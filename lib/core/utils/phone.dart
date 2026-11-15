// ============================================================================
// حاضر — تطبيع الهاتف المصري إلى E.164 (منطق موحد مع _shared/crypto.ts حرفيًا)
// منطق نقي 100% بلا أي استيراد Flutter — قابل للاختبار المباشر
// ============================================================================

/// تطبيع رقم مصري أو دولي إلى صيغة E.164 — أو null لو غير صالح.
/// 01xxxxxxxxx → +201xxxxxxxxx | 201xxxxxxxxx → +201... | +201... كما هو
String? normalizePhone(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s\-()]'), '');
  // 01xxxxxxxxx (11 خانة محليًا — شرائح 010/011/012/015)
  if (RegExp(r'^01[0125][0-9]{8}$').hasMatch(cleaned)) return '+2$cleaned';
  // +201xxxxxxxxx
  if (RegExp(r'^\+201[0125][0-9]{8}$').hasMatch(cleaned)) return cleaned;
  // 201xxxxxxxxx بلا +
  if (RegExp(r'^201[0125][0-9]{8}$').hasMatch(cleaned)) return '+$cleaned';
  // أي رقم دولي صالح آخر
  if (RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(cleaned)) return cleaned;
  return null;
}

/// هل الرقم مصري محلي (يبدأ بـ 01)؟ — لعرض تنبيه الشريحتين
bool isLocalEgyptian(String input) =>
    RegExp(r'^01[0125][0-9]{8}$').hasMatch(input.trim());
