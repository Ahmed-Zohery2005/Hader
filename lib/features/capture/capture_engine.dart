// ============================================================================
// حاضر — آلة حالة محرك التصوير (العشر خطوات — الجزء 3.4)
// ============================================================================
// منطق نقي 100%: الانتقالات والحراس والأزمنة قابلة للاختبار الكامل بلا كاميرا.
// الشاشة (capture_screen) مجرد عرض لهذه الآلة — والآلة مصدر الحقيقة.
//
// الخطوات العشر:
//  1 idle → 2 requestingToken → 3 showingDigits (البوابة: وجه واحد بإضاءة كافية)
//  → 4 recording (8..10 ثوانٍ — لا إيقاف قبل 8 وتوقف تلقائي عند 10)
//  → 5 collectingSignals → 6 compressing (H.264 480p) → 7 hashing (SHA-256)
//  → 8 uploading (presign PUT) أو offlineQueued → 9 registering (register-capture)
//  → 10 done (مسح الملف المحلي فور تأكيد الوصول)
// ============================================================================

enum CapturePhase {
  idle,
  requestingToken,
  showingDigits,
  recording,
  collectingSignals,
  compressing,
  hashing,
  uploading,
  offlineQueued,
  registering,
  done,
  failed,
}

enum CaptureKind { checkIn, checkOut, spotCheck, kiosk, practice }

/// حارس بوابة الوجه (ML Kit): وجه واحد واضح بإضاءة مقبولة قبل بدء العداد
class FaceGate {
  const FaceGate({
    required this.faceCount,
    required this.brightnessOk,
    required this.faceAreaRatio,
  });

  final int faceCount;
  final bool brightnessOk;
  final double faceAreaRatio;

  bool get ready => faceCount == 1 && brightnessOk && faceAreaRatio >= 0.08;

  String? get hint {
    if (faceCount == 0) return 'وشك مش باين في الكادر';
    if (faceCount > 1) return 'فيه أكتر من وجه في الكادر — سجل لوحدك';
    if (!brightnessOk) return 'النور ضعيف جدًا — روح مكان أنور';
    if (faceAreaRatio < 0.08) return 'قرّب الموبايل شوية';
    return null;
  }
}

/// قواعد المدة الدستورية: 8 ثوانٍ إلزامية، 10 سقف تلقائي (الجزء 3.4 خطوة 5)
abstract final class CaptureTiming {
  static const int minMs = 8000;
  static const int maxMs = 10000;
  static const int tokenExpiryMs = 15 * 60 * 1000;
  static const int lateUploadThresholdMs = 4 * 3600 * 1000;

  /// هل يُسمح بإيقاف التسجيل الآن؟ (ممنوع قبل الثامنة)
  static bool canStopRecording(int elapsedMs) => elapsedMs >= minMs;

  /// هل يتوقف التسجيل تلقائيًا؟ (الثانية العاشرة)
  static bool shouldAutoStop(int elapsedMs) => elapsedMs >= maxMs;

  /// صلاحية مدة الفيديو لقبول السيرفر (7000..12000 كما في قيود الجدول)
  static bool isValidDuration(int durationMs) =>
      durationMs >= 7000 && durationMs <= 12000;
}

/// نتيجة خطوة من آلة الحالة
class CaptureStepResult {
  const CaptureStepResult({required this.phase, this.error, this.payload});
  final CapturePhase phase;
  final String? error;
  final Object? payload;
}

/// آلة الحالة النقية: تُدار بالأحداث وتحدد الانتقال المشروع — الشاشة تنفذ فقط
class CaptureStateMachine {
  CapturePhase _phase = CapturePhase.idle;
  CapturePhase get phase => _phase;

  String? lastError;

  void reset() {
    _phase = CapturePhase.idle;
    lastError = null;
  }

  void tokenRequested() {
    assert(_phase == CapturePhase.idle);
    _phase = CapturePhase.requestingToken;
  }

  /// نجاح إصدار التصريح → عرض الرقم (مع بيانات التحدي)
  CaptureStepResult tokenIssued() {
    if (_phase != CapturePhase.requestingToken) {
      return _illegal();
    }
    _phase = CapturePhase.showingDigits;
    return const CaptureStepResult(phase: CapturePhase.showingDigits);
  }

  /// فشل إصدار التصريح → أوفلاين (للحضور/الانصراف فقط — الفحص لا يوجد له توكن محلي)
  CaptureStepResult tokenFailed({required bool allowOffline}) {
    if (_phase != CapturePhase.requestingToken) return _illegal();
    _phase = allowOffline
        ? CapturePhase.collectingSignals // تصريح محلي + وسم أوفلاين عند التسجيل
        : CapturePhase.failed;
    lastError = allowOffline ? null : 'تعذر إصدار التصريح — جرب تاني';
    return CaptureStepResult(phase: _phase, error: lastError);
  }

  /// بدأ التسجيل الفعلي (بعد اجتياز بوابة الوجه)
  CaptureStepResult recordingStarted(FaceGate gate) {
    if (_phase != CapturePhase.showingDigits) return _illegal();
    if (!gate.ready) {
      return CaptureStepResult(
        phase: CapturePhase.showingDigits,
        error: gate.hint ?? 'استنى ظهور وشك في الكادر',
      );
    }
    _phase = CapturePhase.recording;
    return const CaptureStepResult(phase: CapturePhase.recording);
  }

  /// انتهى التسجيل بمدة دستورية سليمة
  CaptureStepResult recordingFinished(int durationMs) {
    if (_phase != CapturePhase.recording) return _illegal();
    if (!CaptureTiming.isValidDuration(durationMs)) {
      _phase = CapturePhase.failed;
      lastError = 'مدة الفيديو لازم بين 8 و 10 ثواني — صوّر من الأول';
      return CaptureStepResult(phase: _phase, error: lastError);
    }
    _phase = CapturePhase.collectingSignals;
    return const CaptureStepResult(phase: CapturePhase.collectingSignals);
  }

  CaptureStepResult signalsCollected() {
    if (_phase != CapturePhase.collectingSignals) return _illegal();
    _phase = CapturePhase.compressing;
    return const CaptureStepResult(phase: CapturePhase.compressing);
  }

  CaptureStepResult compressed() {
    if (_phase != CapturePhase.compressing) return _illegal();
    _phase = CapturePhase.hashing;
    return const CaptureStepResult(phase: CapturePhase.hashing);
  }

  CaptureStepResult hashed() {
    if (_phase != CapturePhase.hashing) return _illegal();
    _phase = CapturePhase.uploading;
    return const CaptureStepResult(phase: CapturePhase.uploading);
  }

  /// الرفع نجح → التسجيل عند السيرفر | فشل مؤقت → طابور أوفلاين مشفر
  CaptureStepResult uploadFinished({required bool ok}) {
    if (_phase != CapturePhase.uploading) return _illegal();
    _phase = ok ? CapturePhase.registering : CapturePhase.offlineQueued;
    return CaptureStepResult(phase: _phase);
  }

  CaptureStepResult registered() {
    if (_phase != CapturePhase.registering) return _illegal();
    _phase = CapturePhase.done;
    return const CaptureStepResult(phase: CapturePhase.done);
  }

  /// التسجيل عند السيرفر فشل بعد نجاح الرفع → الطابور (بيانات الرفع محفوظة)
  CaptureStepResult registerFailed() {
    if (_phase != CapturePhase.registering) return _illegal();
    _phase = CapturePhase.offlineQueued;
    return const CaptureStepResult(phase: CapturePhase.offlineQueued);
  }

  CaptureStepResult _illegal() {
    lastError = 'خطوة غير متوقعة — ابدأ التسجيل من الأول';
    return CaptureStepResult(phase: _phase, error: lastError);
  }
}
