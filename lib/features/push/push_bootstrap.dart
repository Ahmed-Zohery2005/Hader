// ============================================================================
// حاضر — تهيئة خدمات الإشعارات بعد التفعيل/الدخول (تستدعى مرة واحدة)
// ============================================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import 'notification_defense.dart';

abstract final class PushBootstrap {
  static bool _done = false;

  static Future<void> initialize(WidgetRef ref) async {
    if (_done) return;
    _done = true;
    await LocalAlarms.init();
    await FcmService(ref.read(apiProvider)).init();
    await HeartbeatWorker.register(ref.read(apiProvider));
  }
}
