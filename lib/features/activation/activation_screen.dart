// ============================================================================
// حاضر — رحلة التفعيل الآمن لمرة واحدة (الجزء 3.2 — 8 خطوات محكمة)
// ============================================================================
// 1 تثبيت من Play   2 رقم+كود دعوة (تنبيه الشريحتين)   3 القواعد الأربع على السيرفر
// 4 OTP + ربط الجهاز نهائيًا (Device Binding)          5 شاشة الشفافية والموافقة
// 6 سيلفي مرجعي واحد                                  7 معالج البطارية + بوابة
//   إشعار تجريبي إلزامي                                8 فيديو تدريبي واحد (غير محسوب)
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/app_texts.dart';
import '../../core/server_api.dart';
import '../../core/session.dart';
import '../../app.dart';
import '../capture/capture_screen.dart';
import '../capture/signals_collector.dart';
import 'battery_wizard.dart';

enum ActStep { welcome, phoneCode, otp, consent, selfie, battery, practice, done }

class ActivationController extends StateNotifier<ActStep> {
  ActivationController(this._api) : super(ActStep.welcome);

  final ServerApi _api;
  String phone = '';
  String? inviteError;
  bool busy = false;
  bool consentAccepted = true;
  DeviceIdentity? device;
  String? selfieR2Key;

  Future<String?> submitPhoneAndCode(String phoneInput, String code) async {
    busy = true;
    final res = await _api.verifyInvite(phone: phoneInput, inviteCode: code);
    busy = false;
    if (!res.ok) return res.error;
    phone = phoneInput;
    final otp = await _api.sendOtp(phoneInput);
    if (!otp.ok) return otp.error;
    state = ActStep.otp;
    return null;
  }

  Future<String?> submitOtp(String code) async {
    busy = true;
    final res = await _api.verifyOtp(phone, code);
    busy = false;
    if (!res.ok) return res.error;

    // هوية الجهاز + شهادة Play Integrity (إن توفرت الخدمات)
    device = await DeviceIdentity.read();
    final integrity = await NativeSignals.requestIntegrity(
      DateTime.now().millisecondsSinceEpoch.toRadixString(36),
    );
    state = ActStep.consent;
    _pendingIntegrity = integrity;
    return null;
  }

  String? _pendingIntegrity;

  Future<String?> submitConsent(bool accepted) async {
    busy = true;
    final res = await _api.completeActivation(
      device: device ?? (await DeviceIdentity.read()),
      consentAccepted: accepted,
      playIntegrityToken: _pendingIntegrity,
    );
    busy = false;
    if (!res.ok) return res.error;
    if (!accepted) {
      // اختار البديل اليدوي بهدوء — حسابه جاهز للورقي وإشعار الإدارة تم (داخل الدالة)
      state = ActStep.done;
      return null;
    }
    state = ActStep.selfie;
    return null;
  }

  Future<String?> submitSelfie(String localPath) async {
    busy = true;
    final presign = await _api.presignSelfie();
    if (!presign.ok || presign.data == null) {
      busy = false;
      return presign.error;
    }
    try {
      final bytes = await File(localPath).readAsBytes();
      final res = await http.put(
        Uri.parse(presign.data!['upload_url'] as String),
        body: bytes,
        headers: {'Content-Type': 'image/jpeg'},
      );
      if (res.statusCode != 200 && res.statusCode != 204) {
        busy = false;
        return 'تعذر رفع الصورة — جرب تاني';
      }
      busy = false;
      selfieR2Key = presign.data!['object_key'] as String;
      state = ActStep.battery;
      return null;
    } catch (_) {
      busy = false;
      return 'النت شكله ضعيف — جرب تاني';
    }
  }

  void batteryGatePassed() => state = ActStep.practice;
  void practiceDone() => state = ActStep.done;
}

final activationProvider =
    StateNotifierProvider<ActivationController, ActStep>((ref) {
  return ActivationController(ref.read(apiProvider));
});

class ActivationScreen extends ConsumerWidget {
  const ActivationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(activationProvider);
    return Scaffold(
      body: SafeArea(
        child: StepperBody(step: step),
      ),
    );
  }
}

class StepperBody extends ConsumerWidget {
  const StepperBody({super.key, required this.step});

  final ActStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (step) {
      case ActStep.welcome:
        return _Welcome(ref: ref);
      case ActStep.phoneCode:
        return _PhoneCode(ref: ref);
      case ActStep.otp:
        return _Otp(ref: ref);
      case ActStep.consent:
        return _Consent(ref: ref);
      case ActStep.selfie:
        return _Selfie(ref: ref);
      case ActStep.battery:
        return _Battery(ref: ref);
      case ActStep.practice:
        return _Practice(ref: ref);
      case ActStep.done:
        return _Done(ref: ref);
    }
  }
}

// ————————————————————————— الخطوات —————————————————————————

class _Welcome extends ConsumerWidget {
  const _Welcome({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Frame(
      title: T.welcomeTitle,
      body: T.welcomeBody,
      child: FilledButton(
        onPressed: () =>
            ref.read(activationProvider.notifier).state = ActStep.phoneCode,
        child: const Text(T.startActivation),
      ),
    );
  }
}

class _PhoneCode extends ConsumerStatefulWidget {
  const _PhoneCode({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_PhoneCode> createState() => _PhoneCodeState();
}

class _PhoneCodeState extends ConsumerState<_PhoneCode> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? error;

  @override
  Widget build(BuildContext context) {
    final c = ref.read(activationProvider.notifier);
    return _Frame(
      title: 'بيانات التفعيل',
      body: 'رقمك وكود الدعوة اللي بعتتهاله الإدارة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: T.phoneLabel,
              hintText: T.phoneHint,
            ),
          ),
          const SizedBox(height: 12),
          if (isLocalEgyptian(_phone.text))
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(T.dualSimNote,
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF78716C))),
            ),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: T.inviteLabel,
              hintText: T.inviteHint,
            ),
          ),
          if (error != null) _Error(error!),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: c.busy
                ? null
                : () async {
                    final e = await c.submitPhoneAndCode(_phone.text, _code.text);
                    if (e != null) setState(() => error = e);
                  },
            child: const Text(T.verifyInvite),
          ),
        ],
      ),
    );
  }

  bool isLocalEgyptian(String s) =>
      RegExp(r'^01[0125][0-9]{8}$').hasMatch(s.trim());
}

class _Otp extends ConsumerStatefulWidget {
  const _Otp({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_Otp> createState() => _OtpState();
}

class _OtpState extends ConsumerState<_Otp> {
  final _code = TextEditingController();
  String? error;

  @override
  Widget build(BuildContext context) {
    final c = ref.read(activationProvider.notifier);
    return _Frame(
      title: T.otpTitle,
      body: '${T.otpSentTo} ${c.phone}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 10,
              fontFamily: 'IBM Plex Mono',
            ),
            decoration: const InputDecoration(counterText: '', hintText: '● ● ● ● ● ●'),
          ),
          if (error != null) _Error(error!),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: c.busy
                ? null
                : () async {
                    final e = await c.submitOtp(_code.text);
                    if (e != null) setState(() => error = e);
                  },
            child: const Text('تحقق'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: c.busy ? null : () => c.submitPhoneAndCode(c.phone, ''),
            child: const Text('إعادة إرسال الرمز'),
          ),
          const Text(T.otpNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF78716C))),
        ],
      ),
    );
  }
}

class _Consent extends ConsumerWidget {
  const _Consent({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(activationProvider.notifier);
    return _Frame(
      title: T.consentTitle,
      body: _consentBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bullet('فيديو 8 ثوانٍ لوشك وبصوتك وقت التسجيل بس — مفيش أي تتبع لمكانك قبلها ولا بعدها'),
          _bullet('مفيش تصوير للمكان حواليك ولا قراءة لصورك أو رسائلك أبدًا'),
          _bullet('كل الفيديوهات بتتمسح نهائيًا من السيرفرات بعد 7 أيام بالظبط'),
          _bullet('النظام مش قاضي: أي ملاحظة بيراجعها مديرك بنفسه وليك حق الاعتراض بضغطة'),
          _bullet('من رفض التصوير: بديل ورقي قانوني كامل من غير أي عقوبة'),
          const Spacer(),
          FilledButton(
            onPressed: c.busy
                ? null
                : () async {
                    final e = await c.submitConsent(true);
                    if (e != null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e)));
                    }
                  },
            child: const Text(T.consentAccept),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: c.busy
                ? null
                : () async {
                    await c.submitConsent(false);
                  },
            child: const Text(T.consentDecline),
          ),
        ],
      ),
    );
  }

  static const _consentBody = 'إحنا بنشوف اللي بيتسجل بالظبط زي ما بيشوفه مديرك — شفافية كاملة بينا';

  Widget _bullet(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✓ ', style: TextStyle(fontWeight: FontWeight.w900)),
            Expanded(child: Text(t, style: const TextStyle(height: 1.7))),
          ],
        ),
      );
}

class _Selfie extends ConsumerWidget {
  const _Selfie({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(activationProvider.notifier);
    return _Frame(
      title: T.selfieTitle,
      body: T.selfieHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () async {
              final path = await _pickSelfie();
              if (path == null) return;
              final e = await c.submitSelfie(path);
              if (e != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e)));
              }
            },
            child: const Text('التقط الصورة'),
          ),
        ],
      ),
    );
  }

  /// التقاط السيلفي المرجعي: الكاميرا الأمامية فقط — لا يوجد مسار للمعرض إطلاقًا
  Future<String?> _pickSelfie() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 82,
      maxWidth: 1280,
    );
    return shot?.path;
  }
}

class _Battery extends ConsumerStatefulWidget {
  const _Battery({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_Battery> createState() => _BatteryState();
}

class _BatteryState extends ConsumerState<_Battery> {
  String manufacturer = '';
  bool gatePassed = false;

  @override
  void initState() {
    super.initState();
    DeviceIdentity.read().then((d) => setState(() => manufacturer = d.manufacturer));
  }

  @override
  Widget build(BuildContext context) {
    final wizard = batteryWizardFor(manufacturer);
    final c = ref.read(activationProvider.notifier);
    return _Frame(
      title: T.batteryTitle,
      body: 'خطوات موبايلك (${wizard.osLabel}):',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...wizard.steps.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(s, style: const TextStyle(height: 1.6))),
                  ],
                ),
              )),
          if (wizard.huaweiNoGmsWarning)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'هواوي بلا خدمات جوجل: التطبيق الشخصي مش هيعرف يوصلك إشعارات — '
                'استخدم جهاز الكشك المشترك أو البديل الورقي (حقك الكامل).',
                style: TextStyle(fontSize: 12.5, height: 1.6),
              ),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              gatePassed
                  ? 'وصل الإشعار التجريبي ✓ — كمّل للفيديو التدريبي'
                  : T.testNotificationGate,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: gatePassed
                ? () => c.batteryGatePassed()
                : () {
                    // زر «بعت الإشعار التجريبي» — البوابة تُقفل حتى وصوله فعليًا
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('بعتنا الإشعار — استنى يوصل واظهر على موبايلك'),
                      ),
                    );
                  },
            child: Text(gatePassed ? T.next : 'بعت الإشعار التجريبي'),
          ),
        ],
      ),
    );
  }
}

class _Practice extends ConsumerWidget {
  const _Practice({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(activationProvider.notifier);
    return _Frame(
      title: T.practiceTitle,
      body: T.practiceBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () async {
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => const CaptureScreen(practice: true),
                ),
              );
              c.practiceDone();
            },
            child: const Text('صوّر الفيديو التدريبي'),
          ),
        ],
      ),
    );
  }
}

class _Done extends ConsumerWidget {
  const _Done({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Frame(
      title: T.activationDone,
      body: 'من دلوقتي حضورك وانصرافك بيتسجلوا بضغطة واحدة — وفحوصات نص اليوم '
          'بتثبت تواجدك بفيديو 8 ثواني.',
      child: FilledButton(
        onPressed: () {
          // إعادة بناء البوابة الجذرية (الجلسة صارت موجودة → الرئيسية)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeShell()),
          );
        },
        child: const Text('ابدأ استخدام حاضر'),
      ),
    );
  }
}

// ————————————————————————— عناصر مشتركة —————————————————————————

class _Frame extends StatelessWidget {
  const _Frame({required this.title, required this.body, required this.child});

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.8, color: Color(0xFF4B5563))),
            const SizedBox(height: 26),
            child,
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(message,
          style: const TextStyle(
              color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
    );
  }
}
