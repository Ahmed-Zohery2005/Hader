// ============================================================================
// حاضر — معالج ضبط البطارية حسب مصنع الهاتف (الجزء 1 تجربة الاختراق + 3.2 خطوة 7)
// ============================================================================
// منطق نقي: تعرّف المصنع من Android.Build.MANUFACTURER (device_info_plus)
// وعرض الخطوات المصورة الدقيقة لكل نظام تشغيل مصري منتشر — لأن قاتل التطبيقات
// في الخلفية هو التحدي الأول للإشعارات على الهواتف الاقتصادية.
// ============================================================================

/// عائلة نظام التشغيل وقائمة خطوات الضبط المطلوبة
class BatteryWizardSteps {
  const BatteryWizardSteps({
    required this.osLabel,
    required this.steps,
    this.huaweiNoGmsWarning = false,
  });

  final String osLabel;
  final List<String> steps;

  /// هواوي بلا خدمات جوجل غير مدعومة على التطبيق الشخصي (إفصاح العقد)
  final bool huaweiNoGmsWarning;
}

/// التعرّف على عائلة النظام من اسم المصنع (case-insensitive — كما يأتي من الجهاز)
BatteryWizardSteps batteryWizardFor(String manufacturer) {
  final m = manufacturer.trim().toLowerCase();

  if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
    return BatteryWizardSteps(
      osLabel: 'شاومي (MIUI / HyperOS)',
      steps: [
        'افتح الإعدادات ← التطبيقات ← إدارة التطبيقات ← «حاضر»',
        'فعّل «التشغيل التلقائي» (Auto-start)',
        'من «استهلاك البطارية» اختار «لا قيود» (No restrictions)',
        'من الإعدادات ← البطارية والتأدية ← تأكد إن وضع التوفير مش شغال',
      ],
    );
  }
  if (m.contains('samsung')) {
    return BatteryWizardSteps(
      osLabel: 'سامسونج (One UI)',
      steps: [
        'افتح الإعدادات ← البطارية و العناية بالجهاز ← البطارية',
        'من «حدود الاستخدام بالخلفية» اختار «غير مقيّد» لتطبيق حاضر',
        'افتح «حاضر» من قائمة التطبيقات الأخيرة واضغط رمز القفل (لا تسرّبه أبدًا)',
      ],
    );
  }
  if (m.contains('oppo') || m.contains('realme')) {
    return BatteryWizardSteps(
      osLabel: 'أوبو / ريلمي (ColorOS)',
      steps: [
        'افتح الإعدادات ← البطارية ← خيارات تفصيلية بالتطبيقات ← «حاضر»',
        'فعّل «السماح بالتشغيل التلقائي» و«العمل بالخلفية»',
        'عطّل «تحسين استهلاك البطارية» لتطبيق حاضر',
      ],
    );
  }
  if (m.contains('vivo')) {
    return BatteryWizardSteps(
      osLabel: 'فيفو (Funtouch / OriginOS)',
      steps: [
        'افتح إدارة الهاتف (i Manager) ← إدارة التشغيل التلقائي ← فعّل «حاضر»',
        'من إعدادات البطارية: ألغِ «تنظيف الخلفية عالي الاستهلاك» لتطبيق حاضر',
      ],
    );
  }
  if (m.contains('tecno')) {
    return BatteryWizardSteps(
      osLabel: 'تكنو (HiOS)',
      steps: [
        'افتح Phone Master ← إدارة التشغيل التلقائي ← فعّل «حاضر»',
        'من الإعدادات ← البطارية ← عطّل توفير الطاقة لتطبيق حاضر',
      ],
    );
  }
  if (m.contains('infinix')) {
    return BatteryWizardSteps(
      osLabel: 'إنفينكس (XOS)',
      steps: [
        'افتح XOS Master / Phone Master ← التشغيل التلقائي ← فعّل «حاضر»',
        'ألغِ «تنظيف الذاكرة التلقائي» وقت تشغيل حاضر',
      ],
    );
  }
  if (m.contains('honor')) {
    return BatteryWizardSteps(
      osLabel: 'هونر (MagicOS)',
      steps: [
        'افتح الإعدادات ← البطارية ← تشغيل التطبيقات ← «حاضر»',
        'اختار «إدارة يدوية»: فعّل التشغيل التلقائي والتشغيل بالخلفية',
      ],
    );
  }
  if (m.contains('huawei')) {
    return const BatteryWizardSteps(
      osLabel: 'هواوي',
      steps: [
        'افتح الإعدادات ← البطارية ← تشغيل التطبيقات ← «حاضر» ← إدارة يدوية',
      ],
      // هواوي بلا GMS = إشعارات جوجل مستحيلة → الكشك أو الورق (إفصاح العقد)
      huaweiNoGmsWarning: true,
    );
  }

  // هاتف قياسي (Pixel/موتورولا/نوكيا…) — قيود أقل
  return const BatteryWizardSteps(
    osLabel: 'أندرويد قياسي',
    steps: [
      'تأكد إن «تحسين البطارية» لتطبيق حاضر على «غير مُحسَّن» (بدون قيود)',
      'فعّل إشعارات التطبيق من إعدادات النظام',
    ],
  );
}
