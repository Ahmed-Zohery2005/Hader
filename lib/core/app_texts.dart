// ============================================================================
// حاضر — كل نصوص التطبيق بالمصرية المهذبة (قاموس واحد — قاعدة D11)
// ممنوع نهائيًا: «غائب / كاذب / مرفوض / متلاعب / غشاش» — أوصاف تقنية محايدة فقط
// ============================================================================

abstract final class T {
  // ——— عام ———
  static const String appName = 'حاضر';
  static const String tagline = 'مش بس بصمت';
  static const String ok = 'تمام';
  static const String retry = 'جرب تاني';
  static const String cancel = 'إلغاء';
  static const String next = 'التالي';
  static const String back = 'رجوع';
  static const String loading = 'ثانية واحدة…';

  // ——— التفعيل (الجزء 3.2) ———
  static const String welcomeTitle = 'أهلاً بيك في حاضر';
  static const String welcomeBody =
      'نظام إثبات تواجد بسيط: فيديو 8 ثوانٍ لوشك وبصوتك وقت الحضور والانصراف، '
      'وفي نص اليوم ممكن يجيلك إشعار فحص سريع. الفيديو بيتتمسح تلقائي بعد 7 أيام.';
  static const String startActivation = 'يلا نبدأ';
  static const String phoneLabel = 'رقم الموبايل المسجل عند الإدارة';
  static const String phoneHint = 'مثال: 01012345678';
  static const String dualSimNote =
      'عندك شريحتين؟ الرمز هيوصل على الرقم المسجل عند الإدارة تحديدًا.';
  static const String inviteLabel = 'كود الدعوة (من رسالة الإدارة)';
  static const String inviteHint = 'مثال: HADER-7K2M9Q4P';
  static const String verifyInvite = 'تحقق من الكود';
  static const String otpTitle = 'اكتب رمز التحقق';
  static const String otpSentTo = 'بعتنا رمز من 6 أرقام على';
  static const String otpNote = 'الرمز صالح لدقايق قليلة — لو مأدالكش استنى شوية واطلب تاني';
  static const String consentTitle = 'قبل ما نكمل — من حقك تعرف كل حاجة';
  static const String consentAccept = 'قرأت وموافق';
  static const String consentDecline = 'غير موافق، أرغب في البديل اليدوي';
  static const String selfieTitle = 'صورة مرجعية واحدة لوشك';
  static const String selfieHint = 'اقعد في مكان نير ووجهك واضح — دي اللي هيتقارن بيها أي تسجيل';
  static const String batteryTitle = 'نظبط إعدادات موبايلك مرة واحدة';
  static const String testNotificationGate =
      'هنبعتلك إشعار تجريبي دلوقتي — الإعداد مش بيكمل غير لما يوصلك';
  static const String practiceTitle = 'فيديو تجريبي واحد (مش بيتحسب عليك)';
  static const String practiceBody = 'عشان تتعود على قراءة الرقم وكسر رهبة الكاميرا';
  static const String activationDone = 'مبروك — حسابك جاهز خلاص';

  // ——— الرئيسية (الجزء 3.3) ———
  static const String tabHome = 'الرئيسية';
  static const String tabHistory = 'سجلي';
  static const String tabNotifications = 'الإشعارات';
  static const String tabProfile = 'حسابي';
  static const String checkIn = 'سجّل حضور';
  static const String checkOut = 'سجّل انصراف';
  static const String presentSince = 'حاضر منذ';
  static const String recordNow = 'سجّل الآن';
  static const String snooze10 = 'أجّل 10 دقايق';
  static const String snoozedOnce = 'التأجيل اتستخدم للفحص ده';
  static const String remaining = 'متبقي';
  static const String minutes = 'دقيقة';
  static const String spotCheckIncoming = 'فحص مفاجئ — سجل تواجدك';
  static const String unreachableBar =
      'إعدادات هاتفك ممكن تمنع وصول الفحوصات — اضغط هنا لإصلاحها في دقيقة';
  static const String daySummary = 'ملخص يومك';

  // ——— التصوير (الجزء 3.4) ———
  static const String getReady = 'هات وشك في الكادر…';
  static const String moveCloser = 'قرّب الموبايل شوية';
  static const String lowLight = 'النور ضعيف جدًا — روح مكان أنور';
  static const String noFace = 'وشك مش باين في الكادر';
  static const String sayLoudly = 'اقرأ الرقم ده بصوت واضح';
  static const String recording = 'بتسجل…';
  static const String minDurationNote = 'مينفعش تقفل قبل 8 ثواني';
  static const String doneRecording = 'تم التسجيل بنجاح';
  static const String offlineQueued =
      'النت مقطوع — التسجيل اتحفظ مشفرًا على الموبايل وهيرفع تلقائي أول ما النت يرجع';
  static const String gestureTurnLeft = 'التفت لليسار';
  static const String gestureTurnRight = 'التفت لليمين';
  static const String gestureSmile = 'ابتسم';
  static const String gestureCloseEyes = 'أغمض عينيك';

  // ——— سجلي والاعتراض (الجزء 3.3) ———
  static const String myRecords = 'سجلي — آخر 7 أيام';
  static const String transparencyNote = 'بترس بالظبط اللي بيشوفه مديرك — شفافية كاملة';
  static const String watchVideo = 'شوف الفيديو (رابط 5 دقايق)';
  static const String videoExpired = 'خلصت صلاحية الرابط — اضغط عرض تاني';
  static const String objectionButton = 'اعتراض';
  static const String objectionTitle = 'اعتراض رسمي على التسجيل';
  static const String objectionReason1 = 'كنت متواجدًا بالمكان وضعفت الإشارة';
  static const String objectionReason2 = 'لم يصلني صوت الإشعار';
  static const String objectionReason3 = 'كنت في مأمورية أو إذن عمل';
  static const String objectionReason4 = 'سبب آخر';
  static const String objectionNoteHint = 'سطر توضيحي (اختياري): اكتب اللي حصل بالظبط';
  static const String objectionSend = 'إرسال الاعتراض';
  static const String objectionSent =
      'وصل اعتراضك — الفيديو اتثبّت لحين الفصل وهوصلك القرار إشعارًا';
  static const String objectionWindowOver = 'مدة الاعتراض (7 أيام) خلصت للتسجيل ده';

  // ——— حسابي (الجزء 3.3) ———
  static const String updateSelfie = 'طلب تحديث الصورة المرجعية';
  static const String updateSelfieNote =
      'لو ملامحك اتغيرت (لحية/نظارة) — الإدارة تعتمد الصورة الجديدة والقديمة تفضل مؤرشفة';
  static const String myDevice = 'الموبايل المرتبط بالحساب';
  static const String rerunBatteryWizard = 'إعادة تشغيل معالج ضبط البطارية';
  static const String faq = 'الأسئلة الشائعة';
  static const String support = 'الدعم الفني (واتساب)';
  static const String privacy = 'سياسة الخصوصية';
  static const String withdrawConsent = 'سحب الموافقة والتحول للبديل اليدوي';
  static const String withdrawConsentConfirm =
      'متأكد؟ من حقك قانونًا — هتسجل حضورك ورقيًا مع المشرف ومفيش أي عقوبة عليك '
      'وقسم التصوير هيتقفل بهدوء.';
  static const String signOut = 'تسجيل خروج';

  // ——— الحالات المحايدة (قاموس D11 — نفس نصوص القاعدة) ———
  static const String statusPending = 'قيد المعالجة';
  static const String statusAutoAccepted = 'مقبول تلقائيًا';
  static const String statusNeedsReview = 'محتاج نظرة من الإدارة';
  static const String statusManagerAccepted = 'قبلته الإدارة';
  static const String statusManagerRejected = 'لم تكتمل الأدلة';
  static const String statusAskedEmployee = 'الإدارة سألتك عن التسجيل';
  static const String gradeConfirmed = 'المكان مؤكد';
  static const String gradeProbable = 'المكان محتمل';
  static const String gradeNeedsReview = 'المكان محتاج نظرة';
  static const String gradeGpsOnly = 'تحقق عبر الـ GPS فقط';
  static const String audioPending = 'جاري التحقق من الصوت';
  static const String audioMatched = 'الرقم مطابق';
  static const String audioNotApplicable = 'تسجيل بلا مطابقة صوت (كشك/أوفلاين)';
  static const String offlineTag = 'تسجيل أوفلاين';
  static const String lateUploadTag = 'رفع متأخر — اتراجع من الإدارة';

  // ——— الكشك ———
  static const String kioskTitle = 'جهاز الحضور المشترك';
  static const String kioskEnterPin = 'اكتب رقم فتح الكشك';
  static const String kioskPickWorker = 'اختار اسمك أو اكتب كودك';
  static const String kioskCodeHint = 'الكود من 4 أرقام';
  static const String kioskStartCapture = 'سجّل حضور';
  static const String kioskNextWorker = 'موظف تاني';

  // ——— أخطاء عامة ———
  static const String errNetwork =
      'النت شكله مقطوع — جرّب تاني أول ما ترجع الشبكة';
  static const String errGeneric = 'حصلت مشكلة — جرب تاني';
  static const String errSession = 'جلستك انتهت — سجل دخول من الأول';
}
