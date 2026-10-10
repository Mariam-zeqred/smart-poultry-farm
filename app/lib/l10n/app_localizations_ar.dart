// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get visionTabLabel => 'المراقبة الذكية';

  @override
  String get visionScreenSubtitle => 'تحليل الرؤية والتنبيهات';

  @override
  String get snapshotCardTitle => 'لقطة تحليل الرؤية';

  @override
  String get statBirdsTracked => 'الطيور المتتبعة';

  @override
  String get statActivityLevel => 'مستوى النشاط';

  @override
  String get statHealthyUnhealthy => 'سليم / غير سليم';

  @override
  String get behaviorMixLabel => 'نمط السلوك (أكل وشرب / حركة / راحة)';

  @override
  String get behaviorEatDrink => 'أكل وشرب';

  @override
  String get behaviorMoving => 'حركة';

  @override
  String get behaviorRest => 'راحة';

  @override
  String hotspotInfo(String row, String col, String intensity) {
    return 'نقطة النشاط: الصف $row، العمود $col (الشدة $intensity)';
  }

  @override
  String get hotspotUnknown => 'نقطة النشاط: —';

  @override
  String lastUpdated(String age) {
    return 'آخر تحديث $age';
  }

  @override
  String lastUpdatedStale(String age) {
    return 'آخر تحديث $age — بيانات قديمة';
  }

  @override
  String get justNow => 'الآن';

  @override
  String minutesAgo(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $countString دقيقة',
      many: 'منذ $countString دقيقة',
      few: 'منذ $countString دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة واحدة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String get noDataYet =>
      'لم يتم استلام أي تحليل بعد — بانتظار كاميرا/محلل الرؤية.';

  @override
  String get statusNormal => 'طبيعي';

  @override
  String get statusWatch => 'مراقبة';

  @override
  String get statusAlert => 'تنبيه';

  @override
  String get statusStale => 'بيانات قديمة';

  @override
  String get statusNoData => 'لا توجد بيانات';

  @override
  String get activityHigh => 'مرتفع';

  @override
  String get activityMedium => 'متوسط';

  @override
  String get activityLow => 'منخفض';

  @override
  String get activityUnknown => '—';

  @override
  String get trendsCardTitle => 'الاتجاهات';

  @override
  String get trendsHint => 'آخر الجلسات المسجّلة محليًا';

  @override
  String get trendBirdCount => 'عدد الطيور';

  @override
  String get trendUnhealthyPct => 'نسبة غير السليم %';

  @override
  String get alertsCardTitle => 'التنبيهات';

  @override
  String get showResolved => 'إظهار التنبيهات المُعالجة';

  @override
  String get noAlertsYet =>
      'لا توجد تنبيهات بعد — جرّب أحد سيناريوهات المحاكاة.';

  @override
  String get acknowledgeBtn => 'الإقرار';

  @override
  String get acknowledgedBtn => 'تم الإقرار';

  @override
  String get resolveBtn => 'معالجة';

  @override
  String get resolvedBtn => 'تمت المعالجة';

  @override
  String get alertTypeTemperatureHigh => 'ارتفاع درجة الحرارة';

  @override
  String get alertTypeTemperatureLow => 'انخفاض درجة الحرارة';

  @override
  String get alertTypeHumidityHigh => 'ارتفاع الرطوبة';

  @override
  String get alertTypeHumidityLow => 'انخفاض الرطوبة';

  @override
  String get alertTypeGasDetected => 'رصد غاز';

  @override
  String get alertTypeGasCritical => 'مستوى غاز حرج';

  @override
  String get alertTypeTempCriticalLow => 'انخفاض حرج في درجة الحرارة';

  @override
  String get alertTypeTempCriticalHigh => 'ارتفاع حرج في درجة الحرارة';

  @override
  String get alertTypeHumCriticalLow => 'انخفاض حرج في الرطوبة';

  @override
  String get alertTypeHumCriticalHigh => 'ارتفاع حرج في الرطوبة';

  @override
  String get alertTypeVisionStale => 'انقطاع بث الذكاء الاصطناعي';

  @override
  String get alertTypeVisionUnhealthyRate => 'نسبة الطيور غير السليمة';

  @override
  String get alertTypeVisionActivityLow => 'انخفاض النشاط';

  @override
  String get alertTypeVisionBirdCountDrop => 'انخفاض عدد الطيور';

  @override
  String get alertTypeVisionOvercrowding => 'اكتظاظ';

  @override
  String get alertTypeVisionFeedingStalled => 'توقف التغذية';

  @override
  String get alertTypeVisionCombinedHealthActivity =>
      'خطر مركّب: الصحة والنشاط';

  @override
  String get alertTypeVisionCombinedMortality => 'احتمال حدوث نفوق';

  @override
  String msgVisionStale(String minutes) {
    return 'لم يتم استلام تحليل جديد منذ $minutes دقيقة — تحقق من الكاميرا / برنامج التحليل.';
  }

  @override
  String msgVisionUnhealthyRate(String pct, String unhealthy, String total) {
    return 'معدل اكتشاف الطيور غير السليمة $pct% ($unhealthy/$total طائر).';
  }

  @override
  String msgVisionActivityLow(String count) {
    return 'مستوى النشاط منخفض منذ $count جلسات متتالية.';
  }

  @override
  String msgVisionBirdCountDrop(String count, String pct, String baseline) {
    return 'انخفض عدد الطيور المتتبعة إلى $count، أي أكثر من $pct% تحت خط الأساس الأخير (~$baseline).';
  }

  @override
  String msgVisionOvercrowding(
      String ratio, String multiplier, String row, String col) {
    return 'ارتفعت شدة نقطة النشاط لكل طائر إلى $ratio (~$multiplier ضعف خط الأساس) بالقرب من الصف $row، العمود $col — احتمال اكتظاظ أو تجمّع.';
  }

  @override
  String msgVisionFeedingStalled(String pct, String count) {
    return 'نشاط الأكل والشرب أقل من $pct% لمدة $count جلسات متتالية — تحقق من المعلف/المسقى.';
  }

  @override
  String msgVisionCombinedHealthActivity(String pct) {
    return 'نسبة غير السليم $pct% مع انخفاض مستمر في النشاط — قد يشير انخفاض النشاط إلى مرض وليس راحة فقط.';
  }

  @override
  String msgVisionCombinedMortality(String count, String baseline, String pct) {
    return 'انخفض عدد الطيور إلى $count (خط الأساس ~$baseline) بينما نسبة غير السليم $pct% — احتمال حدوث نفوق.';
  }

  @override
  String get thresholdsCardTitle => 'حدود التنبيه';

  @override
  String get thresholdsSaveBtn => 'حفظ الحدود';

  @override
  String get thresholdsSaved => 'تم الحفظ';

  @override
  String get thUnhealthyWarnPct => 'نسبة غير سليم (تحذير) %';

  @override
  String get thUnhealthyCriticalPct => 'نسبة غير سليم (حرج) %';

  @override
  String get thActivityLowSustainedCount =>
      'عدد الجلسات لتفعيل تنبيه النشاط المنخفض';

  @override
  String get thBirdCountDropPct => 'نسبة انخفاض عدد الطيور %';

  @override
  String get thBirdCountSustainedCount => 'عدد الجلسات لتفعيل تنبيه الانخفاض';

  @override
  String get thHotspotSpikeRatio => 'نسبة ارتفاع الاكتظاظ (ضعف خط الأساس)';

  @override
  String get thFeedingStalledPct => 'الحد الأدنى لنسبة توقف التغذية %';

  @override
  String get thFeedingSustainedCount => 'عدد الجلسات لتفعيل تنبيه توقف التغذية';

  @override
  String get thStaleMinutes => 'اعتبار البيانات قديمة بعد (دقائق)';

  @override
  String get settingsLanguageTitle => 'اللغة';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get closeBtn => 'إغلاق';

  @override
  String get retryBtn => 'إعادة المحاولة';

  @override
  String get cancelBtnGeneric => 'إلغاء';

  @override
  String get navDashboard => 'الرئيسية';

  @override
  String get navDevices => 'الأجهزة';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get dashMyFarmTitle => 'مزرعتي';

  @override
  String get noDeviceConnectedTitle => 'لا يوجد جهاز متصل';

  @override
  String get noDeviceConnectedSubtitle => 'قم بتوصيل جهاز ESP32 للبدء';

  @override
  String get waitingForDeviceLabel => 'في انتظار الجهاز';

  @override
  String get connectYourDeviceTitle => 'قم بتوصيل جهازك';

  @override
  String get connectYourDeviceBody =>
      'انتقل إلى تبويب الأجهزة لإضافة وإعداد وحدة تحكم ESP32';

  @override
  String get goToDevicesBtn => 'الانتقال إلى الأجهزة';

  @override
  String get farmControlTitle => 'التحكم بالمزرعة';

  @override
  String get disabledBadge => 'معطّل';

  @override
  String get controlsDisabledMsg => 'عناصر التحكم معطّلة حتى يتصل جهاز';

  @override
  String get ventilationTitle => 'التهوية';

  @override
  String get fanControlSubtitle => 'التحكم بالمروحة';

  @override
  String get coolingTitle => 'التبريد';

  @override
  String get coolerControlSubtitle => 'التحكم بالمبرد';

  @override
  String get heaterTitle => 'السخان';

  @override
  String get heatingControlSubtitle => 'التحكم بالتدفئة';

  @override
  String get humidifierTitle => 'المرطب';

  @override
  String get humidifierControlSubtitle => 'التحكم بالترطيب';

  @override
  String get stateOn => 'تشغيل';

  @override
  String get stateOff => 'إيقاف';

  @override
  String get realtimeMonitoringSubtitle => 'المراقبة اللحظية';

  @override
  String get lastUpdateLabel => 'آخر تحديث';

  @override
  String get temperatureLabel => 'درجة الحرارة';

  @override
  String get humidityLabel => 'الرطوبة';

  @override
  String get airQualityLabel => 'جودة الهواء';

  @override
  String get overallLabel => 'الحالة العامة';

  @override
  String idealTempRange(String low, String high) {
    return 'المثالي: $low-$high°م';
  }

  @override
  String idealHumidityRange(String low, String high) {
    return 'المثالي: $low-$high%';
  }

  @override
  String goodGasRange(String max) {
    return 'جيد: أقل من $max ppm';
  }

  @override
  String get farmConditionLabel => 'حالة المزرعة';

  @override
  String get autoBadge => 'تلقائي';

  @override
  String get manualBadge => 'يدوي';

  @override
  String get farmControlModeLabel => 'وضع التحكم بالمزرعة';

  @override
  String get autoControlSystemDesc => 'يتحكم النظام تلقائيًا بالمزرعة';

  @override
  String get manualControlDesc => 'تحكم يدوي بأجهزة المزرعة';

  @override
  String get autoControlPausedTitle => 'التحكم التلقائي متوقف مؤقتًا';

  @override
  String manualPriorityRemainingMsg(String seconds) {
    return 'أولوية التحكم اليدوي: ~$seconds ثانية متبقية';
  }

  @override
  String get autoControlActiveTitle => 'التحكم التلقائي نشط';

  @override
  String get safetyOverrideActiveTitle => '🚨 تجاوز السلامة نشط';

  @override
  String get safetyOverrideDefaultReason =>
      'تم تفعيل حدود السلامة الحرجة - عناصر التحكم مقفلة';

  @override
  String get recentActivityTitle => 'النشاط الأخير';

  @override
  String get temperatureReadingLabel => 'قراءة درجة الحرارة';

  @override
  String get fanStatusLabel => 'حالة المروحة';

  @override
  String get coolerStatusLabel => 'حالة المبرد';

  @override
  String get heaterStatusLabel => 'حالة السخان';

  @override
  String get loadingFarmData => 'جارٍ تحميل بيانات المزرعة...';

  @override
  String get healthCritical => 'حرج';

  @override
  String get healthWarning => 'تحذير';

  @override
  String get healthExcellent => 'ممتاز';

  @override
  String get lockedSafetyOverrideTooltip => 'مقفل: تجاوز السلامة نشط';

  @override
  String get lockedAutomaticModeTooltip => 'مقفل: الوضع التلقائي مفعّل';

  @override
  String get lockedAppControlTooltip => 'مقفل: شاشة الجهاز هي المتحكمة';

  @override
  String get appControlToggleLabel => 'تحكم التطبيق';

  @override
  String get appControlEnabledDesc => 'التطبيق يتحكم في الجهاز';

  @override
  String get appControlDisabledDesc =>
      'شاشة الجهاز هي المتحكمة - التطبيق للعرض فقط';

  @override
  String get noDeviceConnectedBody =>
      'قم بتوصيل وحدة تحكم المزرعة لبدء مراقبة\nوالتحكم في بيئة الدواجن الخاصة بك';

  @override
  String get addNewDeviceBtn => 'إضافة جهاز جديد';

  @override
  String get wifiSetupHint => 'سيرشدك هذا خلال إعداد الواي فاي';

  @override
  String get whatYouCanDoTitle => 'ما يمكنك فعله:';

  @override
  String get featureMonitoringTitle => 'المراقبة اللحظية';

  @override
  String get featureMonitoringDesc => 'تتبع درجة الحرارة والرطوبة وجودة الهواء';

  @override
  String get featureAutoControlTitle => 'التحكم التلقائي';

  @override
  String get featureAutoControlDesc => 'تعديلات بيئية ذكية';

  @override
  String get featureAlertsTitle => 'تنبيهات فورية';

  @override
  String get featureAlertsDesc => 'احصل على إشعار بأي مشكلات';

  @override
  String get connectAnotherControllerSubtitle =>
      'توصيل وحدة تحكم أخرى بالمزرعة';

  @override
  String get onlineBadge => 'متصل';

  @override
  String get offlineBadge => 'غير متصل';

  @override
  String firmwareLabel(String firmware) {
    return 'البرنامج الثابت: $firmware';
  }

  @override
  String get viewDetailsOption => 'عرض التفاصيل';

  @override
  String get editDeviceOption => 'تعديل الجهاز';

  @override
  String get refreshDataOption => 'تحديث البيانات';

  @override
  String get refreshingDeviceData => 'جارٍ تحديث بيانات الجهاز...';

  @override
  String get troubleshootOption => 'استكشاف الأخطاء';

  @override
  String get deviceDetailsTitle => 'تفاصيل الجهاز';

  @override
  String get nameLabel => 'الاسم';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get lastSeenLabel => 'آخر ظهور';

  @override
  String get deviceIdLabel => 'معرّف الجهاز';

  @override
  String get firmwareOnlyLabel => 'البرنامج الثابت';

  @override
  String get currentReadingsTitle => 'القراءات الحالية:';

  @override
  String get controlSettingsColonTitle => 'إعدادات التحكم:';

  @override
  String get controlModeLabel => 'وضع التحكم';

  @override
  String get fanLabel => 'المروحة';

  @override
  String get coolerLabel => 'المبرد';

  @override
  String get statusOnlineValue => 'متصل';

  @override
  String get statusOfflineValue => 'غير متصل';

  @override
  String get justNowSentence => 'الآن';

  @override
  String shortMinutesAgo(String count) {
    return 'منذ $count د';
  }

  @override
  String shortHoursAgo(String count) {
    return 'منذ $count س';
  }

  @override
  String shortDaysAgo(String count) {
    return 'منذ $count يوم';
  }

  @override
  String get unknownLabel => 'غير معروف';

  @override
  String get deviceOptionsDefaultTitle => 'خيارات الجهاز';

  @override
  String get deviceTroubleshootingTitle => 'استكشاف أخطاء الجهاز';

  @override
  String deviceAppearsOfflineMsg(String name) {
    return 'يبدو أن الجهاز \"$name\" غير متصل.';
  }

  @override
  String get troubleshootingStepsTitle => 'خطوات استكشاف الأخطاء:';

  @override
  String get stepCheckPower => '• تحقق من توصيل طاقة الجهاز';

  @override
  String get stepVerifyWifi => '• تحقق من الاتصال بالواي فاي';

  @override
  String get stepRestartDevice => '• أعد تشغيل الجهاز';

  @override
  String get stepCheckFirebase => '• تحقق من اتصال Firebase';

  @override
  String lastSeenColonLabel(String value) {
    return 'آخر ظهور: $value';
  }

  @override
  String get retryConnectionBtn => 'إعادة محاولة الاتصال';

  @override
  String get editDeviceComingSoon => 'ميزة تعديل الجهاز قادمة قريبًا!';

  @override
  String get appSettingsTitle => 'إعدادات التطبيق';

  @override
  String get darkModeTitle => 'الوضع الداكن';

  @override
  String get darkThemeActiveSubtitle => 'المظهر الداكن مفعّل';

  @override
  String get lightThemeActiveSubtitle => 'المظهر الفاتح مفعّل';

  @override
  String get environmentalThresholdsTitle => 'الحدود البيئية';

  @override
  String get configureAutoControlTriggerSubtitle =>
      'إعداد نقاط تفعيل التحكم التلقائي';

  @override
  String get controlSettingsTitle => 'إعدادات التحكم';

  @override
  String get configureAutoControlBehaviorSubtitle =>
      'إعداد سلوك التحكم التلقائي';

  @override
  String get manualPriorityTimeoutTitle => 'مهلة الأولوية اليدوية';

  @override
  String get manualPriorityTimeoutSubtitle =>
      'المدة التي ينتظرها التحكم التلقائي بعد الأوامر اليدوية';

  @override
  String get fanCycleTitle => 'دورة المروحة';

  @override
  String get fanCycleSubtitle =>
      'تهوية مجدولة — تُشغّل المروحة على مؤقّت، بشكل مستقل عن الغاز/الحرارة/الرطوبة';

  @override
  String get fanCycleEnabledLabel => 'تفعيل الدورة المجدولة';

  @override
  String get fanCycleOnDurationLabel => 'مدة التشغيل';

  @override
  String get fanCycleOffDurationLabel => 'مدة الإيقاف';

  @override
  String get fanCycleActiveBanner =>
      'المروحة على دورة مجدولة — التحكم اليدوي بالمروحة مقفل أثناء التفعيل';

  @override
  String get saveBtn => 'حفظ';

  @override
  String get systemSectionTitle => 'النظام';

  @override
  String get aboutTitle => 'حول';

  @override
  String get aboutSubtitle => 'إصدار التطبيق ومعلوماته';

  @override
  String get connectedDeviceTitle => 'الجهاز المتصل';

  @override
  String get lotusFarmDefaultName => 'مزرعة لوتس';

  @override
  String get deviceDisconnectedTitle => 'الجهاز غير متصل';

  @override
  String get unableToConnectDeviceMsg => 'تعذّر الاتصال بالجهاز';

  @override
  String get aboutDialogTitle => 'حول Lotus Power';

  @override
  String versionLabel(String version) {
    return 'الإصدار: $version';
  }

  @override
  String get builtWithFlutterFirebase =>
      'تم البناء باستخدام Flutter و Firebase';

  @override
  String get esp32IntegrationDesc => 'تكامل ESP32 لمراقبة إنترنت الأشياء';

  @override
  String copyrightLine(String year) {
    return '© $year Lotus Power';
  }

  @override
  String get manualSetupTitle => 'الإعداد اليدوي';

  @override
  String hysteresisLabel(String value) {
    return 'التذبذب المسموح: $value°';
  }

  @override
  String get hysteresisDesc => 'يمنع التبديل السريع بين التشغيل والإيقاف';

  @override
  String get resetToDefaultsDialogTitle =>
      'إعادة التعيين إلى الإعدادات الموصى بها؟';

  @override
  String get resetToDefaultsDialogBody =>
      'سيؤدي هذا إلى إعادة تعيين جميع الحدود إلى قيم مبنية علميًا ومحسّنة للدجاج البالغ (5+ أسابيع):\n\n• درجة الحرارة: 18-24°م\n• الرطوبة: 50-70%\n• تنبيه الغاز: 400 ppm\n• التذبذب المسموح: 1.5\n\nهذه القيم مبنية على معايير Aviagen وUSDA وFAO لتربية الدواجن.';

  @override
  String get resetBtn => 'إعادة تعيين';

  @override
  String get thresholdsResetSuccessMsg =>
      '✅ تمت إعادة تعيين الحدود إلى الإعدادات الموصى بها';

  @override
  String errorResettingThresholds(String error) {
    return 'خطأ في إعادة تعيين الحدود: $error';
  }

  @override
  String get resetToDefaultsBtnLong =>
      'إعادة التعيين إلى الإعدادات الموصى بها (الطيور البالغة)';

  @override
  String get temperatureRangeLabel => 'نطاق درجة الحرارة';

  @override
  String get humidityRangeLabel => 'نطاق الرطوبة';

  @override
  String get gasLevelAlertLabel => 'تنبيه مستوى الغاز';

  @override
  String genericErrorMsg(String error) {
    return 'خطأ: $error';
  }

  @override
  String get quickPresetsTitle => 'إعدادات سريعة';

  @override
  String get presetSelectHint =>
      'اختر إعدادًا مسبقًا بناءً على مرحلة تربية الدواجن للحصول على الظروف المثلى';

  @override
  String get temperaturePresetAppliedMsg =>
      'تم تطبيق إعداد درجة الحرارة بنجاح!';

  @override
  String get humidityPresetAppliedMsg => 'تم تطبيق إعداد الرطوبة بنجاح!';

  @override
  String get resetToDefaultsBtnShort => 'إعادة التعيين للإعدادات الافتراضية';

  @override
  String get thresholdsResetToDefaultsMsg =>
      'تمت إعادة تعيين الحدود إلى الإعدادات الافتراضية';

  @override
  String get chooseTimeoutDurationMsg =>
      'اختر المدة التي يجب أن ينتظرها التحكم التلقائي بعد ضبطك للأجهزة يدويًا:';

  @override
  String get seconds15 => '15 ثانية';

  @override
  String get seconds30 => '30 ثانية';

  @override
  String get minute1 => 'دقيقة واحدة';

  @override
  String get minutes2 => 'دقيقتان';

  @override
  String get minutes5 => '5 دقائق';

  @override
  String manualPriorityTimeoutSetMsg(String label) {
    return 'تم ضبط مهلة الأولوية اليدوية على $label';
  }

  @override
  String get minimumLabel => 'الحد الأدنى';

  @override
  String get maximumLabel => 'الحد الأقصى';

  @override
  String validRangeLabel(String min, String max, String unit) {
    return 'النطاق الصالح: $min-$max $unit';
  }

  @override
  String get customLabel => 'مخصص';

  @override
  String plainRangeLabel(String min, String max, String unit) {
    return '$min - $max $unit';
  }

  @override
  String customRangeDialogTitle(String label) {
    return 'نطاق $label مخصص';
  }

  @override
  String minimumUnitLabel(String unit) {
    return 'الحد الأدنى $unit';
  }

  @override
  String maximumUnitLabel(String unit) {
    return 'الحد الأقصى $unit';
  }

  @override
  String get applyBtn => 'تطبيق';

  @override
  String get presetChicks => 'كتاكيت (0-1 أسبوع)';

  @override
  String get presetYoung => 'صغار (1-2 أسبوع)';

  @override
  String get presetGrowing => 'نامية (3-4 أسابيع)';

  @override
  String get presetAdults => 'بالغة (5+ أسابيع)';

  @override
  String get presetLayers => 'دجاج بياض (مثالي)';

  @override
  String get presetDryClimate => 'مناخ جاف';

  @override
  String get presetStandard => 'قياسي';

  @override
  String get presetHumidClimate => 'مناخ رطب';

  @override
  String get presetHatching => 'تفقيس';

  @override
  String get pleaseEnterWifiCreds =>
      'يرجى إدخال اسم شبكة الواي فاي وكلمة المرور';

  @override
  String get deviceSetupTitle => 'إعداد الجهاز';

  @override
  String get deviceWifiSetupTitle => 'إعداد واي فاي الجهاز';

  @override
  String get configureDeviceWifiSubtitle =>
      'قم بإعداد جهازك للاتصال بالواي فاي';

  @override
  String get beforeYouStartTitle => 'قبل أن تبدأ';

  @override
  String get stepConnectDeviceWifiTitle => 'الاتصال بواي فاي الجهاز';

  @override
  String get stepConnectDeviceWifiDesc =>
      'انتقل إلى إعدادات الواي فاي ← اتصل بشبكة \"PoultryFarm_Setup\"';

  @override
  String get stepEnterCredsTitle => 'أدخل بيانات الاعتماد أدناه';

  @override
  String get stepEnterCredsDesc => 'املأ تفاصيل واي فاي المنزل';

  @override
  String get stepSendConfigTitle => 'إرسال الإعدادات';

  @override
  String get stepSendConfigDesc => 'سيتصل الجهاز بشبكتك';

  @override
  String get wifiCredentialsTitle => 'بيانات اعتماد الواي فاي';

  @override
  String get networkNameLabel => 'اسم الشبكة (SSID)';

  @override
  String get networkNameHint => 'أدخل اسم شبكة الواي فاي الخاصة بك';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get passwordHint => 'أدخل كلمة مرور الواي فاي';

  @override
  String get sendCredentialsBtn => 'إرسال بيانات الاعتماد إلى الجهاز';

  @override
  String get tryAgainBtn => 'حاول مرة أخرى';

  @override
  String get provisionCheckingPermissions => 'جارٍ التحقق من الأذونات...';

  @override
  String get provisionSendingCredentials =>
      'جارٍ إرسال بيانات الاعتماد إلى الجهاز...';

  @override
  String get provisionSuccessMsg =>
      'تم الإعداد بنجاح! سيعيد الجهاز التشغيل ويتصل بشبكة الواي فاي الخاصة بك.';

  @override
  String get provisionAuthRequired =>
      'مطلوب تسجيل الدخول. يرجى تسجيل الدخول والمحاولة مرة أخرى.';

  @override
  String get provisionDeviceRestartedLikelySuccess =>
      'أعاد الجهاز التشغيل بعد استلام بيانات الاعتماد. الإعداد نجح على الأرجح - يرجى التحقق مما إذا كان جهازك يظهر متصلاً في التطبيق.';

  @override
  String get provisionTimedOutLikelySuccess =>
      'انتهت مهلة الطلب. ربما أعاد الجهاز التشغيل بنجاح - يرجى الانتظار قليلاً والتحقق مما إذا كان يظهر في قائمة أجهزتك.';

  @override
  String get provisionCannotConnect =>
      'تعذّر التواصل مع الجهاز. يرجى التأكد من:\n• أنك متصل بشبكة \"PoultryFarm_Setup\"\n• أن الجهاز قيد التشغيل\n• محاولة الاقتراب أكثر من الجهاز';

  @override
  String get provisionAuthFailedReLogin =>
      'فشلت المصادقة. يرجى تسجيل الخروج وإعادة تسجيل الدخول، ثم المحاولة مرة أخرى.';

  @override
  String get provisionDeviceRejectedData =>
      'رفض الجهاز البيانات. يرجى التأكد من اتصالك بواي فاي الجهاز والمحاولة مرة أخرى.';

  @override
  String get provisionDeviceInternalError =>
      'خطأ داخلي في الجهاز. يرجى إعادة تشغيل الجهاز والمحاولة مرة أخرى.';

  @override
  String get provisionDeviceRejectedCredentials =>
      'تعذّر على الجهاز معالجة بيانات الاعتماد. يرجى التحقق من كلمة مرور الواي فاي والمحاولة مرة أخرى.';

  @override
  String get provisionLocationPermissionRequired =>
      'إذن الموقع مطلوب. يرجى تفعيل خدمات الموقع في إعدادات التطبيق لإعداد الواي فاي.';

  @override
  String get provisionPermissionsRequired =>
      'أذونات التطبيق مطلوبة. يرجى منح جميع الأذونات المطلوبة في الإعدادات.';

  @override
  String provisionGenericSetupError(String error) {
    return 'خطأ في الإعداد: $error';
  }

  @override
  String get offlineTitle => 'يبدو أنك غير متصل بالإنترنت';

  @override
  String get couldNotConnectTitle => 'تعذّر الاتصال بالخادم';

  @override
  String get offlineBody => 'تحقق من اتصال الشبكة واضغط على إعادة المحاولة.';

  @override
  String get genericStartupErrorBody =>
      'حدث خطأ أثناء بدء التشغيل. اضغط على إعادة المحاولة للمحاولة مرة أخرى.';

  @override
  String get tempLowGteHighError =>
      'يجب أن تكون درجة الحرارة الدنيا أقل من درجة الحرارة القصوى';

  @override
  String get tempRangeTooNarrowError =>
      'نطاق درجة الحرارة ضيق جدًا (الحد الأدنى للفرق 2°م)';

  @override
  String tempOutOfRangeError(String min, String max) {
    return 'يجب أن تكون درجة الحرارة بين $min°م و$max°م';
  }

  @override
  String get humidityLowGteHighError =>
      'يجب أن تكون الرطوبة الدنيا أقل من الرطوبة القصوى';

  @override
  String get humidityRangeTooNarrowError =>
      'نطاق الرطوبة ضيق جدًا (الحد الأدنى للفرق 5%)';

  @override
  String humidityOutOfRangeError(String min, String max) {
    return 'يجب أن تكون الرطوبة بين $min% و$max%';
  }

  @override
  String gasOutOfRangeError(String max) {
    return 'يجب أن يكون حد الغاز بين 1 و$max ppm';
  }

  @override
  String get hysteresisOutOfRangeError =>
      'يجب أن يكون التذبذب المسموح بين 0.5 و10.0';
}
