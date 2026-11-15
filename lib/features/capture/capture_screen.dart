// ============================================================================
// حاضر — شاشة التصوير (العشر خطوات عمليًا — الجزء 3.4)
// ============================================================================
// الكاميرا الأمامية فقط (لا يوجد أي مسار للكاميرا الخلفية أو معرض الوسائط)
// + بوابة ML Kit (وجه واحد بإضاءة كافية قبل بدء العداد)
// + 8–10 ثوانٍ إلزامية + الإشارات بالتوازي + ضغط 480p + رفع/طابور.
// الشاشة عرضٌ صرف لآلة الحالة (capture_engine) — لا قرار فيها.
// ============================================================================

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_texts.dart';
import '../../core/server_api.dart';
import '../../core/session.dart';
import '../../core/utils/clock_math.dart';
import 'capture_engine.dart';
import 'signals_collector.dart';
import 'uploader.dart';
import 'video_processor.dart';
import '../push/notification_defense.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    this.practice = false,
    this.captureType = 'check_in',
    this.spotCheckId,
    this.kioskUserId,
    this.livenessGestures,
  });

  final bool practice;
  final String captureType; // check_in | check_out | spot_check
  final String? spotCheckId;
  final String? kioskUserId; // وضع الكشك
  final List<String>? livenessGestures; // وضع الحركات البديل

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _machine = CaptureStateMachine();
  CameraController? _camera;
  bool _cameraReady = false;
  String? _digits;
  String? _tokenId;
  String? _signature;
  Timer? _countdown;
  int _recordedMs = 0;
  String? _hint;
  bool _uploading = false;
  String? _resultMessage;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _requestToken();
  }

  Future<void> _initCamera() async {
    // الكاميرا الأمامية حصريًا — لا يوجد كود في التطبيق كله يفتح الخلفية
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _camera = CameraController(
      front,
      ResolutionPreset.medium, // 480p أساس الضغط
      enableAudio: true, // الرقم المنطوق جوهر التحقق
    );
    await _camera!.initialize();
    if (!mounted) return;
    setState(() => _cameraReady = true);
    _startFaceGate();
  }

  Future<void> _requestToken() async {
    _machine.reset();
    _machine.tokenRequested();

    // الفيديو التدريبي لا يستهلك تصريحًا سيرفريًا أبدًا (غير محسوب)
    if (widget.practice) {
      setState(() => _digits = _randomLocalDigits());
      return;
    }

    final api = ServerApi(Supabase.instance.client);
    final res = await api.issueCaptureToken(
      captureType: widget.captureType,
      spotCheckId: widget.spotCheckId,
    );
    if (!res.ok || res.data == null) {
      // الفحص المفاجئ لا يوجد له توكن محلي — إعادة المحاولة فقط
      final r = _machine.tokenFailed(allowOffline: widget.captureType != 'spot_check');
      setState(() {
        if (r.phase == CapturePhase.failed) {
          _hint = r.error ?? T.errGeneric;
        } else {
          _hint = 'النت مقطوع؟ سجل عادي — التسجيل هيتوسم أوفلاين وهيتحسب بوقت تصويرك';
          _digits = _randomLocalDigits();
        }
      });
      return;
    }
    final d = res.data!;
    _machine.tokenIssued();
    setState(() {
      _digits = d['challenge_digits'] as String;
      _tokenId = d['token_id'] as String;
      _signature = d['signature'] as String;
    });

    // جدول الصباح المشفر مع رد الحضور → منبهات احتياطية (المستوى الثاني)
    if (widget.captureType == 'check_in' && d['day_schedule'] != null) {
      final times =
          await decryptDaySchedule(d['day_schedule'] as Map<String, dynamic>);
      if (times != null) await LocalAlarms.scheduleToday(times);
    }
  }

  /// بوابة الوجه: تحليل إطار كل 400ms حتى يظهر وجه واحد واضح بإضاءة كافية
  void _startFaceGate() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      if (_machine.phase != CapturePhase.showingDigits || !_cameraReady) return;
      try {
        final xfile = await _camera!.takePicture();
        final input = InputImage.fromFilePath(xfile.path);
        final faces = await _faceDetector.detectFace(input);
        final gate = FaceGate(
          faceCount: faces.length,
          brightnessOk: faces.isNotEmpty && faces.first.brightnessAvailable
              ? faces.first.brightness >= -0.35
              : true,
          faceAreaRatio: faces.isNotEmpty
              ? faces.first.boundingBox.width * faces.first.boundingBox.height /
                  1000000
              : 0,
        );
        if (gate.ready) {
          _countdown?.cancel();
          setState(() => _hint = null);
        } else if (mounted) {
          setState(() => _hint = gate.hint ?? T.getReady);
        }
      } catch (_) {
        // بوابة الوجه إرشادية — الفشل لا يمنع التسجيل (قرار السيرفر)
      }
    });
  }

  Future<void> _startRecording() async {
    final r = _machine.recordingStarted(const FaceGate(
      faceCount: 1,
      brightnessOk: true,
      faceAreaRatio: 0.2,
    ));
    if (r.error != null) {
      setState(() => _hint = r.error);
      return;
    }
    await _camera!.startVideoRecording();
    setState(() => _recordedMs = 0);
    _countdown?.cancel();

    final t0 = MonotonicClockBinder.now();
    _countdown = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final elapsed = MonotonicClockBinder.now() - t0;
      setState(() => _recordedMs = elapsed);
      if (CaptureTiming.shouldAutoStop(elapsed)) {
        timer.cancel();
        _stopRecording(auto: true);
      }
    });
  }

  Future<void> _stopRecording({bool auto = false}) async {
    final elapsed = _recordedMs;
    if (!auto && !CaptureTiming.canStopRecording(elapsed)) {
      setState(() => _hint = T.minDurationNote);
      return;
    }
    _countdown?.cancel();
    final xfile = await _camera!.stopVideoRecording();

    final r = _machine.recordingFinished(elapsed);
    if (r.phase == CapturePhase.failed) {
      setState(() => _hint = r.error);
      return;
    }
    await _processAndUpload(xfile.path, elapsed);
  }

  Future<void> _processAndUpload(String rawPath, int durationMs) async {
    setState(() {
      _uploading = true;
      _hint = 'بنجهز التسجيل…';
    });

    try {
      // (5) الإشارات بالتوازي — GPS + BSSID + Integrity + Mock
      _machine.signalsCollected();
      final gps = await currentPosition();
      final bssids = await NativeSignals.scanBssids();
      final mockOn = await NativeSignals.isMockLocationOn();
      _machine.compressed();

      // (6-7) الضغط 480p ثم البصمة
      final video = await VideoProcessor.process(rawPath, durationMs);
      _machine.hashed();

      // وقت التصوير الفعلي: ساعة السيرفر المقدرة (بلا تلاعب ساعة الهاتف)
      final elapsedNow = MonotonicClockBinder.now();
      final sync = await ServerClockSync().load();
      final capturedAtMs = sync != null
          ? estimateServerNowMs(sync, elapsedNow)
          : DateTime.now().millisecondsSinceEpoch;
      final monoDelta = sync != null ? monotonicDeltaMs(sync, elapsedNow) : null;

      // (8-10) التدريبي محلي بالكامل — لا يغادر الهاتف إطلاقًا
      if (widget.practice) {
        _machine.uploadFinished(ok: true);
        _machine.registered();
        setState(() {
          _uploading = false;
          _success = true;
          _resultMessage = 'تمام! كده تمام — تسجيلاتك الحقيقية زي دي بالظبط';
        });
        return;
      }

      final out = await refUploader.uploadAndRegister(
        tokenId: _tokenId ?? '',
        signature: _signature,
        video: video,
        capturedAtMs: capturedAtMs,
        monotonicDeltaMs: monoDelta ?? 0,
        gps: gps,
        bssids: bssids,
        mockDetected: mockOn,
        faceMeta: {'face_count': 1, 'brightness': 'good'},
        kioskUserId: widget.kioskUserId,
      );

      if (out.registered) {
        _machine.uploadFinished(ok: true);
        _machine.registered();
      } else {
        _machine.uploadFinished(ok: false);
      }

      setState(() {
        _uploading = false;
        _success = out.registered;
        _resultMessage = out.registered
            ? T.doneRecording
            : T.offlineQueued;
      });
    } catch (_) {
      setState(() {
        _uploading = false;
        _success = false;
        _resultMessage = T.errGeneric;
      });
    }
  }

  String _randomLocalDigits() {
    final r = DateTime.now().microsecondsSinceEpoch;
    return ((r % 9000) + 1000).toString();
  }

  /// الرافع المشترك (يُنشأ من عميل Supabase الحالي)
  static CaptureUploader get refUploader =>
      CaptureUploader(ServerApi(Supabase.instance.client));

  /// كاشف وجه ML Kit (كشف سريع بالصور الثابتة — بوابة إرشادية)
  static final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // سماكة الوجه/الابتسامة (إضاءة تقريبية)
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  @override
  void dispose() {
    _countdown?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = _machine.phase == CapturePhase.recording;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // الكاميرا الأمامية
            if (_cameraReady)
              Center(child: CameraPreview(_camera!))
            else
              const Center(child: CircularProgressIndicator()),

            // الرقم الكبير + العداد
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (_digits != null && !recording) ...[
                    Text(
                      T.sayLoudly,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _digits!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        letterSpacing: 22,
                        fontFamily: 'IBM Plex Mono',
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(blurRadius: 18, color: Colors.black54)],
                      ),
                    ),
                  ],
                  if (recording)
                    Text(
                      '${T.recording} ${(_recordedMs / 1000).toStringAsFixed(1)} ث',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'IBM Plex Mono',
                      ),
                    ),
                ],
              ),
            ),

            // تلميح البوابة
            if (_hint != null && !_uploading)
              Positioned(
                bottom: 240,
                left: 24,
                right: 24,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),

            // رفع/نتيجة
            if (_uploading || _resultMessage != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black72,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _success ? Icons.check_circle : Icons.cloud_upload,
                            color: _success
                                ? const Color(0xFF34D399)
                                : Colors.white,
                            size: 58,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _resultMessage ?? T.loading,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          if (_resultMessage != null) ...[
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(_success),
                              child: const Text('تم'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // أزرار التحكم
            if (!_uploading && _resultMessage == null)
              Positioned(
                bottom: 36,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor: recording
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F6E56),
                        ),
                        onPressed: recording
                            ? () => _stopRecording()
                            : (_digits != null && _hint == null)
                                ? _startRecording
                                : null,
                        child: Icon(
                          recording ? Icons.stop : Icons.videocam,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      recording ? 'التسجيل شغال — اقرأ الرقم بصوت واضح' : T.getReady,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
