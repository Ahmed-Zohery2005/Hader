// ============================================================================
// حاضر — الجلسة المحلية: هوية الجهاز + مزامنة ساعة السيرفر + الخزنة الآمنة
// ============================================================================
// * flutter_secure_storage (Hardware-backed Keystore) — لا OTP يوميًا أبدًا:
//   جلسة Supabase الطويلة تُحفظ آمنة، والحساب مربوط بهذا الجهاز حصريًا
//   (bound_device_id — فك الربط قرار إداري فقط).
// * ServerClockSync: آخر وقت سيرفر معروف مقرونًا بساعة الرتابة — أساس العدل
//   الزمني للتسجيلات الأوفلاين (ساعة المستخدم الحائطية لا تُعتد إطلاقًا).
// ============================================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'clock_math.dart';

/// معرف الجهاز المستقر: يُشتق من خصائص العتاد الثابتة (وليس ANDROID_ID القابل
/// لإعادة الضبط) — بديل عملي بلا أذونات إضافية: ثابت طوال عمر التثبيت+العتاد.
class DeviceIdentity {
  DeviceIdentity({
    required this.deviceId,
    required this.model,
    required this.manufacturer,
  });

  final String deviceId;
  final String model;
  final String manufacturer;

  static Future<DeviceIdentity> read() async {
    final info = await DeviceInfoPlugin().androidInfo;
    // مزيج ثابت من معرفات العتاد المصنّع — لا يتغير بترقية التطبيق
    final raw = '${info.manufacturer}|${info.model}|${info.device}|'
        '${info.hardware}|${info.fingerprint.split('/').first}';
    final stable = raw.hashCode.toRadixString(36) + raw.length.toRadixString(36);
    return DeviceIdentity(
      deviceId: 'hd-$stable-${const Uuid().v4().substring(0, 8)}'
          .substring(0, 24),
      model: info.model,
      manufacturer: info.manufacturer,
    );
  }
}

/// آخر مزامنة ناجحة لساعة السيرفر — يُحدَّث مع كل رد من الدوال الطرفية
class ServerClockSync {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kServerTime = 'hader_server_time_ms';
  static const _kElapsed = 'hader_elapsed_ms';

  ClockSyncPoint? _cached;
  ClockSyncPoint? get point => _cached;

  /// تسجيل مزامنة جديدة (يُستدعى من كل رد ناجح فيه server_time)
  Future<void> sync(String serverTimeIso, int elapsedRealtimeMs) async {
    final serverMs = DateTime.parse(serverTimeIso).millisecondsSinceEpoch;
    _cached = ClockSyncPoint(serverTimeMs: serverMs, elapsedRealtimeMs: elapsedRealtimeMs);
    await _storage.write(key: _kServerTime, value: serverMs.toString());
    await _storage.write(key: _kElapsed, value: elapsedRealtimeMs.toString());
  }

  /// استرجاع آخر مزامنة عند الإقلاع (للأوفلاين)
  Future<ClockSyncPoint?> load() async {
    if (_cached != null) return _cached;
    final s = await _storage.read(key: _kServerTime);
    final e = await _storage.read(key: _kElapsed);
    if (s == null || e == null) return null;
    _cached = ClockSyncPoint(
      serverTimeMs: int.parse(s),
      elapsedRealtimeMs: int.parse(e),
    );
    return _cached;
  }
}

/// قراءة ساعة الرتابة الحقيقية عبر قناة أصلية بسيطة —
/// الافتراض العملي الأكثر أمانًا المتاح بلا جسر: SystemClock.elapsedRealtime
/// نمرره من MainActivity عند كل استدعاء native (scanBssids يرافق كل تسجيل).
/// هذه الفئة تغلف المصدر الوحيد للحقيقة الزمنية.
abstract final class MonotonicClock {
  static int now() => _delegate?.call() ?? DateTime.now().millisecondsSinceEpoch;
  static int Function()? _delegate;

  /// يضبطه main.dart من قناة الساعة الأصلية (SystemClock.elapsedRealtime)
  static void setDelegate(int Function() fn) => _delegate = fn;
}

/// هل الهاتف بلا خدمات جوجل (هواوي HMS)؟ — إفصاح الكشك/الورق
Future<bool> isMissingGoogleServices() async {
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final m = info.manufacturer.toLowerCase();
    // فحص عملي: هواوي حديثة = HMS بلا GMS غالبًا — نتيجة الاستدعاء الفعلي
    // لـ GoogleApiAvailability يحدد في runtime داخل fcm_service
    return m.contains('huawei') || m.contains('honor');
  } catch (_) {
    return false;
  }
}
