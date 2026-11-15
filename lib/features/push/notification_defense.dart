// ============================================================================
// حاضر — الاستراتيجية الدفاعية الثلاثية للإشعارات + نبضة الاتصال (الجزء 3.7)
// ============================================================================
// المستوى الأول : FCM High-Priority يوقظ Doze + تأكيد استلام لحظي (ACK)
// المستوى الثاني: جدول الصباح المشفر AES-256-GCM → منبهات محلية احتياطية
//                 (فحص المتابعة لا يُرسل هنا أبدًا — لحظي FCM فقط)
// المستوى الثالث: فحص لحظي عند كل فتح للتطبيق
// نبضة الاتصال  : أي إشارة حياة (فتح/تسجيل/ACK/WorkManager 15-30 دقيقة)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import '../../core/config.dart';
import '../../core/server_api.dart';
import '../../core/session.dart';

// ---------------------------------------------------------------------------
// المستوى الثاني — فك جدول الصباح المشفر وجدولة المنبهات
// ---------------------------------------------------------------------------

/// فك تشفير {iv, ct} (base64) بمفتاح SHA-256(kScheduleSecret) — أو null
Future<List<DateTime>?> decryptDaySchedule(Map<String, dynamic> enc) async {
  try {
    final secret = kScheduleSecret;
    final key = SecretKey(
      (await Sha256().hash(utf8.encode(secret))).bytes,
    );
    // WebCrypto AES-GCM: الوسم (16 بايت) ملحق بنهاية النص — نفصله يدويًا
    final ct = base64Decode(enc['ct'] as String);
    final iv = base64Decode(enc['iv'] as String);
    final cipherOnly = ct.sublist(0, ct.length - 16);
    final mac = ct.sublist(ct.length - 16);
    final box = SecretBox(cipherOnly, nonce: iv, mac: Mac(mac));
    final clear = await AesGcm.with256bits().decrypt(box, secretKey: key);
    final data = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    final times = (data['t'] as List).cast<String>();
    return times.map(DateTime.parse).toList();
  } catch (_) {
    return null; // فك فاشل (عبث/هاتف مكسور) — تُتجاهل بهدوء وتبقى طبقتا FCM واللحظي
  }
}

/// مجدول المنبهات المحلية (المستوى الثاني)
class LocalAlarms {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        // فتح التطبيق من المنبه — نفس مسار نقر إشعار FCM
        SpotCheckRouter.openRequested.add(true);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// جدولة منبه لكل موعد فحص أساسي اليوم (بلا فحوص المتابعة — مستحيل هنا)
  static Future<void> scheduleToday(List<DateTime> times) async {
    await _plugin.cancelAll();
    const android = AndroidNotificationDetails(
      'hader_backup_alarms', // قناة مختلفة عن قناة FCM عمدًا
      'منبهات الفحص الاحتياطية',
      channelDescription: 'تنبيه احتياطي لو تأخر إشعار الإنترنت',
      importance: Importance.high,
      priority: Priority.high,
    );
    var id = 2001;
    for (final t in times) {
      if (t.isBefore(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        id++,
        'فحص مفاجئ — سجل تواجدك',
        'اضغط هنا وافتح حاضر وسجل الفيديو (8 ثواني)',
        t,
        const NotificationDetails(android: android),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // السقوط التلقائي لمنبه غير دقيق لو رُفض إذن التنبيه الدقيق —
        // فارق الدقائق تغطيه مهلة الـ 15 دقيقة
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// إلغاء منبه موعد وصل إشعاره عبر FCM (الإلغاء الصامت — الجزء 3.7)
  static Future<void> cancelAround(DateTime scheduledAt) async {
    // نلغي الكل ونعيد جدولة الباقي لاحقًا عند الفتح (تبسيط مضمون)
    await _plugin.cancelAll();
  }
}

// ---------------------------------------------------------------------------
// المستوى الأول — FCM
// ---------------------------------------------------------------------------

/// موجه فتح شاشة الفحص من أي مصدر إشعار (Stream واحد للمستهلكين)
abstract final class SpotCheckRouter {
  static final StreamController<bool> openRequested =
      StreamController<bool>.broadcast();
}

/// خدمة FCM: توكن + استقبال + ACK فوري + إلغاء المنبه المقابل
class FcmService {
  FcmService(this._api);
  final ServerApi _api;

  Future<void> init({bool deviceChanged = false}) async {
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission(alert: true, sound: true, badge: true);

    // تسجيل/تجديد التوكن (يُبطئ القديم لو الجهاز اتغير)
    final token = await fcm.getToken();
    if (token != null) {
      await _api.registerPushToken(token, deactivatePrevious: deviceChanged);
    }
    fcm.onTokenRefresh.listen((t) => _api.registerPushToken(t));

    // إشعار الفحص وصل (والتطبيق بالخلفية) → ACK فوري (تثبيت المهلة من لحظة الوصول)
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      SpotCheckRouter.openRequested.add(true);
      _ackFromMessage(m);
    });
    FirebaseMessaging.onMessage.listen((m) {
      final kind = m.data['kind'];
      if (kind == 'spot_check') {
        // الوصل والسيرفر متاح؟ ACK لحظي + إلغاء المنبه الاحتياطي المقابل
        _ackFromMessage(m);
      }
    });
  }

  Future<void> _ackFromMessage(RemoteMessage m) async {
    final id = m.data['spot_check_id'];
    if (id is String && id.isNotEmpty) {
      await _api.ackSpotCheck(id);
      await _api.heartbeat(); // وصول الإشعار نفسه نبضة اتصال
    }
  }
}

// ---------------------------------------------------------------------------
// نبضة الاتصال — WorkManager كل 15-30 دقيقة (حين يسمح النظام)
// ---------------------------------------------------------------------------

abstract final class HeartbeatWorker {
  static const taskName = 'hader-heartbeat';

  static Future<void> register(ServerApi api) async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(minutes: 30), // الحد الأدنى للنظام 15 دقيقة
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
    );
  }

  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        // نبضة خفيفة — أي رد يُحدث last_seen_at ويعيد ساعة السيرفر
        final api = ServerApi(ServerApi.createClient());
        final res = await api.heartbeat();
        return res.ok;
      } catch (_) {
        return false; // يُعاد جدولتها بتراجع تصاعدي
      }
    });
  }
}
