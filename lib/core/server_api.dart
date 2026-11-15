// ============================================================================
// حاضر — عميل الدوال الطرفية والاستعلامات (طبقة الشبكة الوحيدة للتطبيق)
// ============================================================================
// * الكتابات كلها عبر الدوال الطرفية (قرار D40) — بجلسة Supabase (Bearer تلقائي)
// * القراءات المباشرة (سجلي/الإشعارات) عبر PostgREST نفسها داخل سياق RLS
// * كل رد فيه server_time يُغذّي مزامنة الساعة (ServerClockSync)
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'session.dart';
import 'utils/phone.dart';

/// غلاف استجابة الدوال الطرفية: {ok, ...} | {ok:false, error}
class FnResult<T> {
  FnResult(this.ok, this.data, this.error);
  final bool ok;
  final T? data;
  final String? error;

  factory FnResult.fail(String e) => FnResult<T>(false, null, e);
  factory FnResult.ok_(T d) => FnResult<T>(true, d, null);
}

class ServerApi {
  ServerApi(this._sb);
  final SupabaseClient _sb;

  static SupabaseClient createClient() => SupabaseClient(
        kSupabaseUrl,
        kSupabaseAnonKey,
        authOptions: const AuthClientOptions(
          // جلسة طويلة الأمد محفوظة آمنة — لا OTP يوميًا (ربط الجهاز بديلها)
          persistSession: true,
        ),
      );

  // ------------------------------------------------------------------
  // التفعيل (الجزء 3.2)
  // ------------------------------------------------------------------

  /// الخطوة 3: التحقق من كود الدعوة (القواعد الأربع على السيرفر)
  Future<FnResult<Map<String, dynamic>>> verifyInvite({
    required String phone,
    required String inviteCode,
  }) async {
    final e164 = normalizePhone(phone);
    if (e164 == null) {
      return FnResult.fail('اكتب رقم موبايل مصري صالح (مثال: 01012345678)');
    }
    return _fn('verify-invite', {'phone': e164, 'invite_code': inviteCode.trim()});
  }

  /// الخطوة 4: إرسال OTP (Supabase Auth الأصلي على نفس الرقم)
  Future<FnResult<void>> sendOtp(String phone) async {
    final e164 = normalizePhone(phone);
    if (e164 == null) return FnResult.fail('رقم الموبايل مش صالح');
    try {
      await _sb.auth.signInWithOtp(phone: e164);
      return FnResult.ok_(null);
    } on AuthException catch (e) {
      return FnResult.fail(_friendlyAuth(e.message));
    } catch (_) {
      return FnResult.fail('تعذر إرسال الرمز — تأكد من الشبكة وجرب تاني');
    }
  }

  /// الخطوة 4: التحقق من OTP → جلسة دائمة
  Future<FnResult<void>> verifyOtp(String phone, String code) async {
    final e164 = normalizePhone(phone);
    if (e164 == null) return FnResult.fail('رقم الموبايل مش صالح');
    try {
      await _sb.auth.verifyOTP(
        phone: e164,
        token: code.replaceAll(RegExp(r'\D'), ''),
        type: OtpType.sms,
      );
      return FnResult.ok_(null);
    } on AuthException catch (e) {
      return FnResult.fail(_friendlyAuth(e.message));
    } catch (_) {
      return FnResult.fail('الرمز مش صح — جرب تاني');
    }
  }

  /// الخطوة 4-5: ربط الجهاز + تسجيل القرار القانوني (complete-activation)
  Future<FnResult<Map<String, dynamic>>> completeActivation({
    required DeviceIdentity device,
    required bool consentAccepted,
    String? playIntegrityToken,
  }) async {
    return _fn('complete-activation', {
      'device_id': device.deviceId,
      'device_model': device.model,
      'device_manufacturer': device.manufacturer,
      'play_integrity_token': playIntegrityToken,
      'consent_decision': consentAccepted ? 'accepted' : 'declined_manual_fallback',
      'consent_version': kConsentVersion,
    });
  }

  // ------------------------------------------------------------------
  // دورة التصوير (الجزء 3.4)
  // ------------------------------------------------------------------

  /// الخطوة 2: تصريح التصوير (وفي الحضور: جدول الصباح المشفر)
  Future<FnResult<Map<String, dynamic>>> issueCaptureToken({
    required String captureType, // check_in | check_out | spot_check
    String? spotCheckId,
  }) async {
    return _fn('issue-capture-token', {
      'capture_type': captureType,
      if (spotCheckId != null) 'spot_check_id': spotCheckId,
    });
  }

  /// الخطوة 8: رابط الرفع المؤقت (بعد التحقق من التصريح على السيرفر)
  Future<FnResult<Map<String, dynamic>>> presignUpload(String tokenId) =>
      _fn('r2-presign', {'mode': 'upload', 'token_id': tokenId});

  /// رابط رفع لتسجيل أوفلاين (بلا تصريح — يوسم على السيرفر للمراجعة)
  Future<FnResult<Map<String, dynamic>>> presignOfflineUpload() =>
      _fn('r2-presign', {'mode': 'offline_upload'});

  /// رابط رفع السيلفي المرجعي
  Future<FnResult<Map<String, dynamic>>> presignSelfie() =>
      _fn('r2-presign', {'mode': 'selfie'});

  /// الخطوة 10: تسجيل الفيديو بعد رفعه (المسار الكامل للأوفلاين أيضًا)
  Future<FnResult<Map<String, dynamic>>> registerCapture({
    required String captureId,
    required String objectKey,
    required String videoSha256,
    required int durationMs,
    String? tokenId,
    String? signature,
    bool isOffline = false,
    String? capturedAtClient,
    int? monotonicDeltaMs,
    Map<String, dynamic>? gps,
    List<Map<String, dynamic>>? bssids,
    bool? mockDetected,
    String? playIntegrityVerdict,
    bool? livenessPassed,
    Map<String, dynamic>? faceMeta,
    String? kioskUserId,
  }) async {
    return _fn('register-capture', {
      'capture_id': captureId,
      'token_id': tokenId,
      'signature': signature,
      'object_key': objectKey,
      'video_sha256': videoSha256,
      'duration_ms': durationMs,
      'is_offline': isOffline,
      'captured_at_client': capturedAtClient,
      'monotonic_delta_ms': monotonicDeltaMs,
      'gps': gps,
      'bssids': bssids,
      'mock_detected': mockDetected,
      'play_integrity_verdict': playIntegrityVerdict,
      'liveness_passed': livenessPassed,
      'face_meta': faceMeta,
      if (kioskUserId != null) 'kiosk_user_id': kioskUserId,
    });
  }

  // ------------------------------------------------------------------
  // الفحص المفاجئ (الجزء 3.3/3.7)
  // ------------------------------------------------------------------

  /// تأكيد وصول الإشعار (المستوى الأول — تثبيت المهلة من لحظة الوصول)
  Future<FnResult<Map<String, dynamic>>> ackSpotCheck(String spotCheckId) =>
      _fn('spot-check-actions', {'spot_check_id': spotCheckId, 'action': 'ack'});

  /// حق التأجيل لمرة واحدة 10 دقائق
  Future<FnResult<Map<String, dynamic>>> snoozeSpotCheck(String spotCheckId) =>
      _fn('spot-check-actions', {'spot_check_id': spotCheckId, 'action': 'snooze'});

  /// نبضة الاتصال (أي إشارة حياة) + الفحص اللحظي (المستوى الثالث)
  Future<FnResult<Map<String, dynamic>>> heartbeat({
    int? batteryPct,
    bool? powerSaveOn,
  }) =>
      _fn('heartbeat', {
        if (batteryPct != null) 'battery_pct': batteryPct,
        if (powerSaveOn != null) 'power_save_on': powerSaveOn,
      });

  /// تسجيل/تجديد توكن FCM
  Future<FnResult<Map<String, dynamic>>> registerPushToken(
    String token, {
    bool deactivatePrevious = false,
  }) =>
      _fn('register-push-token', {
        'token': token,
        'platform': 'android',
        'deactivate_previous': deactivatePrevious,
      });

  // ------------------------------------------------------------------
  // إجراءات الموظف (employee-actions — الجلسة 5)
  // ------------------------------------------------------------------

  Future<FnResult<Map<String, dynamic>>> submitObjection({
    required String captureId,
    required String presetReason,
    String? note,
  }) =>
      _fn('employee-actions', {
        'action': 'submit_objection',
        'capture_id': captureId,
        'preset_reason': presetReason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  Future<FnResult<Map<String, dynamic>>> requestSelfieUpdate(String r2Key) =>
      _fn('employee-actions', {'action': 'request_selfie_update', 'selfie_r2_key': r2Key});

  Future<FnResult<Map<String, dynamic>>> revokeConsent() =>
      _fn('employee-actions', {'action': 'revoke_consent'});

  Future<FnResult<Map<String, dynamic>>> kioskUnlock(String pin) =>
      _fn('employee-actions', {'action': 'kiosk_unlock', 'pin': pin});

  /// مشاهدة فيديو تسجيلي أنا (شفافية سجلي — رابط 5 دقائق)
  Future<FnResult<Map<String, dynamic>>> requestOwnVideoUrl(String captureId) =>
      _fn('r2-presign', {'mode': 'view', 'capture_id': captureId});

  // ------------------------------------------------------------------
  // قراءات مباشرة عبر RLS (سجلي / الإشعارات / الرئيسية)
  // ------------------------------------------------------------------

  /// تسجيلاتي آخر 7 أيام (سياسة captures_select_scope تجبر النافذة)
  Future<List<Map<String, dynamic>>> myCaptures() async {
    final rows = await _sb
        .from('captures')
        .select(
          'id, capture_type, captured_at_server, uploaded_at, late_upload_advisory, '
          'client_monotonic_delta_ms, location_grade, audio_status, final_status, '
          'review_reason_ar, r2_object_key, media_deleted_at',
        )
        .order('captured_at_server', ascending: false)
        .limit(120);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// الفحص النشط الآن (عند فتح التطبيق — المستوى الثالث)
  Future<Map<String, dynamic>?> activeSpotCheck() async {
    final rows = await _sb
        .from('spot_checks')
        .select('id, scheduled_at, deadline_at, is_followup_check, snoozed_once')
        .eq('outcome_state', 'pending')
        .not('notification_sent_at', 'is', null)
        .order('scheduled_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  /// إشعاراتي الزمنية
  Future<List<Map<String, dynamic>>> myNotifications() async {
    final rows = await _sb
        .from('notifications')
        .select('id, notification_type, title_ar, body_ar, read_at, created_at')
        .order('created_at', ascending: false)
        .limit(80);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// وسم إشعار كمقروء (سياسة notifications_mark_read_own — تحديث مباشر مشروع)
  Future<void> markNotificationRead(String id) async {
    await _sb
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _sb.auth.currentUser?.id ?? '');
  }

  /// نسخة الوردية النشطة الآن (لعرض مواعيد الدوام في الرئيسية)
  Future<Map<String, dynamic>?> activeShift() async {
    final rows = await _sb
        .from('shift_instances')
        .select('id, starts_at, ends_at, shifts(name_ar, start_time, end_time)')
        .order('starts_at', ascending: false)
        .limit(5);
    final now = DateTime.now().toUtc();
    for (final r in rows) {
      final s = DateTime.parse(r['starts_at'] as String).toUtc();
      final e = DateTime.parse(r['ends_at'] as String).toUtc();
      if (!s.isAfter(now) && !e.isBefore(now)) return Map<String, dynamic>.from(r);
    }
    return null;
  }

  // ------------------------------------------------------------------
  // داخلي
  // ------------------------------------------------------------------

  Future<FnResult<Map<String, dynamic>>> _fn(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _sb.functions.invoke(name, body: body);
      final data = Map<String, dynamic>.from(res.data as Map? ?? {});
      // تغذية مزامنة الساعة من أي رد يحمل توقيتًا سيرفريًا
      final serverTime = data['server_time'] ??
          data['issued_server_time'] ??
          data['now'];
      if (serverTime is String) {
        await ServerClockSync().sync(serverTime, MonotonicClock.now());
      }
      if (data['ok'] == true) return FnResult.ok_(data);
      return FnResult.fail(
        (data['error'] as String?) ?? 'حصلت مشكلة — جرب تاني',
      );
    } on FunctionException catch (e) {
      final d = e.data;
      if (d is Map && d['error'] is String) {
        return FnResult.fail(d['error'] as String);
      }
      return FnResult.fail('حصلت مشكلة — جرب تاني');
    } catch (_) {
      return FnResult.fail('النت شكله مقطوع — جرّب تاني أول ما ترجع الشبكة');
    }
  }

  static String _friendlyAuth(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid credentials') || m.contains('token')) {
      return 'الرمز مش صح — راجعه واكتبه تاني';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'محاولات كتير — استنى دقيقة وجرب تاني';
    }
    if (m.contains('phone')) {
      return 'مش قادرين نبعتب على الرقم ده — تأكد منه وجرّب تاني';
    }
    return 'حصلت مشكلة في الدخول — جرب تاني';
  }
}
