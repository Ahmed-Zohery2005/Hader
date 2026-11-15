// ============================================================================
// حاضر — معالجة الفيديو: ضغط H.264 480p ~1Mbps + بصمة SHA-256 (خطوتا 7-8)
// ============================================================================
// المُخرَج المستهدف (المستند): ملف 1–1.25 ميجابايت (بمتوسط 1.1) — خفيف على
// باقة الموظف وسريع الرفع على شبكات مصر. البصمة تُحسب على الملف النهائي
// المضغوط (هي التي تتطابق على السيرفر — تعديل أي بايت يكسرها).
// ============================================================================

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:video_compress/video_compress.dart';

class ProcessedVideo {
  ProcessedVideo({
    required this.path,
    required this.sizeBytes,
    required this.sha256,
    required this.durationMs,
  });

  final String path;
  final int sizeBytes;
  final String sha256; // hex صغير — نفس صيغة السيرفر
  final int durationMs;

  /// متوسط معدل البت المُحقق (ميجابت/ث) — للعرض التشخيصي فقط
  double get approxMbps => (sizeBytes * 8 / 1000000) / (durationMs / 1000);
}

class VideoProcessor {
  /// ضغط إلى H.264 بجودة Medium (480p تلقائيًا) ثم حساب SHA-256 للناتج
  static Future<ProcessedVideo> process(String rawPath, int recordedMs) async {
    final info = await VideoCompress.compressVideo(
      rawPath,
      quality: VideoQuality.MediumQuality, // 480p
      deleteOrigin: false, // نمسح يدويًا بعد الحساب — تحكم صريح
      includeAudio: true, // الرقم المنطوق هو جوهر التحقق
    );
    final outPath = info?.path ?? rawPath;
    final file = File(outPath);
    final bytes = await file.readAsBytes();

    // مسح النسخة الخام الأصلية فور اكتمال الضغط (خصوصية بالتصميم)
    if (rawPath != outPath) {
      final raw = File(rawPath);
      if (await raw.exists()) await raw.delete();
    }

    return ProcessedVideo(
      path: outPath,
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      durationMs: recordedMs,
    );
  }

  /// حساب بصمة ملف (لإعادة التحقق من عنصر طابور الأوفلاين قبل رفعه)
  static Future<String> hashFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
