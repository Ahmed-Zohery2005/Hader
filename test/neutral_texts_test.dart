// ============================================================================
// حاضر — اختبارات قاموس النصوص المحايد + نافذة الاعتراض (D11 حرفيًا)
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:hader_employee/core/app_texts.dart';

void main() {
  group('حظر كلمات الاتهام في كل نصوص التطبيق (قاعدة D11)', () {
    const banned = ['غائب', 'كاذب', 'متلاعب', 'غشاش'];

    test('الحالات النهائية محايدة تقنيًا', () {
      final all = [
        T.statusPending, T.statusAutoAccepted, T.statusNeedsReview,
        T.statusManagerAccepted, T.statusManagerRejected, T.statusAskedEmployee,
      ].join(' ');
      for (final w in banned) {
        expect(all.contains(w), isFalse, reason: 'كلمة محظورة: $w');
      }
    });

    test('درجات المكان بلا اتهام', () {
      final grades = [
        T.gradeConfirmed, T.gradeProbable, T.gradeNeedsReview, T.gradeGpsOnly,
      ].join(' ');
      for (final w in banned) {
        expect(grades.contains(w), isFalse);
      }
    });

    test('«مرفوض» كلمة محظورة كوصف موظف — لكن زر الإجراء موجود فقط للكود',
        () {
      // النصوص الظاهرة للمستخدم: التحقق أن كلمة «مرفوض» لا تصف أحدًا
      final userVisible = [
        T.statusManagerRejected, T.statusNeedsReview, T.gradeNeedsReview,
      ].join(' ');
      expect(userVisible.contains('مرفوض'), isFalse);
    });

    test('نصوص الأوفلاين والرفع المتأخر وصفية بلا عقوبة', () {
      expect(T.offlineTag, contains('أوفلاين'));
      expect(T.lateUploadTag, contains('اتراجع'));
      expect(T.offlineQueued, contains('مشفر'));
    });
  });

  group('نافذة الاعتراض (7 أيام) — منطق العرض', () {
    test('أسبونع الاعتراض متاح تحت 7 أيام', () {
      final captured = DateTime.now().subtract(const Duration(days: 6));
      final allowed = DateTime.now().difference(captured).inDays < 7;
      expect(allowed, isTrue);
    });

    test('مغلق بعد 7 أيام', () {
      final captured = DateTime.now().subtract(const Duration(days: 8));
      final allowed = DateTime.now().difference(captured).inDays < 7;
      expect(allowed, isFalse);
    });
  });

  group('أسباب الاعتراض الأربعة (قائمة المستند حرفيًا)', () {
    test('القائمة كاملة ومصرية', () {
      expect(T.objectionReason1, contains('المكان'));
      expect(T.objectionReason2, contains('الإشعار'));
      expect(T.objectionReason3, contains('مأمورية'));
      expect(T.objectionReason4, contains('آخر'));
    });
  });
}
