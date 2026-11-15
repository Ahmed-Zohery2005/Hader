// ============================================================================
// حاضر — اختبارات رياضيات الساعة (العدل الزمني للأوفلاين)
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:hader_employee/core/utils/clock_math.dart';

void main() {
  group('estimateServerNowMs — تقدير وقت السيرفر بمعزل عن ساعة الهاتف', () {
    test('المزامنة الأساسية: نفس اللحظة', () {
      const sync = ClockSyncPoint(serverTimeMs: 1000000, elapsedRealtimeMs: 5000);
      expect(estimateServerNowMs(sync, 5000), 1000000);
    });

    test('مرور 10 دقائق على ساعة الرتابة = 10 دقائق سيرفر', () {
      const sync = ClockSyncPoint(serverTimeMs: 1000000, elapsedRealtimeMs: 5000);
      expect(estimateServerNowMs(sync, 5000 + 600000), 1000000 + 600000);
    });

    test('انقلاب ساعة الرتابة (إعادة تشغيل) لا ينتج وقتًا ماضيًا كاذبًا', () {
      const sync = ClockSyncPoint(serverTimeMs: 1000000, elapsedRealtimeMs: 900000);
      // الرتابة رجعت للصفر بعد reboot — لا نسمح بقيمة سالبة
      expect(estimateServerNowMs(sync, 100), 1000000);
    });

    test('تغيير المستخدم لساعة الهاتف الحائطية لا يؤثر إطلاقًا (المصدر رتابة فقط)', () {
      const sync = ClockSyncPoint(serverTimeMs: 2000000, elapsedRealtimeMs: 10000);
      // لو الهاتف يقول أي شيء — الدالة لا ترى غير الرتابة
      expect(estimateServerNowMs(sync, 10000 + 120000), 2000000 + 120000);
    });
  });

  group('monotonicDeltaMs — فرق الرتابة المسجل مع التسجيل', () {
    test('الفرق بين لحظة التصوير وآخر مزامنة', () {
      const sync = ClockSyncPoint(serverTimeMs: 1000000, elapsedRealtimeMs: 1000);
      expect(monotonicDeltaMs(sync, 61000), 60000);
    });
  });

  group('isLateUpload — عتبة الرفع المتأخر (4 ساعات)', () {
    test('رفع فوري ليس متأخرًا', () {
      expect(isLateUpload(1000000, 1000000 + 60000), isFalse);
    });
    test('أكثر من 4 ساعات = ملاحظة تنبيهية (لا رفض)', () {
      expect(isLateUpload(1000000, 1000000 + 4 * 3600000 + 1), isTrue);
    });
    test('بالضبط 4 ساعات ليس متأخرًا', () {
      expect(isLateUpload(1000000, 1000000 + 4 * 3600000), isFalse);
    });
  });

  group('formatCountdown — عداد بطاقة الفحص', () {
    test('mm:ss', () {
      expect(formatCountdown(754500), '12:34');
      expect(formatCountdown(15 * 60000), '15:00');
      expect(formatCountdown(0), '00:00');
      expect(formatCountdown(-5000), '00:00');
    });
  });

  group('sinceArabic — الجمع المصري الصحيح', () {
    test('المفرد والمثنى والجمع للدقائق', () {
      expect(sinceArabic(60000), 'منذ دقيقة');
      expect(sinceArabic(120000), 'منذ دقيقتين');
      expect(sinceArabic(5 * 60000), 'منذ 5 دقايق');
      expect(sinceArabic(30 * 60000), 'منذ 30 دقيقة');
    });
    test('الساعات والأيام', () {
      expect(sinceArabic(3600000), 'منذ ساعة');
      expect(sinceArabic(2 * 3600000), 'منذ ساعتين');
      expect(sinceArabic(5 * 3600000), 'منذ 5 ساعات');
      expect(sinceArabic(26 * 3600000), 'منذ يوم');
      expect(sinceArabic(3 * 86400000), 'منذ 3 أيام');
    });
    test('الآن', () {
      expect(sinceArabic(0), 'الآن');
      expect(sinceArabic(-1000), 'الآن');
    });
  });
}
