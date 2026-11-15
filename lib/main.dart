// ============================================================================
// حاضر — نقطة الإقلاع: تهيئة الخدمات + ربط ساعة الرتابة + مضخة الطابور
// ============================================================================
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config.dart';
import 'core/server_api.dart';
import 'core/session.dart';
import 'features/capture/signals_collector.dart';
import 'features/capture/uploader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // RTL أصيل + وضع فاتح ثابت (قراءة مريحة لكل الفئات)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );
  await Firebase.initializeApp();

  // ربط ساعة الرتابة الحقيقية (SystemClock.elapsedRealtime) كمصدر وحيد للزمن
  final elapsed = await NativeSignals.elapsedRealtime();
  MonotonicClockBinder.set(elapsed);
  MonotonicClock.setDelegate(MonotonicClockBinder.now);

  // مضخة طابور الأوفلاين: أول ما النت متاح نرفع المعلق (وقت التصوير محفوظ)
  final api = ServerApi(Supabase.instance.client);
  unawaitedGuarded(CaptureUploader(api).flushQueue());

  runApp(const HaderApp());
}

/// unawaited بلا استثناء مسرب (ساكنة الكود الصارمة)
void unawaitedGuarded(Future<void> f) {
  f.catchError((_) {});
}
