// ============================================================================
// حاضر — الرافع: رابط مؤقت → PUT إلى R2/MinIO → تسجيل عند السيرفر → مسح محلي
// + مضخة طابور الأوفلاين (ترفع تلقائيًا فور عودة الشبكة)
// ============================================================================

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/server_api.dart';
import '../../core/session.dart';
import 'offline_queue.dart';
import 'video_processor.dart';

class UploadOutcome {
  UploadOutcome({required this.registered, required this.offlineQueued, this.error});
  final bool registered;
  final bool offlineQueued;
  final String? error;
}

class CaptureUploader {
  CaptureUploader(this._api);
  final ServerApi _api;
  final OfflineQueueStore _queue = OfflineQueueStore();

  /// المسار السريع (خطوات 8→10): رفع مباشر ثم تسجيل ثم مسح فوري
  Future<UploadOutcome> uploadAndRegister({
    required String tokenId,
    required String? signature,
    required ProcessedVideo video,
    required int capturedAtMs,
    required int monotonicDeltaMs,
    Map<String, dynamic>? gps,
    List<Map<String, dynamic>>? bssids,
    bool? mockDetected,
    String? playIntegrityVerdict,
    bool? livenessPassed,
    Map<String, dynamic>? faceMeta,
    String? kioskUserId,
  }) async {
    // (أ) رابط الرفع المؤقت (يتحقق السيرفر من التصريح قبل إصداره)
    final presign = await _api.presignUpload(tokenId);
    if (!presign.ok || presign.data == null) {
      return _enqueue(
        captureId: _newCaptureId(presign.data),
        tokenId: tokenId,
        signature: signature,
        video: video,
        capturedAtMs: capturedAtMs,
        monotonicDeltaMs: monotonicDeltaMs,
        gps: gps,
        bssids: bssids,
        mockDetected: mockDetected,
        playIntegrityVerdict: playIntegrityVerdict,
        livenessPassed: livenessPassed,
        faceMeta: faceMeta,
        reason: presign.error ?? 'تعذر إصدار رابط الرفع',
      );
    }

    final d = presign.data!;
    final captureId = d['capture_id'] as String;
    final uploadUrl = d['upload_url'] as String;
    final objectKey = d['object_key'] as String;

    // (ب) الرفع المباشر (PUT مشفر)
    try {
      final bytes = await File(video.path).readAsBytes();
      final res = await http.put(
        Uri.parse(uploadUrl),
        body: bytes,
        headers: {'Content-Type': 'video/mp4'},
      ).timeout(const Duration(seconds: 90));
      if (res.statusCode != 200 && res.statusCode != 204) {
        throw Exception('upload ${res.statusCode}');
      }
    } catch (_) {
      return _enqueue(
        captureId: captureId,
        tokenId: tokenId,
        signature: signature,
        video: video,
        capturedAtMs: capturedAtMs,
        monotonicDeltaMs: monotonicDeltaMs,
        objectKey: objectKey,
        gps: gps,
        bssids: bssids,
        mockDetected: mockDetected,
        playIntegrityVerdict: playIntegrityVerdict,
        livenessPassed: livenessPassed,
        faceMeta: faceMeta,
        reason: 'الرفع اتقطع — النت ضعيف',
      );
    }

    // (ج) التسجيل عند السيرفر
    final reg = await _api.registerCapture(
      captureId: captureId,
      objectKey: objectKey,
      videoSha256: video.sha256,
      durationMs: video.durationMs,
      tokenId: tokenId,
      signature: signature,
      gps: gps,
      bssids: bssids,
      mockDetected: mockDetected,
      playIntegrityVerdict: playIntegrityVerdict,
      livenessPassed: livenessPassed,
      faceMeta: faceMeta,
      kioskUserId: kioskUserId,
    );

    // (د) مسح الملف المحلي فور تأكيد الوصول (خطوة 9)
    await File(video.path).delete().catchError((_) => File(video.path));

    if (!reg.ok) {
      // رُفع لكن لم يُسجل — عنصر طابور بلا ملف فيديو (بيانات الرفع كافية)
      final item = QueuedCapture(
        captureId: captureId,
        localVideoPath: '',
        objectKey: objectKey,
        videoSha256: video.sha256,
        durationMs: video.durationMs,
        capturedAtMs: capturedAtMs,
        monotonicDeltaMs: monotonicDeltaMs,
        tokenId: tokenId,
        signature: signature,
        isOffline: false,
        gps: gps,
        bssids: bssids,
        mockDetected: mockDetected,
        playIntegrityVerdict: playIntegrityVerdict,
        livenessPassed: livenessPassed,
        faceMeta: faceMeta,
      );
      await _queue.save([...await _queue.load(), item]);
      return UploadOutcome(registered: false, offlineQueued: true, error: reg.error);
    }

    return UploadOutcome(registered: true, offlineQueued: false);
  }

  /// مسار الأوفلاين الكامل: تصريح محلي + طابور مشفر
  Future<UploadOutcome> _enqueue({
    required String captureId,
    String? tokenId,
    String? signature,
    required ProcessedVideo video,
    required int capturedAtMs,
    required int monotonicDeltaMs,
    String? objectKey,
    Map<String, dynamic>? gps,
    List<Map<String, dynamic>>? bssids,
    bool? mockDetected,
    String? playIntegrityVerdict,
    bool? livenessPassed,
    Map<String, dynamic>? faceMeta,
    required String reason,
  }) async {
    final item = QueuedCapture(
      captureId: captureId,
      localVideoPath: video.path,
      objectKey: objectKey ?? '',
      videoSha256: video.sha256,
      durationMs: video.durationMs,
      capturedAtMs: capturedAtMs,
      monotonicDeltaMs: monotonicDeltaMs,
      tokenId: tokenId,
      signature: signature,
      isOffline: true,
      gps: gps,
      bssids: bssids,
      mockDetected: mockDetected,
      playIntegrityVerdict: playIntegrityVerdict,
      livenessPassed: livenessPassed,
      faceMeta: faceMeta,
    );
    await _queue.enqueue(item, clearVideoPath: video.path);
    return UploadOutcome(registered: false, offlineQueued: true, error: reason);
  }

  String _newCaptureId(Map<String, dynamic>? data) =>
      (data?['capture_id'] as String?) ??
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  // ------------------------------------------------------------------
  // مضخة الطابور: تُستدعى عند عودة الشبكة وعند فتح التطبيق
  // ------------------------------------------------------------------

  /// رفع كل العناصر المستحقة الآن — يعيد عدد ما نجح
  Future<int> flushQueue() async {
    final online = await Connectivity().checkConnectivity();
    if (online == ConnectivityResult.none) return 0;

    final items = await _queue.load();
    final now = MonotonicClockBinder.now();
    var done = 0;

    for (final item in items) {
      if (!isAttemptDue(item, now)) continue;

      item.attempts += 1;
      item.lastAttemptMs = now;
      await _queue.save(items); // حفظ فوري للمحاولة (لا تُعد عند إغلاق التطبيق)

      try {
        // عنصر بلا ملف فيديو (رُفع سابقًا ولم يُسجل)
        if (item.localVideoPath.isEmpty) {
          final reg = await _api.registerCapture(
            captureId: item.captureId,
            objectKey: item.objectKey,
            videoSha256: item.videoSha256,
            durationMs: item.durationMs,
            tokenId: item.tokenId,
            signature: item.signature,
            isOffline: item.isOffline,
            capturedAtClient: _iso(item.capturedAtMs),
            monotonicDeltaMs: item.monotonicDeltaMs,
            gps: item.gps,
            bssids: item.bssids,
            mockDetected: item.mockDetected,
            playIntegrityVerdict: item.playIntegrityVerdict,
            livenessPassed: item.livenessPassed,
            faceMeta: item.faceMeta,
          );
          if (reg.ok) {
            await _queue.purge(item);
            done += 1;
          }
          continue;
        }

        // عنصر كامل: فك التشفير ← رفع ← تسجيل ← مسح
        final decPath = await QueueCrypto.decryptFileTo(item.localVideoPath);
        final sha = await VideoProcessor.hashFile(decPath);
        if (sha != item.videoSha256) {
          // فساد بيانات محلي — يُحتفظ به للمراجعة اليدوية (لا يُتهم أحد)
          await File(decPath).delete().catchError((_) => File(decPath));
          continue;
        }

        // للأوفلاين: رابط رفع بلا تصريح (يوسم على السيرفر بالمراجعة الإدارية)
        final presign = item.isOffline
            ? await _api.presignOfflineUpload()
            : await _api.presignUpload(item.tokenId ?? '');
        if (!presign.ok || presign.data == null) continue;
        final url = presign.data!['upload_url'] as String;
        final objectKey = presign.data!['object_key'] as String;
        final bytes = await File(decPath).readAsBytes();
        final res = await http.put(
          Uri.parse(url),
          body: bytes,
          headers: {'Content-Type': 'video/mp4'},
        ).timeout(const Duration(seconds: 120));
        await File(decPath).delete().catchError((_) => File(decPath));
        if (res.statusCode != 200 && res.statusCode != 204) continue;

        final reg = await _api.registerCapture(
          captureId: presign.data!['capture_id'] as String,
          objectKey: objectKey,
          videoSha256: item.videoSha256,
          durationMs: item.durationMs,
          isOffline: item.isOffline,
          capturedAtClient: _iso(item.capturedAtMs),
          monotonicDeltaMs: item.monotonicDeltaMs,
          gps: item.gps,
          bssids: item.bssids,
          mockDetected: item.mockDetected,
          playIntegrityVerdict: item.playIntegrityVerdict,
          livenessPassed: item.livenessPassed,
          faceMeta: item.faceMeta,
        );
        if (reg.ok) {
          await _queue.purge(item);
          done += 1;
        }
      } catch (_) {
        // المحاولة القادمة بعد التراجع التصاعدي
      }
    }
    return done;
  }

  static String _iso(int ms) => DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String();
}
