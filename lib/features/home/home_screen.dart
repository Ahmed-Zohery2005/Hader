// ============================================================================
// حاضر — الرئيسية (الجزء 3.3): 4 حالات ذكية + بطاقة الفحص بعداد حي + شريط
// «مش متاح للفحص» الأصفر + الفحص اللحظي عند كل فتح (المستوى الثالث)
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_texts.dart';
import '../../core/server_api.dart';
import '../../core/utils/clock_math.dart';
import '../../app.dart';
import '../capture/capture_screen.dart';
import '../history/history_screen.dart';
import '../notifications_tab/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../push/notification_defense.dart';

/// حالة اليوم الأربع
enum DayState { beforeShift, present, activeCheck, doneForDay }

class HomeSnapshot {
  HomeSnapshot({
    required this.dayState,
    this.shiftStart,
    this.shiftEnd,
    this.firstCheckIn,
    this.lastCheckIn,
    this.todayCount = 0,
    this.spotCheck,
    this.unreachable = false,
  });

  final DayState dayState;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;
  final DateTime? firstCheckIn;
  final DateTime? lastCheckIn;
  final int todayCount;
  final Map<String, dynamic>? spotCheck; // الفحص النشط
  final bool unreachable;
}

final homeProvider = FutureProvider<HomeSnapshot>((ref) async {
  final api = ref.read(apiProvider);
  final sb = Supabase.instance.client;

  // نبضة افتتاحية = تسجيل حضور «إشارة حياة» + سؤال الفحص اللحظي (المستوى الثالث)
  final hb = await api.heartbeat();
  final unreachable = hb.ok == false;

  final shift = await api.activeShift();
  final activeCheck = await api.activeSpotCheck();

  // آخر تسجيلاتي اليوم (سياسة RLS: نافذة 7 أيام — يكفي اليوم)
  final caps = await sb
      .from('captures')
      .select('capture_type, captured_at_server')
      .order('captured_at_server', ascending: false)
      .limit(30);
  final today = <Map<String, dynamic>>[];
  final now = DateTime.now();
  for (final r in caps) {
    final t = DateTime.parse(r['captured_at_server'] as String);
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      today.add(Map<String, dynamic>.from(r));
    }
  }
  final checkIns = today.where((t) => t['capture_type'] != 'check_out').toList();
  final checkOut = today.any((t) => t['capture_type'] == 'check_out');

  DayState state;
  if (activeCheck != null) {
    state = DayState.activeCheck;
  } else if (checkOut) {
    state = DayState.doneForDay;
  } else if (checkIns.isNotEmpty) {
    state = DayState.present;
  } else {
    state = DayState.beforeShift;
  }

  return HomeSnapshot(
    dayState: state,
    shiftStart: shift == null ? null : DateTime.parse(shift['starts_at'] as String),
    shiftEnd: shift == null ? null : DateTime.parse(shift['ends_at'] as String),
    firstCheckIn: checkIns.isEmpty
        ? null
        : DateTime.parse(checkIns.last['captured_at_server'] as String),
    lastCheckIn: checkIns.isEmpty
        ? null
        : DateTime.parse(checkIns.first['captured_at_server'] as String),
    todayCount: today.length,
    spotCheck: activeCheck,
    unreachable: unreachable,
  );
});

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // فتح شاشة الفحص من أي مصدر إشعار (FCM أو منبه محلي)
    SpotCheckRouter.openRequested.stream.listen((_) {
      if (mounted) setState(() => _tab = 0);
      ref.invalidate(homeProvider);
    });
    // تحديث دوري خفيف للحالة (كل 20 ثانية — عدادات حية)
    Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) ref.invalidate(homeProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const HistoryScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: T.tabHome),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: T.tabHistory),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: T.tabNotifications),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: T.tabProfile),
        ],
      ),
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(homeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('${T.appName} — ${T.tabHome}')),
      body: snap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _OfflineNotice(),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              if (s.unreachable) const _OfflineNotice(),
              if (s.dayState == DayState.activeCheck && s.spotCheck != null)
                _ActiveCheckCard(spotCheck: s.spotCheck!),
              ..._forState(context, s),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _forState(BuildContext context, HomeSnapshot s) {
    final timeFmt = DateFormat('h:mm a', 'ar_EG');
    switch (s.dayState) {
      case DayState.beforeShift:
        return [
          _Greeting(sub: s.shiftStart == null
              ? 'مفيش وردية مسجلة النهارده — لو ده غلط كلّم المشرف'
              : 'وردية النهارده من ${timeFmt.format(s.shiftStart!)} إلى ${timeFmt.format(s.shiftEnd!)}'),
          _BigButton(
            label: T.checkIn,
            onPressed: () => _openCapture(context, 'check_in'),
          ),
        ];
      case DayState.present:
        return [
          _Greeting(
            sub: s.firstCheckIn != null
                ? '${T.presentSince} ${timeFmt.format(s.firstCheckIn!)} ✓'
                : T.presentSince,
          ),
          _InfoCard(rows: [
            ('تسجيلات النهارده', '${s.todayCount}'),
            ('آخر تسجيل', s.lastCheckIn != null ? timeFmt.format(s.lastCheckIn!) : '—'),
          ]),
          const SizedBox(height: 12),
          _BigButton(
            label: T.checkOut,
            quiet: true,
            onPressed: () => _openCapture(context, 'check_out'),
          ),
        ];
      case DayState.activeCheck:
        return const [
          SizedBox(height: 8),
          Text(
            'لو الزر مش شغال: افتح التطبيق من الإشعار — المهلة بتتحسب من وصوله',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF78716C)),
          ),
        ];
      case DayState.doneForDay:
        return [
          _Greeting(sub: T.daySummary),
          _InfoCard(rows: [
            ('الحضور', s.firstCheckIn != null ? timeFmt.format(s.firstCheckIn!) : '—'),
            ('الانصراف', s.lastCheckIn != null ? timeFmt.format(s.lastCheckIn!) : '—'),
            ('إجمالي تسجيلات اليوم', '${s.todayCount}'),
          ]),
        ];
    }
  }

  Future<void> _openCapture(BuildContext context, String type) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CaptureScreen(captureType: type),
    ));
    ref.invalidate(homeProvider);
  }
}

/// بطاقة الفحص المفاجئ: عداد تنازلي حي + سجل الآن + أجّل مرة واحدة
class _ActiveCheckCard extends ConsumerStatefulWidget {
  const _ActiveCheckCard({required this.spotCheck});
  final Map<String, dynamic> spotCheck;

  @override
  ConsumerState<_ActiveCheckCard> createState() => _ActiveCheckCardState();
}

class _ActiveCheckCardState extends ConsumerState<_ActiveCheckCard> {
  Timer? _tick;
  late DateTime _deadline;
  bool _snoozed = false;
  bool _acked = false;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.parse(widget.spotCheck['deadline_at'] as String? ??
        DateTime.now().add(const Duration(minutes: 15)).toIso8601String());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // ACK فوري عند العرض (تثبيت المهلة من لحظة وصول الإشعار/الفتح)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final api = ref.read(apiProvider);
      final res = await api
          .ackSpotCheck(widget.spotCheck['id'] as String);
      if (res.ok && res.data?['deadline_at'] != null) {
        setState(() {
          _deadline = DateTime.parse(res.data!['deadline_at'] as String);
          _acked = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _deadline.difference(DateTime.now());
    final expired = left.isNegative;
    final snoozedOnce =
        widget.spotCheck['snoozed_once'] as bool? ?? _snoozed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.radar, size: 42, color: Color(0xFFD97706)),
          const SizedBox(height: 8),
          const Text(T.spotCheckIncoming,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            expired ? 'خلصت المهلة — سجل براحتك وهيراجعها المدير' : '${T.remaining} ${formatCountdown(left.inMilliseconds)} ${T.minutes}',
            style: TextStyle(
              fontSize: 26,
              fontFamily: 'IBM Plex Mono',
              fontWeight: FontWeight.w800,
              color: expired ? const Color(0xFF78716C) : const Color(0xFFB45309),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.videocam),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CaptureScreen(
                    captureType: 'spot_check',
                    spotCheckId: widget.spotCheck['id'] as String,
                  ),
                ));
                ref.invalidate(homeProvider);
              },
              child: const Text(T.recordNow, style: TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(height: 8),
          if (!snoozedOnce && !expired)
            TextButton(
              onPressed: () async {
                final res = await ref
                    .read(apiProvider)
                    .snoozeSpotCheck(widget.spotCheck['id'] as String);
                if (res.ok && res.data?['deadline_at'] != null) {
                  setState(() {
                    _deadline = DateTime.parse(res.data!['deadline_at'] as String);
                    _snoozed = true;
                  });
                } else if (res.error != null && mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(res.error!)));
                }
              },
              child: const Text(T.snooze10),
            )
          else if (snoozedOnce)
            const Text(T.snoozedOnce,
                style: TextStyle(fontSize: 12.5, color: Color(0xFF78716C))),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.sub});
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            _greet(),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(sub,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13.5, color: Color(0xFF4B5563), height: 1.7)),
        ],
      ),
    );
  }

  String _greet() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير';
    if (h < 17) return 'نهارك سعيد';
    return 'مساء الخير';
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onPressed, this.quiet = false});

  final String label;
  final VoidCallback onPressed;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor:
              quiet ? const Color(0xFF0F6E56).withValues(alpha: 0.85) : null,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: rows
              .map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(r.$1, style: const TextStyle(color: Color(0xFF4B5563))),
                        Text(r.$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontFamily: 'IBM Plex Mono')),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        T.unreachableBar,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.6),
      ),
    );
  }
}
