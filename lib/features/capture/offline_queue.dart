// ============================================================================
// حاضر — طابور التسجيلات الأوفلاين المشفر (AES-256-GCM)
// ============================================================================
// (الجزء 3.4 خطوة 8): لو انقطع النت أثناء الرفع، يدخل الفيديو المشفر في
// طابور محلي آمن يُرفع تلقائيًا فور عودة الشبكة — ويُعتد دائمًا بوقت
// التصوير الفعلي لا وقت اكتمال الرفع.
//
// التصميم:
//   * كل عنصر = ملفات الفيديو المؤقتة على القرار + بيانات التسجيل مشفرة
//     AES-256-GCM (مفتاح عشوائي 256-bit يُولَّد مرة ويُحفظ في secure storage)
//   * البيانات الوصفية (بدون الفيديو) أيضًا مشفرة — لا شيء مقروء بلا مفتاح
//   * بلا أي مسار «تجاوز الطابور»: منطق القرار نقي وقابل للاختبار
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// عنصر طابور واحد — كل الحقول المطلوبة لإعادة الرفع والتسجيل لاحقًا
class QueuedCapture {
  QueuedCapture({
    required this.captureId,
    required this.localVideoPath,
    required this.objectKey,
    required this.videoSha256,
    required this.durationMs,
    required this.capturedAtMs,
    required this.monotonicDeltaMs,
    this.tokenId,
    this.signature,
    required this.isOffline,
    this.gps,
    this.bssids,
    this.mockDetected,
    this.playIntegrityVerdict,
    this.livenessPassed,
    this.faceMeta,
    this.attempts = 0,
    this.lastAttemptMs,
  });

  final String captureId;
  final String localVideoPath; // فيديو مشفر على القرص
  final String objectKey;
  final String videoSha256;
  final int durationMs;
  final int capturedAtMs; // وقت التصوير الفعلي (ساعة السيرفر المقدرة)
  final int monotonicDeltaMs;
  final String? tokenId;
  final String? signature;
  final bool isOffline;
  final Map<String, dynamic>? gps;
  final List<Map<String, dynamic>>? bssids;
  final bool? mockDetected;
  final String? playIntegrityVerdict;
  final bool? livenessPassed;
  final Map<String, dynamic>? faceMeta;
  int attempts;
  int? lastAttemptMs;

  Map<String, dynamic> toMap() => {
        'capture_id': captureId,
        'local_video_path': localVideoPath,
        'object_key': objectKey,
        'video_sha256': videoSha256,
        'duration_ms': durationMs,
        'captured_at_ms': capturedAtMs,
        'monotonic_delta_ms': monotonicDeltaMs,
        'token_id': tokenId,
        'signature': signature,
        'is_offline': isOffline,
        'gps': gps,
        'bssids': bssids,
        'mock_detected': mockDetected,
        'play_integrity_verdict': playIntegrityVerdict,
        'liveness_passed': livenessPassed,
        'face_meta': faceMeta,
        'attempts': attempts,
        'last_attempt_ms': lastAttemptMs,
      };

  static QueuedCapture fromMap(Map<String, dynamic> m) => QueuedCapture(
        captureId: m['capture_id'] as String,
        localVideoPath: m['local_video_path'] as String,
        objectKey: m['object_key'] as String,
        videoSha256: m['video_sha256'] as String,
        durationMs: m['duration_ms'] as int,
        capturedAtMs: m['captured_at_ms'] as int,
        monotonicDeltaMs: m['monotonic_delta_ms'] as int,
        tokenId: m['token_id'] as String?,
        signature: m['signature'] as String?,
        isOffline: m['is_offline'] as bool,
        gps: m['gps'] as Map<String, dynamic>?,
        bssids: (m['bssids'] as List?)?.cast<Map<String, dynamic>>(),
        mockDetected: m['mock_detected'] as bool?,
        playIntegrityVerdict: m['play_integrity_verdict'] as String?,
        livenessPassed: m['liveness_passed'] as bool?,
        faceMeta: m['face_meta'] as Map<String, dynamic>?,
        attempts: (m['attempts'] as int?) ?? 0,
        lastAttemptMs: m['last_attempt_ms'] as int?,
      );

  /// هل وصل لعتبة التخلي؟ (10 محاولات — المستند: يُقبل مع ملاحظة مراجعة)
  bool get exhausted => attempts >= 10;

  /// تأخير التراجع التصاعدي للمحاولة القادمة (بعد أول 3 محاولات فاشلة):
  /// 30 ثانية ← دقيقة ← دقيقتين … بسقف 64 دقيقة
  int nextBackoffMs() {
    if (attempts < 3) return 0;
    final exp = attempts - 3;
    final shift = exp > 7 ? 7 : exp; // سقف 30 ث × 128 = 64 دقيقة
    return 30 * 1000 * (1 << shift);
  }
}

/// منطق نقي: أي عنصر قابل للمحاولة الآن؟ (بلا I/O — قابل للاختبار الكامل)
bool isAttemptDue(QueuedCapture item, int nowMs) {
  if (item.exhausted) return false;
  final last = item.lastAttemptMs;
  if (last == null) return true;
  return nowMs - last >= item.nextBackoffMs();
}

/// ترتيب الطابور: الأقدم تصويرًا أولًا (وقت التصوير هو المعيار — عدل زمني)
List<QueuedCapture> orderQueue(List<QueuedCapture> items) {
  final list = [...items]..sort((a, b) => a.capturedAtMs.compareTo(b.capturedAtMs));
  return list;
}

/// المشفر الفعلي — AES-256-GCM بمفتاح يولد مرة واحدة ويحفظ آمنًا
class QueueCrypto {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kKey = 'hader_queue_key';
  static const _alg = AesGcm.with256bits();

  static Future<Uint8List> _loadOrCreateKey() async {
    final stored = await _storage.read(key: _kKey);
    if (stored != null) {
      return Uint8List.fromList(base64Decode(stored));
    }
    final key = await _alg.newSecretKey();
    final bytes = await key.extractBytes();
    await _storage.write(key: _kKey, value: base64Encode(bytes));
    return Uint8List.fromList(bytes);
  }

  /// تشفير بيانات عنصر — {nonce, ct} بالـ base64
  static Future<Map<String, String>> encryptJson(Map<String, dynamic> data) async {
    final keyBytes = await _loadOrCreateKey();
    final secretKey = SecretKey(keyBytes);
    final nonce = _alg.newNonce();
    final box = await _alg.encrypt(
      utf8.encode(jsonEncode(data)),
      secretKey: secretKey,
      nonce: nonce,
    );
    return {
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    };
  }

  /// فك بيانات عنصر — أو null لو فشل التحقق (عبث بالملف)
  static Future<Map<String, dynamic>?> decryptJson(Map<String, String> enc) async {
    try {
      final keyBytes = await _loadOrCreateKey();
      final box = SecretBox(
        base64Decode(enc['c']!),
        nonce: base64Decode(enc['n']!),
        mac: Mac(base64Decode(enc['m']!)),
      );
      final clear = await _alg.decrypt(box, secretKey: SecretKey(keyBytes));
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
    } catch (_) {
      return null; // فشل GCM = ملف معبث به — يُتجاهل بهدوء
    }
  }

  /// تشفير ملف فيديو إلى ملف جانبي (نفس المسار + .enc)
  static Future<String> encryptFileTo(String sourcePath) async {
    final keyBytes = await _loadOrCreateKey();
    final secretKey = SecretKey(keyBytes);
    final plain = await File(sourcePath).readAsBytes();
    final nonce = _alg.newNonce();
    final box = await _alg.encrypt(plain, secretKey: secretKey, nonce: nonce);

    final sink = File('$sourcePath.enc').openSync(mode: FileMode.write);
    sink.writeFromSync([
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
    await sink.close();
    return '$sourcePath.enc';
  }

  /// فك ملف الفيديو المشفر إلى مسار مؤقت
  static Future<String> decryptFileTo(String encPath) async {
    final keyBytes = await _loadOrCreateKey();
    final secretKey = SecretKey(keyBytes);
    final blob = await File(encPath).readAsBytes();
    final nonce = blob.sublist(0, 12);
    final mac = blob.sublist(12, 12 + 16);
    final ct = blob.sublist(12 + 16);
    final box = SecretBox(ct, nonce: nonce, mac: Mac(mac));
    final clear = await _alg.decrypt(box, secretKey: secretKey);

    final outPath = encPath.replaceAll('.enc', '.dec.mp4');
    await File(outPath).writeAsBytes(clear, flush: true);
    return outPath;
  }
}

/// مستودع الطابور (فهرس مشفر واحد في secure storage + ملفات فيديو مشفرة)
class OfflineQueueStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kIndex = 'hader_queue_index';

  Future<List<QueuedCapture>> load() async {
    final raw = await _storage.read(key: _kIndex);
    if (raw == null) return [];
    try {
      final enc = Map<String, String>.from(jsonDecode(raw) as Map);
      final data = await QueueCrypto.decryptJson(enc);
      if (data == null) return [];
      final items = (data['items'] as List)
          .map((e) => QueuedCapture.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      return orderQueue(items);
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<QueuedCapture> items) async {
    final enc = await QueueCrypto.encryptJson({
      'items': items.map((i) => i.toMap()).toList(),
    });
    await _storage.write(key: _kIndex, value: jsonEncode(enc));
  }

  Future<void> enqueue(QueuedCapture item, {required String clearVideoPath}) async {
    // شفّر الفيديو ثم امسح الأصل فورًا (لا يبقى نسخة غير مشفرة أبدًا)
    final encPath = await QueueCrypto.encryptFileTo(clearVideoPath);
    final file = File(clearVideoPath);
    if (await file.exists()) await file.delete();

    final items = await load();
    item.localVideoPath = encPath;
    items.add(item);
    await save(orderQueue(items));
  }

  /// مسح كل آثار عنصر بعد نجاح التسجيل (الفيديو المشفر والمؤقت)
  Future<void> purge(QueuedCapture item) async {
    final enc = File(item.localVideoPath);
    if (await enc.exists()) await enc.delete();
    final dec = File('${item.localVideoPath.replaceAll('.enc', '')}.dec.mp4');
    if (await dec.exists()) await dec.delete();
    final items = (await load()).where((i) => i.captureId != item.captureId).toList();
    await save(items);
  }
}
