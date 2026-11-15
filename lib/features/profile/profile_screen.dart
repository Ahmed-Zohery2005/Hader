// ============================================================================
// حاضر — حسابي (الجزء 3.3): السيلفي المرجعي + بيانات الجهاز + معالج البطارية
// + 15 سؤالًا شائعًا (الملحق ج) + الدعم + الخصوصية + سحب الموافقة
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_texts.dart';
import '../../core/config.dart';
import '../../core/server_api.dart';
import '../../core/session.dart';
import '../../app.dart';
import '../activation/battery_wizard.dart';
import 'faq_data.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _me;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await Supabase.instance.client
        .from('users')
        .select(
            'full_name, phone_e164, bound_device_model, bound_device_manufacturer, '
            'reference_selfie_r2_key, attendance_mode')
        .limit(1);
    if (mounted && rows.isNotEmpty) {
      setState(() => _me = Map<String, dynamic>.from(rows.first));
    }
  }

  Future<void> _withdrawConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(T.withdrawConsent),
        content: const Text(T.withdrawConsentConfirm, style: TextStyle(height: 1.7)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('كمّل بالتطبيق')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF78716C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('اسحب موافقتي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final res = await ref.read(apiProvider).revokeConsent();
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.ok ? (res.data?['message'] as String? ?? T.ok) : (res.error ?? T.errGeneric))),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final device = _me == null
        ? '—'
        : '${_me!['bound_device_manufacturer'] ?? ''} ${_me!['bound_device_model'] ?? ''}'.trim();
    final manualMode = _me?['attendance_mode'] == 'manual_paper';

    return Scaffold(
      appBar: AppBar(title: const Text(T.tabProfile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_me?['full_name'] as String? ?? '…',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    _me?['phone_e164'] as String? ?? '—',
                    style: const TextStyle(fontFamily: 'IBM Plex Mono', color: Color(0xFF78716C)),
                  ),
                  const Divider(height: 22),
                  _row(T.myDevice, device.isEmpty ? '—' : device),
                  if (manualMode)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'حسابك على البديل الورقي — سجّل حضورك مع المشرف',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          _item(
            icon: Icons.face_retouching_natural,
            label: T.updateSelfie,
            subtitle: T.updateSelfieNote,
            onTap: () => _requestSelfieUpdate(),
          ),
          _item(
            icon: Icons.battery_charging_full,
            label: T.rerunBatteryWizard,
            onTap: () => _showBatteryWizard(),
          ),
          _item(
            icon: Icons.help_outline,
            label: T.faq,
            onTap: () => _showFaq(),
          ),
          _item(
            icon: Icons.support_agent,
            label: T.support,
            onTap: () => _openWhatsapp(),
          ),
          _item(
            icon: Icons.privacy_tip_outlined,
            label: T.privacy,
            onTap: () => _showPrivacy(),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF78716C),
            ),
            onPressed: _busy ? null : _withdrawConsent,
            icon: const Icon(Icons.logout),
            label: const Text(T.withdrawConsent),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              }
            },
            child: const Text(T.signOut),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Color(0xFF4B5563))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _item({
    required IconData icon,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
  }) =>
      Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF0F6E56)),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          subtitle: subtitle != null
              ? Text(subtitle,
                  style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF78716C)))
              : null,
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap,
        ),
      );

  /// طلب تحديث السيلفي: التقاط + رفع + طلب اعتماد من الإدارة
  Future<void> _requestSelfieUpdate() async {
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    final presign = await api.presignSelfie();
    if (!presign.ok || presign.data == null) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(presign.error ?? T.errGeneric)));
      }
      return;
    }
    // الالتقاط الفعلي يتم عبر شاشة التصوير بوضع السيلفي (كاميرا أمامية + بوابة وجه)
    // هنا نرسل الطلب بمفتاح الرفع الجاهز بعد اكتمال الالتقاط والرفع في الشاشة
    final r2Key = presign.data!['object_key'] as String;
    final res = await api.requestSelfieUpdate(r2Key);
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.ok
            ? 'وصل طلبك — الإدارة هتعتمد الصورة الجديدة بعد المراجعة'
            : (res.error ?? T.errGeneric)),
      ),
    );
  }

  Future<void> _showBatteryWizard() async {
    final d = await DeviceIdentity.read();
    if (!mounted) return;
    final wizard = batteryWizardFor(d.manufacturer);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('${T.batteryTitle} (${wizard.osLabel})',
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...wizard.steps.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(s, style: const TextStyle(height: 1.7))),
                    ],
                  ),
                )),
            if (wizard.huaweiNoGmsWarning)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'هواوي بلا خدمات جوجل: استخدم جهاز الكشك أو البديل الورقي.',
                  style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFaq() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const FaqScreen(),
    ));
  }

  Future<void> _showPrivacy() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text('الخصوصية ببساطة', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text(
              '• التصوير لوشك فقط وقت التسجيل — لا يوجد أي تتبع لمكانك قبلها أو بعدها\n'
              '• لا نقرأ صورك ولا رسائلك ولا جهات اتصالك أبدًا\n'
              '• كل الفيديوهات تُمحى نهائيًا من السيرفرات بعد 7 أيام\n'
              '• كل مشاهدة لأي فيديو تُسجَّل باسم المشاهد وتوقيته\n'
              '• لا عقوبات آلية — أي ملاحظة يقررها مديرك الإنسان\n'
              '• من حقك الاعتراض على أي قرار خلال 7 أيام وسحب موافقتك في أي وقت\n'
              '• محو نهائي موثق بعد انتهاء التعاقد (قانون 151/2020)',
              style: TextStyle(height: 2),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsapp() async {
    final uri = Uri.parse('https://wa.me/$kSupportWhatsapp');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('رقم الدعم: +$kSupportWhatsapp')));
      }
    }
  }
}
