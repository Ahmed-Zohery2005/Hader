// ============================================================================
// حاضر — اختبارات طابور الأوفلاين (منطق نقي: الاستحقاق والترتيب والتراجع)
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:hader_employee/features/capture/offline_queue.dart';

QueuedCapture _item({
  required int capturedAtMs,
  int attempts = 0,
  int? lastAttemptMs,
  String path = '/tmp/v.mp4',
}) =>
    QueuedCapture(
      captureId: 'c-$capturedAtMs',
      localVideoPath: path,
      objectKey: 'k/$capturedAtMs',
      videoSha256: 'a' * 64,
      durationMs: 9000,
      capturedAtMs: capturedAtMs,
      monotonicDeltaMs: 0,
      isOffline: true,
      attempts: attempts,
      lastAttemptMs: lastAttemptMs,
    );

void main() {
  group('isAttemptDue — متى تُعاد المحاولة؟', () {
    test('عنصر بلا محاولات سابقة = مستحق فورًا', () {
      expect(isAttemptDue(_item(capturedAtMs: 1000), 5000000), isTrue);
    });

    test('أول 3 محاولات بلا انتظار (شبكة اهتزت ولحقت)', () {
      final item = _item(capturedAtMs: 1000, attempts: 2, lastAttemptMs: 100000);
      expect(isAttemptDue(item, 100001), isTrue);
    });

    test('بعد المحاولة الثالثة: تراجع تصاعدي 30 ثانية', () {
      final item = _item(capturedAtMs: 1000, attempts: 3, lastAttemptMs: 100000);
      expect(isAttemptDue(item, 100000 + 29999), isFalse);
      expect(isAttemptDue(item, 100000 + 30000), isTrue);
    });

    test('التراجع يتضاعف: محاولة 5 = دقيقتين', () {
      final item = _item(capturedAtMs: 1000, attempts: 5, lastAttemptMs: 100000);
      expect(isAttemptDue(item, 100000 + 119999), isFalse);
      expect(isAttemptDue(item, 100000 + 120000), isTrue);
    });

    test('10 محاولات = تُرك للمراجعة اليدوية (لا اتهام)', () {
      final item = _item(capturedAtMs: 1000, attempts: 10, lastAttemptMs: 100000);
      expect(item.exhausted, isTrue);
      expect(isAttemptDue(item, 999999999), isFalse);
    });
  });

  group('orderQueue — الأقدم تصويرًا أولًا (وقت التصوير هو المعيار)', () {
    test('ترتيب زمني تصاعدي بغض النظر عن وقت الإدراج', () {
      final items = [
        _item(capturedAtMs: 3000),
        _item(capturedAtMs: 1000),
        _item(capturedAtMs: 2000),
      ];
      final ordered = orderQueue(items);
      expect(ordered.map((i) => i.capturedAtMs).toList(), [1000, 2000, 3000]);
    });
  });

  group('nextBackoffMs — سقف التراجع', () {
    test('لا يتجاوز 64 دقيقة مهما كثرت المحاولات', () {
      final item = _item(capturedAtMs: 1, attempts: 20, lastAttemptMs: 0);
      expect(item.nextBackoffMs(), lessThanOrEqualTo(64 * 60 * 1000));
    });
  });

  group('toMap/fromMap — دورة كاملة بلا فقدان', () {
    test('الحقول الحساسة تبقى كما هي (sha256/duration/isOffline)', () {
      final item = _item(capturedAtMs: 7777, attempts: 2)
        ..gps = {'lat': 30.1, 'lng': 31.2, 'accuracy': 12.5}
        ..bssids = [
          {'bssid': 'A4:2B:B0:1C:44:01', 'rssi': -58}
        ]
        ..mockDetected = false;
      final restored = QueuedCapture.fromMap(item.toMap());
      expect(restored.videoSha256, item.videoSha256);
      expect(restored.durationMs, 9000);
      expect(restored.isOffline, isTrue);
      expect(restored.gps?['accuracy'], 12.5);
      expect(restored.bssids?.first['bssid'], 'A4:2B:B0:1C:44:01');
    });
  });
}
