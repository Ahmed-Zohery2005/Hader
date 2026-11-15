// ============================================================================
// حاضر — اختبارات آلة حالة التصوير (العشر خطوات)
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:hader_employee/features/capture/capture_engine.dart';

void main() {
  group('CaptureTiming — القواعد الدستورية للمدة', () {
    test('لا إيقاف قبل الثامنة', () {
      expect(CaptureTiming.canStopRecording(7999), isFalse);
      expect(CaptureTiming.canStopRecording(8000), isTrue);
    });
    test('توقف تلقائي عند العاشرة', () {
      expect(CaptureTiming.shouldAutoStop(9999), isFalse);
      expect(CaptureTiming.shouldAutoStop(10000), isTrue);
    });
    test('قبول السيرفر 7000..12000 (هامش أمان القيد)', () {
      expect(CaptureTiming.isValidDuration(6999), isFalse);
      expect(CaptureTiming.isValidDuration(7000), isTrue);
      expect(CaptureTiming.isValidDuration(12000), isTrue);
      expect(CaptureTiming.isValidDuration(12001), isFalse);
    });
  });

  group('FaceGate — بوابة الوجه', () {
    test('وجه واحد واضح = جاهز', () {
      const gate = FaceGate(faceCount: 1, brightnessOk: true, faceAreaRatio: 0.15);
      expect(gate.ready, isTrue);
      expect(gate.hint, isNull);
    });
    test('بلا وجه → تلميح مصري مهذب', () {
      const gate = FaceGate(faceCount: 0, brightnessOk: true, faceAreaRatio: 0);
      expect(gate.ready, isFalse);
      expect(gate.hint, contains('مش باين'));
    });
    test('إضاءة خافتة → تلميح النور', () {
      const gate = FaceGate(faceCount: 1, brightnessOk: false, faceAreaRatio: 0.2);
      expect(gate.ready, isFalse);
      expect(gate.hint, contains('النور ضعيف'));
    });
    test('وجه بعيد → قرّب الموبايل', () {
      const gate = FaceGate(faceCount: 1, brightnessOk: true, faceAreaRatio: 0.03);
      expect(gate.ready, isFalse);
      expect(gate.hint, contains('قرّب'));
    });
    test('أكثر من وجه → مرفوض', () {
      const gate = FaceGate(faceCount: 2, brightnessOk: true, faceAreaRatio: 0.2);
      expect(gate.ready, isFalse);
    });
  });

  group('CaptureStateMachine — الانتقالات المشروعة', () {
    test('المسار السعيد كاملًا حتى done', () {
      final m = CaptureStateMachine();
      m.tokenRequested();
      expect(m.tokenIssued().phase, CapturePhase.showingDigits);
      const gate = FaceGate(faceCount: 1, brightnessOk: true, faceAreaRatio: 0.2);
      expect(m.recordingStarted(gate).phase, CapturePhase.recording);
      expect(m.recordingFinished(9000).phase, CapturePhase.collectingSignals);
      expect(m.signalsCollected().phase, CapturePhase.compressing);
      expect(m.compressed().phase, CapturePhase.hashing);
      expect(m.hashed().phase, CapturePhase.uploading);
      expect(m.uploadFinished(ok: true).phase, CapturePhase.registering);
      expect(m.registered().phase, CapturePhase.done);
    });

    test('مدة خارج الدستور → فشل برسالة واضحة بلا اتهام', () {
      final m = CaptureStateMachine();
      m.tokenRequested();
      m.tokenIssued();
      const gate = FaceGate(faceCount: 1, brightnessOk: true, faceAreaRatio: 0.2);
      m.recordingStarted(gate);
      final r = m.recordingFinished(5000);
      expect(r.phase, CapturePhase.failed);
      expect(r.error, contains('8 و 10 ثواني'));
      expect(r.error!.contains('غشاش'), isFalse); // D11
    });

    test('بوابة الوجه تمنع بدء التسجيل', () {
      final m = CaptureStateMachine();
      m.tokenRequested();
      m.tokenIssued();
      const bad = FaceGate(faceCount: 0, brightnessOk: false, faceAreaRatio: 0);
      final r = m.recordingStarted(bad);
      expect(r.phase, CapturePhase.showingDigits); // بقينا مكاننا
      expect(r.error, isNotNull);
    });

    test('فشل التصريح للحضور → مسار أوفلاين مشروع', () {
      final m = CaptureStateMachine();
      m.tokenRequested();
      final r = m.tokenFailed(allowOffline: true);
      expect(r.phase, CapturePhase.collectingSignals);
    });

    test('فشل التصريح للفحص المفاجئ → فشل (لا توكن محلي للفحص)', () {
      final m = CaptureStateMachine();
      m.tokenRequested();
      final r = m.tokenFailed(allowOffline: false);
      expect(r.phase, CapturePhase.failed);
    });

    test('فشل الرفع → طابور أوفلاين', () {
      final m = CaptureStateMachine();
      m.tokenRequested();
      m.tokenIssued();
      const gate = FaceGate(faceCount: 1, brightnessOk: true, faceAreaRatio: 0.2);
      m.recordingStarted(gate);
      m.recordingFinished(9000);
      m.signalsCollected();
      m.compressed();
      m.hashed();
      expect(m.uploadFinished(ok: false).phase, CapturePhase.offlineQueued);
    });

    test('فشل التسجيل بعد الرفع → طابور (بيانات الرفع محفوظة)', () {
      final m = CaptureStateMachine();
      m.tokenRequested();
      m.tokenIssued();
      const gate = FaceGate(faceCount: 1, brightnessOk: true, faceAreaRatio: 0.2);
      m.recordingStarted(gate);
      m.recordingFinished(9000);
      m.signalsCollected();
      m.compressed();
      m.hashed();
      m.uploadFinished(ok: true);
      expect(m.registerFailed().phase, CapturePhase.offlineQueued);
    });

    test('خطوة خارج الترتيب مرفوضة برسالة بلا اتهام', () {
      final m = CaptureStateMachine();
      final r = m.hashed(); // لم نصل لهذه الخطوة
      expect(r.error, isNotNull);
      expect(r.phase, CapturePhase.idle);
    });
  });
}
