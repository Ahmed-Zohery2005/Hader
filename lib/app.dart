// ============================================================================
// حاضر — جذر التطبيق: RTL + السمات + الموجه (تفعيل ↔ لوجر ↔ الكشك ↔ التبويبات)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'core/server_api.dart';
import 'core/session.dart';
import 'features/activation/activation_screen.dart';
import 'features/capture/uploader.dart';
import 'features/home/home_screen.dart';
import 'features/kiosk/kiosk_screen.dart';
import 'features/push/notification_defense.dart';
import 'features/push/push_bootstrap.dart';

final apiProvider = Provider<ServerApi>((ref) {
  return ServerApi(Supabase.instance.client);
});

final uploaderProvider = Provider<CaptureUploader>(
  (ref) => CaptureUploader(ref.watch(apiProvider)),
);

/// دور المستخدم من الجلسة (employee | kiosk_operator | …)
final roleProvider = FutureProvider<String?>((ref) async {
  final sb = Supabase.instance.client;
  final rows = await sb.from('users').select('roles(code)').limit(1);
  if (rows.isEmpty) return null;
  final r = rows.first as Map<String, dynamic>;
  final role = r['roles'];
  return role is Map ? role['code'] as String? : null;
});

class HaderApp extends ConsumerStatefulWidget {
  const HaderApp({super.key});

  @override
  ConsumerState<HaderApp> createState() => _HaderAppState();
}

class _HaderAppState extends ConsumerState<HaderApp> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final api = ref.read(apiProvider);
    // نبضة افتتاحية + الفحص اللحظي (المستوى الثالث) + خدمات الإشعارات
    await PushBootstrap.initialize(ref);
    await api.heartbeat();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حاضر',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // RTL أصيل — كل النصوص مصرية
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _RootGate(),
    );
  }
}

/// بوابة الجذر: لا جلسة → تفعيل | كشك → الكشك | موظف → التبويبات الأربع
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const ActivationScreen();
    }
    return ref.watch(roleProvider).when(
          loading: () => const _Splash(),
          error: (_, __) => const ActivationScreen(),
          data: (role) =>
              role == 'kiosk_operator' ? const KioskScreen() : const HomeShell(),
        );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlutterLogo(size: 44),
            SizedBox(height: 14),
            Text('حاضر… ثانية واحدة'),
          ],
        ),
      ),
    );
  }
}
