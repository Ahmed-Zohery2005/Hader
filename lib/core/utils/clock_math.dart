// ============================================================================
// حاضر — رياضيات ساعة السيرفر وساعة الرتابة (الأساس الأمني للأوفلاين)
// ============================================================================
// المبدأ الدستوري (الجزء 3.4 خطوة 2): «توقيت السيرفر هو الحقيقة الوحيدة».
// ساعة الهاتف الحائطية تُتجاهل تمامًا — يعتد بـ:
//   * آخر وقت سيرفر معروف (ServerClockSync) عند آخر تواصل ناجح
//   * ساعة الرتابة (elapsedRealtime) التي لا تتأثر بتغيير ساعة المستخدم
//
// وقت التصوير الحقيقي = lastServerTime + (elapsedNow - elapsedAtLastSync)
// (الهدف: تعديل ساعة الهاتف لا يخفي تأخيرًا ولا يزوّر حضورًا مبكرًا)
// ============================================================================

/// نقطة مزامنة واحدة: وقت سيرفر معروف + قراءة ساعة الرتابة وقت معرفته
class ClockSyncPoint {
  const ClockSyncPoint({
    required this.serverTimeMs,
    required this.elapsedRealtimeMs,
  });

  final int serverTimeMs;
  final int elapsedRealtimeMs;
}

/// تقدير وقت السيرفر «الآن» بمعزل عن تلاعب المستخدم بساعة الهاتف
int estimateServerNowMs(ClockSyncPoint sync, int elapsedRealtimeNowMs) {
  final delta = elapsedRealtimeNowMs - sync.elapsedRealtimeMs;
  // حماية من انقلاب ساعة الرتابة (إعادة تشغيل): لا نسمح بقيم سالبة كاذبة
  final safeDelta = delta < 0 ? 0 : delta;
  return sync.serverTimeMs + safeDelta;
}

/// فرق الرتابة المسجل مع التسجيل الأوفلاين (client_monotonic_delta_ms)
/// = كم مضى من ساعة الرتابة بين لحظة التصوير وآخر مزامنة سيرفر ناجحة
int monotonicDeltaMs(ClockSyncPoint sync, int elapsedAtCaptureMs) {
  return elapsedAtCaptureMs - sync.elapsedRealtimeMs;
}

/// هل التسجيل الأوفلاين «رفع متأخر» (أكثر من 4 ساعات عن وقت تصويره)?
/// المستند (الجزء 3.11): يُقبل مع ملاحظة تنبيهية للمدير — ليس رفضًا أبدًا
bool isLateUpload(int capturedAtMs, int uploadedAtMs) =>
    uploadedAtMs - capturedAtMs > 4 * 3600 * 1000;

/// تنسيق العداد التنازلي «12:45» من milliseconds متبقية
String formatCountdown(int msLeft) {
  final s = msLeft < 0 ? 0 : msLeft ~/ 1000;
  final mm = (s ~/ 60).toString().padLeft(2, '0');
  final ss = (s % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// صيغة جمع مصرية صحيحة للفترات: «منذ 5 دقايق»
String sinceArabic(int msAgo) {
  final mins = msAgo < 0 ? 0 : msAgo ~/ 60000;
  if (mins < 1) return 'الآن';
  if (mins == 1) return 'منذ دقيقة';
  if (mins == 2) return 'منذ دقيقتين';
  if (mins <= 10) return 'منذ $mins دقايق';
  if (mins < 60) return 'منذ $mins دقيقة';
  final hours = mins ~/ 60;
  if (hours == 1) return 'منذ ساعة';
  if (hours == 2) return 'منذ ساعتين';
  if (hours <= 10) return 'منذ $hours ساعات';
  if (hours < 24) return 'منذ $hours ساعة';
  final days = hours ~/ 24;
  if (days == 1) return 'منذ يوم';
  if (days == 2) return 'منذ يومين';
  if (days <= 10) return 'منذ $days أيام';
  return 'منذ $days يوم';
}
