// ============================================================================
// حاضر — وضع الكشك المشترك (Kiosk Mode — الجزء 3.3 إضافة تشغيلية)
// ============================================================================
// جهاز واحد عند المشرف/البوابة: فتح برقم الموقع (4 أرقام — التحقق بدور
// الخدمة عبر app.verify_pin، الهاش لا يغادر السيرفر) ثم:
//   اختيار العامل من القائمة أو كتابة كوده الرباعي → تصوير 8 ثواني
//   بحالة معزولة لكل عامل (لا خلط جلسات بين العمال إطلاقًا).
// تسجيلات الكشك: مقبولة تلقائيًا (إشراف بشري مباشر) — قرار D21.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_texts.dart';
import '../../app.dart';
import '../capture/capture_screen.dart';

class KioskWorker {
  KioskWorker({required this.id, required this.fullName, this.code});
  final String id;
  final String fullName;
  final String? code;
}

class KioskController extends StateNotifier<KioskState> {
  KioskController(this._api) : super(const KioskState.locked());

  final ServerApi _api;

  Future<String?> unlock(String pin) async {
    final res = await _api.kioskUnlock(pin);
    if (!res.ok || res.data == null) return res.error;
    final workers = ((res.data!['workers'] as List?) ?? [])
        .map((w) => KioskWorker(
              id: w['id'] as String,
              fullName: w['full_name'] as String,
              code: w['code'] as String?,
            ))
        .toList();
    state = KioskState.unlocked(
      locationName: res.data!['location_name'] as String? ?? 'الموقع',
      workers: workers,
    );
    return null;
  }

  void selectWorker(KioskWorker w) {
    final s = state;
    if (s is! UnlockedKiosk) return;
    state = KioskState.capturing(locationName: s.locationName, worker: w);
  }

  void finishCapture() {
    final s = state;
    if (s is! CapturingKiosk) return;
    // رجوع للقائمة بحالة نظيفة معزولة — لا أثر للجلسة السابقة
    unlockAgain(s.locationName);
  }

  void lock() => state = const KioskState.locked();

  void unlockAgain(String locationName) {
    // إعادة فتح بلا PIN بعد تسجيل عامل؟ لا — القفل إلزامي بعد كل عامل
    // (جهاز مشترك على البوابة — الوسم يوثق من صوّر بالضبط عبر ربط التسجيل بكوده)
    state = const KioskState.locked();
  }
}

sealed class KioskState {
  const KioskState();
}

class LockedKiosk extends KioskState {
  const LockedKiosk();
}

class UnlockedKiosk extends KioskState {
  UnlockedKiosk({required this.locationName, required this.workers});
  final String locationName;
  final List<KioskWorker> workers;
}

class CapturingKiosk extends KioskState {
  CapturingKiosk({required this.locationName, required this.worker});
  final String locationName;
  final KioskWorker worker;
}

final kioskProvider =
    StateNotifierProvider<KioskController, KioskState>((ref) {
  return KioskController(ref.read(apiProvider));
});

class KioskScreen extends ConsumerWidget {
  const KioskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kioskProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: switch (state) {
        LockedKiosk() => const _PinPad(),
        UnlockedKiosk() => _WorkersList(state: state as UnlockedKiosk),
        CapturingKiosk() => _KioskCapture(state: state as CapturingKiosk),
      },
    );
  }
}

// ————————————————— رقم فتح الكشك (شبكة 4 أرقام كبيرة) —————————————————

class _PinPad extends ConsumerStatefulWidget {
  const _PinPad();

  @override
  ConsumerState<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends ConsumerState<_PinPad> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final e = await ref.read(kioskProvider.notifier).unlock(_pin);
    setState(() {
      _busy = false;
      _pin = '';
      _error = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.point_of_sale, size: 52, color: Color(0xFF0F6E56)),
              const SizedBox(height: 10),
              const Text(T.kioskTitle,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(T.kioskEnterPin,
                  style: TextStyle(color: Color(0xFF78716C))),
              const SizedBox(height: 18),
              // نقاط الإدخال
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = _pin.length > i;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? const Color(0xFF0F6E56) : Colors.transparent,
                      border: Border.all(
                          color: const Color(0xFF0F6E56), width: 2),
                    ),
                  );
                }),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 22),
              ..._buildPad(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPad() {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: 76,
            height: 64,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF141B24),
              ),
              child: child ??
                  Text(label,
                      style: const TextStyle(
                          fontSize: 22, fontFamily: 'IBM Plex Mono')),
            ),
          ),
        );

    return [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        key('1', onTap: () => _add('1')),
        key('2', onTap: () => _add('2')),
        key('3', onTap: () => _add('3')),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        key('4', onTap: () => _add('4')),
        key('5', onTap: () => _add('5')),
        key('6', onTap: () => _add('6')),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        key('7', onTap: () => _add('7')),
        key('8', onTap: () => _add('8')),
        key('9', onTap: () => _add('9')),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        key('⌫', onTap: () => setState(() => _pin = _pin.substring(0, _pin.length - 1))),
        key('0', onTap: () => _add('0')),
        key('✓',
            onTap: _pin.length == 4 && !_busy ? _submit : null,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F6E56)))
                : const Icon(Icons.check, color: Color(0xFF0F6E56))),
      ]),
    ];
  }

  void _add(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin = '$_pin$d');
    if (_pin.length == 4) _submit();
  }
}

// ————————————————— اختيار العامل —————————————————

class _WorkersList extends ConsumerStatefulWidget {
  const _WorkersList({required this.state});
  final UnlockedKiosk state;

  @override
  ConsumerState<_WorkersList> createState() => _WorkersListState();
}

class _WorkersListState extends ConsumerState<_WorkersList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final workers = widget.state.workers
        .where((w) =>
            _query.isEmpty ||
            w.fullName.contains(_query) ||
            (w.code ?? '').contains(_query))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        title: Text('${T.kioskTitle} — ${widget.state.locationName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'قفل الكشك',
            onPressed: () => ref.read(kioskProvider.notifier).lock(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'دوّر على اسمك أو اكتب كودك (4 أرقام)',
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
              itemCount: workers.length,
              itemBuilder: (_, i) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFECFDF5),
                    child: Icon(Icons.person_outline, color: Color(0xFF0F6E56)),
                  ),
                  title: Text(workers[i].fullName,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () =>
                      ref.read(kioskProvider.notifier).selectWorker(workers[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ————————————————— تصوير معزول للعامل —————————————————

class _KioskCapture extends ConsumerWidget {
  const _KioskCapture({required this.state});
  final CapturingKiosk state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // شاشة التصوير بنفس محرك التطبيق + عزل كامل لكل عامل (kiosk_user_id)
          CaptureScreen(captureType: 'check_in', kioskUserId: state.worker.id),
          // شريط العامل الحالي أعلى الشاشة — يمنع أي التباس بين العمال
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 10,
              ),
              child: Column(
                children: [
                  Text(
                    'بيقيم دلوقتي: ${state.worker.fullName}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'بعد التسجيل هيظهر زر «موظف تاني» — كل تسجيل باسم صاحبه',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'kiosk-next',
        label: const Text(T.kioskNextWorker),
        icon: const Icon(Icons.group),
        onPressed: () => ref.read(kioskProvider.notifier).finishCapture(),
      ),
    );
  }
}
