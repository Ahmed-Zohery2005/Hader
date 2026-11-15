// ============================================================================
// حاضر — الإعدادات المدمجة وقت البناء (--dart-define — لا تُكتب في الكود)
// كل قيمة تمرر من سطر بناء الإنتاج (راجع DEPLOYMENT_AR.md § التطبيق)
// ============================================================================

/// روابط Supabase (نفس قيم بوابة Kong الموحدة :8000 في التوطين المحلي)
const String kSupabaseUrl = String.fromEnvironment(
  'HADER_SUPABASE_URL',
  defaultValue: 'http://10.0.2.2:8000', // محاكي أندرويد → localhost للحزمة المحلية
);

/// مفتاح anon العام (لا يحمل أي سر — الحماية عبر RLS)
const String kSupabaseAnonKey = String.fromEnvironment(
  'HADER_SUPABASE_ANON_KEY',
  defaultValue: 'CHANGE_ME_ANON_KEY',
);

/// سر فك جدول الصباح المشفر AES-256-GCM (المستوى الثاني)
/// نفس قيمة SPOT_SCHEDULE_SECRET في بيئة الدوال الطرفية.
/// الحماية الفعلية: Play Integrity (هاتف مكسور يُكشف ويُراجع إداريًا).
const String kScheduleSecret = String.fromEnvironment(
  'HADER_SCHEDULE_SECRET',
  defaultValue: 'hader-dev-schedule-secret',
);

/// رقم واتساب الدعم الفني (بصيغة دولية بلا +)
const String kSupportWhatsapp = String.fromEnvironment(
  'HADER_SUPPORT_WHATSAPP',
  defaultValue: '201000000000',
);

/// إصدار الموافقة القانونية (يتغير فقط مع مراجعة المحامي)
const String kConsentVersion = 'v1.0-2026-11';
