// ============================================================================
// حاضر — اختبارات معالج البطارية بالمصنعين + تطبيع الهاتف
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:hader_employee/core/utils/phone.dart';
import 'package:hader_employee/features/activation/battery_wizard.dart';

void main() {
  group('batteryWizardFor — التعرّف على عائلة النظام', () {
    _case('Xiaomi', 'شاومي');
    _case('Redmi', 'شاومي');
    _case('POCO', 'شاومي');
    _case('samsung', 'سامسونج');
    _case('OPPO', 'أوبو / ريلمي');
    _case('realme', 'أوبو / ريلمي');
    _case('vivo', 'فيفو');
    _case('TECNO', 'تكنو');
    _case('Infinix', 'إنفينكس');
    _case('HONOR', 'هونر');
    _case('HUAWEI', 'هواوي');
    _case('Google', 'أندرويد قياسي');
    _case('motorola', 'أندرويد قياسي');

    test('هواوي فقط تحمل تحذير بلا خدمات جوجل', () {
      expect(batteryWizardFor('Huawei').huaweiNoGmsWarning, isTrue);
      expect(batteryWizardFor('Honor').huaweiNoGmsWarning, isTrue);
      expect(batteryWizardFor('Samsung').huaweiNoGmsWarning, isFalse);
      expect(batteryWizardFor('Xiaomi').huaweiNoGmsWarning, isFalse);
    });

    test('كل معالج فيه خطوات مكتوبة (بلا فراغات)', () {
      for (final m in [
        'Xiaomi', 'Samsung', 'OPPO', 'vivo', 'TECNO', 'Infinix', 'Honor',
        'Huawei', 'Google',
      ]) {
        final w = batteryWizardFor(m);
        expect(w.steps, isNotEmpty, reason: m);
        expect(w.osLabel, isNotEmpty);
        for (final s in w.steps) {
          expect(s.length, greaterThan(10), reason: '$m: خطوة فارغة');
        }
      }
    });
  });

  group('normalizePhone — موحد مع crypto.ts حرفيًا', () {
    test('محلي 01 → +2', () {
      expect(normalizePhone('01012345678'), '+201012345678');
      expect(normalizePhone('011 1234 5678'), '+201112345678');
      expect(normalizePhone('012-12345678'), '+201212345678');
      expect(normalizePhone('01512345678'), '+201512345678');
    });
    test('بادئة دولية موجودة', () {
      expect(normalizePhone('+201012345678'), '+201012345678');
      expect(normalizePhone('201012345678'), '+201012345678');
    });
    test('دولي آخر يمر', () {
      expect(normalizePhone('+966501234567'), '+966501234567');
    });
    test('أرقام مكسورة مرفوضة', () {
      expect(normalizePhone('0101234567'), isNull); // 10 خانات
      expect(normalizePhone('01612345678'), isNull); // بادئة غير موجودة
      expect(normalizePhone('abc'), isNull);
      expect(normalizePhone(''), isNull);
      expect(normalizePhone('+2010123456789'), isNull); // زيادة
    });
  });
}

void _case(String manufacturer, String expectedLabel) {
  test('$manufacturer → $expectedLabel', () {
    expect(batteryWizardFor(manufacturer).osLabel, contains(expectedLabel));
  });
}
