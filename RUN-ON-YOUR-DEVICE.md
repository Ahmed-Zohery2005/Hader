# شغّل «حاضر» على جهازك (خطوة بخطوة)

> الزيب ده هو تطبيق الموظف كامل (Flutter / أندرويد): الكود في `lib/`،
> الإعدادات الأصلية في `android/`، الاختبارات في `test/`، ودليل البنية في `README.md`.

## 1) المتطلبات

| المطلوب | ملاحظات |
|---|---|
| Flutter SDK **3.5 أو أحدث** (وأقل من 4.0) | `flutter --version` للتأكد — `flutter doctor` يفحص الباقي |
| Android SDK (عبر Android Studio) + جهاز/محاكي أندرويد | التطبيق **أندرويد أولًا** (iOS غير مُدعوم رسميًا في V5) |
| كاميرا أمامية | التطبيق بيستخدم الكاميرا الأمامية **فقط** — مفيش أي سطر بيفتح الخلفية أو المعرض |
| حساب Firebase مجاني | للإشعارات (FCM) — انظر الخطوة 3 |

## 2) أول تشغيل

```bash
flutter pub get
flutter run
```

**نصيحة للمحاكي:** بوابة الوجه (ML Kit) محتاجة وش حقيقي في الكادر.
في إعدادات المحاكي خلي **Camera Front = webcam0** — كده المحاكي هيستخدم كاميرا اللابتوب
وبوابة الوجه هتشتغل على وشك الحقيقي. على جهاز حقيقي مفيش أي إعداد إضافي.

## 3) ملف `google-services.json` (لازم — بدونه البناء يفشل)

البلجن `com.google.gms.google-services` مُفعّل في `android/app/build.gradle.kts`، فلازم الملف:

1. افتح [console.firebase.google.com](https://console.firebase.google.com) → **Add project** (مجاني).
2. من المشروع: **Add app → Android** واكتب اسم الباقة بالظبط: **`com.hader.app`**.
3. نزّل `google-services.json` وحطه في: **`android/app/google-services.json`** (جنب `build.gradle.kts`).
4. من Project Settings → Cloud Messaging: مش محتاج أي حاجة إضافية — FCM بيتظبط لوحده بمجرد وجود الملف.

> التطبيق بدون ملف الفايربيز **مش هيتجمّع** — ده شرط بنيوي، مش رفاهية.

## 4) البيئة الخلفية (اختار واحدة من ثلاثة)

### (أ) المحاكي + الحزمة المحلية على نفس الكمبيوتر — الأسهل للتجربة
شغّل ستاك التوطين المحلي على جهازك (اتبع `deploy/egypt-local/README-EGYPT-LOCAL.md`
و`DEPLOYMENT_AR.md` في المستودع الكامل). التطبيق **افتراضيًا** بيبعت على:

```
http://10.0.2.2:8000
```

`10.0.2.2` هو اسم الكمبيوتر نفسه من داخل المحاكي — يعني `localhost:8000` بتاعك.
مفيش أي `--dart-define` محتاجها هنا (غير مفتاح الـ anon لو غيّرته في `.env`).

### (ب) جهاز حقيقي على نفس الواي-فاي
جهازك الحقيقي مش بيعرف `10.0.2.2` — استبدلها بعنوان الكمبيوتر على الشبكة:

```bash
flutter run --dart-define=HADER_SUPABASE_URL=http://<IP-الكمبيوتر-على-الواي-فاي>:8000
```

(اعرف الـ IP بـ `ipconfig` على ويندوز / `ifconfig | grep inet` على ماك-لينكس،
وخلي الكمبيوتر والجهاز على نفس الشبكة، والستاك شغال على بورت 8000.)

### (ج) Supabase سحابي / أي عنوان جاهز
```bash
flutter run \
  --dart-define=HADER_SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=HADER_SUPABASE_ANON_KEY=<anon> \
  --dart-define=HADER_SCHEDULE_SECRET=<SPOT_SCHEDULE_SECRET> \
  --dart-define=HADER_SUPPORT_WHATSAPP=20xxxxxxxxxx
```

## 5) جدول `--dart-define` (القيم الافتراضية من `lib/core/config.dart`)

| المتغير | الافتراضي | وظيفته |
|---|---|---|
| `HADER_SUPABASE_URL` | `http://10.0.2.2:8000` | عنوان بوابة Supabase/Kong |
| `HADER_SUPABASE_ANON_KEY` | `CHANGE_ME_ANON_KEY` | مفتاح anon العام (الحماية الحقيقية RLS — مش سر) |
| `HADER_SCHEDULE_SECRET` | `hader-dev-schedule-secret` | سر فك جدول الصباح المشفر AES-256-GCM — **لازم نفس قيمة `SPOT_SCHEDULE_SECRET` عند الدوال الطرفية** |
| `HADER_SUPPORT_WHATSAPP` | `201000000000` | رقم واتساب الدعم (دولي بلا `+`) |

## 6) الاختبارات (من غير جهاز حتى)

```bash
flutter test                 # 5 ملفات دارت: آلة الحالة، طابور الأوفلاين، رياضيات الساعة، البطارية والهاتف، النصوص المحايدة
```

## 7) البناء النهائي (APK/AAB)

```bash
flutter build appbundle --release --dart-define=... # نفس المتغيرات فوق
# أو للتجربة المباشرة على الجهاز:
flutter build apk --release --dart-define=...
```

## ملاحظات مهمة

- **بدون خلفية شغالة:** التطبيق هيفتح ويعرض شاشة التفعيل، لكن التحقق من كود الدعوة
  مش هيكتمل — هتشوف رسائل الشبكة المهذبة (`النت شكله مقطوع…`). ده طبيعي.
- **الفيديو:** 8 ثواني إلزامية، 10 سقف تلقائي — الكاميرا الأمامية فقط، والملف المحلي
  بيتمسح فور وصوله للسيرفر.
- **الأوفلاين:** لو النت قطع وقت التسجيل، الفيديو يتخزن مشفرًا (AES-256-GCM) ويرفع
  تلقائيًا أول ما الشبكة ترجع.
- عايز المستودع الكامل (الدوال الطرفية + الويب + الستاك)؟ راجع مستودع `hader` الكامل
  أو ملف `SESSIONS-PLAN.md`.
