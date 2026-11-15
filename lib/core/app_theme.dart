// ============================================================================
// حاضر — السمات البصرية: نفس رموز الهوية المؤسسية في الويب حرفيًا
// (brand/brand-guidelines.md — الزمرد المؤسسي والورق الدافئ)
// ============================================================================

import 'package:flutter/material.dart';

abstract final class AppColors {
  /// الورق الدافئ — خلفية التطبيق
  static const Color canvas = Color(0xFFF8F7F4);

  /// سطح البطاقات
  static const Color surface = Color(0xFFFFFFFF);

  /// الحدود الشعرية
  static const Color hairline = Color(0xFFE5E3DC);

  /// الزمرد المؤسسي («حاضر» والقبول والاطمئنان)
  static const Color brand = Color(0xFF0F6E56);
  static const Color brandHover = Color(0xFF0B5643);
  static const Color brandDeep = Color(0xFF064E3B);
  static const Color brandTint = Color(0xFFECFDF5);

  /// ألوان الحبر
  static const Color ink = Color(0xFF141B24);
  static const Color ink2 = Color(0xFF4B5563);
  static const Color ink3 = Color(0xFF78716C);

  /// الدلالات الوظيفية الصارمة (لا خلط بينها)
  static const Color ok = Color(0xFF15803D);
  static const Color info = Color(0xFF0369A1);
  static const Color warn = Color(0xFFD97706); // محتاج نظرك — تنبيه غير اتهامي
  static const Color danger = Color(0xFFDC2626); // تحذير أمني مؤكد فقط

  static const Color okSoft = Color(0xFFECFDF5);
  static const Color infoSoft = Color(0xFFE0F2FE);
  static const Color warnSoft = Color(0xFFFEF3C7);
  static const Color dangerSoft = Color(0xFFFEE2E2);
}

/// عائلة الخط: IBM Plex Sans Arabic (مدمجة كأصول — انظر assets والـ pubspec)
abstract final class AppFonts {
  static const String arabic = 'IBM Plex Sans Arabic';
  static const String mono = 'IBM Plex Mono';
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: AppFonts.arabic,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      elevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.arabic,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(
          fontFamily: AppFonts.arabic,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: AppColors.hairline),
        textStyle: const TextStyle(
          fontFamily: AppFonts.arabic,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.hairline),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontFamily: AppFonts.arabic, fontSize: 14),
    ),
  );
}
