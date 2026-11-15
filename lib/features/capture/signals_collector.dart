// ============================================================================
// حاضر — مجمّع الإشارات البيئية والأمنية (الجزء 3.4 خطوة 6 + 3.6)
// ============================================================================
// بالتوازي مع التصوير يُلتقط: GPS ودقته + بصمة شبكات الهواء (BSSID+RSSI عبر
// القناة الأصلية) + شهادة Play Integrity + كشف الموقع الوهمي.
// (القرار الخماسي النهائي يجري على السيرفر في evaluate_capture_location —
//  التطبيق يجمع الإشارات فقط ولا يحكم أبدًا.)
// ============================================================================

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class NativeSignals {
  static const _channel = MethodChannel('hader/native');

  /// مسح شبكات الهواء: [{"bssid":"A4:2B:..","rssi":-58}, ...]
  /// (لا يتطلب اتصالًا بأي شبكة — العنوان الفيزيائي الملتقط في الهواء يكفي)
  static Future<List<Map<String, dynamic>>> scanBssids() async {
    try {
      final raw = await _channel.invokeMethod<String>('scanBssids');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['bssid'] is String)
          .map((e) => {'bssid': e['bssid'], 'rssi': e['rssi'] ?? -100})
          .toList();
    } on PlatformException {
      return []; // إذن مرفوض أو مسح فاشل — إشارة غائبة (لا اتهام)
    } catch (_) {
      return [];
    }
  }

  /// شهادة Play Integrity الخام (تُتحقق على السيرفر) — أو null
  static Future<String?> requestIntegrity(String nonce) async {
    try {
      return await _channel.invokeMethod<String>('requestIntegrity', {'nonce': nonce});
    } on PlatformException {
      return null; // جهاز بلا خدمات أو فشل — يُسجل ويراجع إداريًا
    } catch (_) {
      return null;
    }
  }

  /// هل الموقع الوهمي مفعّل (خيارات المطورين / مزود mock)؟
  static Future<bool> isMockLocationOn() async {
    try {
      return await _channel.invokeMethod<bool>('isMockLocationOn') ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// قراءة ساعة الرتابة الحقيقية (SystemClock.elapsedRealtime) —
  /// أساس العدل الزمني: لا تتأثر بتغيير المستخدم لساعة الهاتف الحائطية
  static Future<int> elapsedRealtime() async {
    try {
      return await _channel.invokeMethod<int>('elapsedRealtime') ??
          DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }
}

/// رابط بسيط لمصدر ساعة الرتابة (يُضبط عند الإقلاع ويرافقه timer للتصحيح)
abstract final class MonotonicClockBinder {
  static int? _base;
  static int? _baseWall;

  static void set(int elapsedRealtimeMs) {
    _base = elapsedRealtimeMs;
    _baseWall = DateTime.now().millisecondsSinceEpoch;
  }

  /// تقدير elapsedRealtime الحالي حتى لو القناة الأصلية غير متاحة
  static int now() {
    if (_base == null || _baseWall == null) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    return _base! + (DateTime.now().millisecondsSinceEpoch - _baseWall!);
  }
}

/// قراءة GPS الحالية (بإذن مسبق) — أو null
Future<Map<String, dynamic>?> currentPosition() async {
  try {
    final serviceOk = await Geolocator.isLocationServiceEnabled();
    if (!serviceOk) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'accuracy': pos.accuracy,
      'mocked': pos.isMocked,
    };
  } catch (_) {
    return null; // إشارة غائبة — القرار للسيرفر والإدارة
  }
}
