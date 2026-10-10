import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @visionTabLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Monitor'**
  String get visionTabLabel;

  /// No description provided for @visionScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Vision analysis & alerts'**
  String get visionScreenSubtitle;

  /// No description provided for @snapshotCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Vision Analysis Snapshot'**
  String get snapshotCardTitle;

  /// No description provided for @statBirdsTracked.
  ///
  /// In en, this message translates to:
  /// **'Birds tracked'**
  String get statBirdsTracked;

  /// No description provided for @statActivityLevel.
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get statActivityLevel;

  /// No description provided for @statHealthyUnhealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy / Unhealthy'**
  String get statHealthyUnhealthy;

  /// No description provided for @behaviorMixLabel.
  ///
  /// In en, this message translates to:
  /// **'Behavior mix (eat-drink / moving / rest)'**
  String get behaviorMixLabel;

  /// No description provided for @behaviorEatDrink.
  ///
  /// In en, this message translates to:
  /// **'eat-drink'**
  String get behaviorEatDrink;

  /// No description provided for @behaviorMoving.
  ///
  /// In en, this message translates to:
  /// **'moving'**
  String get behaviorMoving;

  /// No description provided for @behaviorRest.
  ///
  /// In en, this message translates to:
  /// **'rest'**
  String get behaviorRest;

  /// No description provided for @hotspotInfo.
  ///
  /// In en, this message translates to:
  /// **'Hotspot: row {row}, col {col} (intensity {intensity})'**
  String hotspotInfo(String row, String col, String intensity);

  /// No description provided for @hotspotUnknown.
  ///
  /// In en, this message translates to:
  /// **'Hotspot: —'**
  String get hotspotUnknown;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {age}'**
  String lastUpdated(String age);

  /// No description provided for @lastUpdatedStale.
  ///
  /// In en, this message translates to:
  /// **'Last updated {age} — stale'**
  String lastUpdatedStale(String age);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} min ago}}'**
  String minutesAgo(num count);

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'No analysis received yet — waiting for the vision camera/analyzer to report in.'**
  String get noDataYet;

  /// No description provided for @statusNormal.
  ///
  /// In en, this message translates to:
  /// **'NORMAL'**
  String get statusNormal;

  /// No description provided for @statusWatch.
  ///
  /// In en, this message translates to:
  /// **'WATCH'**
  String get statusWatch;

  /// No description provided for @statusAlert.
  ///
  /// In en, this message translates to:
  /// **'ALERT'**
  String get statusAlert;

  /// No description provided for @statusStale.
  ///
  /// In en, this message translates to:
  /// **'STALE'**
  String get statusStale;

  /// No description provided for @statusNoData.
  ///
  /// In en, this message translates to:
  /// **'NO DATA'**
  String get statusNoData;

  /// No description provided for @activityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get activityHigh;

  /// No description provided for @activityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get activityMedium;

  /// No description provided for @activityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get activityLow;

  /// No description provided for @activityUnknown.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get activityUnknown;

  /// No description provided for @trendsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trendsCardTitle;

  /// No description provided for @trendsHint.
  ///
  /// In en, this message translates to:
  /// **'Last sessions logged locally'**
  String get trendsHint;

  /// No description provided for @trendBirdCount.
  ///
  /// In en, this message translates to:
  /// **'Bird count'**
  String get trendBirdCount;

  /// No description provided for @trendUnhealthyPct.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy %'**
  String get trendUnhealthyPct;

  /// No description provided for @alertsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsCardTitle;

  /// No description provided for @showResolved.
  ///
  /// In en, this message translates to:
  /// **'Show resolved'**
  String get showResolved;

  /// No description provided for @noAlertsYet.
  ///
  /// In en, this message translates to:
  /// **'No alerts yet — try a Simulate scenario.'**
  String get noAlertsYet;

  /// No description provided for @acknowledgeBtn.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge'**
  String get acknowledgeBtn;

  /// No description provided for @acknowledgedBtn.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get acknowledgedBtn;

  /// No description provided for @resolveBtn.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolveBtn;

  /// No description provided for @resolvedBtn.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get resolvedBtn;

  /// No description provided for @alertTypeTemperatureHigh.
  ///
  /// In en, this message translates to:
  /// **'High Temperature'**
  String get alertTypeTemperatureHigh;

  /// No description provided for @alertTypeTemperatureLow.
  ///
  /// In en, this message translates to:
  /// **'Low Temperature'**
  String get alertTypeTemperatureLow;

  /// No description provided for @alertTypeHumidityHigh.
  ///
  /// In en, this message translates to:
  /// **'High Humidity'**
  String get alertTypeHumidityHigh;

  /// No description provided for @alertTypeHumidityLow.
  ///
  /// In en, this message translates to:
  /// **'Low Humidity'**
  String get alertTypeHumidityLow;

  /// No description provided for @alertTypeGasDetected.
  ///
  /// In en, this message translates to:
  /// **'Gas Detection'**
  String get alertTypeGasDetected;

  /// No description provided for @alertTypeGasCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical Gas Level'**
  String get alertTypeGasCritical;

  /// No description provided for @alertTypeTempCriticalLow.
  ///
  /// In en, this message translates to:
  /// **'Critical Low Temperature'**
  String get alertTypeTempCriticalLow;

  /// No description provided for @alertTypeTempCriticalHigh.
  ///
  /// In en, this message translates to:
  /// **'Critical High Temperature'**
  String get alertTypeTempCriticalHigh;

  /// No description provided for @alertTypeHumCriticalLow.
  ///
  /// In en, this message translates to:
  /// **'Critical Low Humidity'**
  String get alertTypeHumCriticalLow;

  /// No description provided for @alertTypeHumCriticalHigh.
  ///
  /// In en, this message translates to:
  /// **'Critical High Humidity'**
  String get alertTypeHumCriticalHigh;

  /// No description provided for @alertTypeVisionStale.
  ///
  /// In en, this message translates to:
  /// **'AI Feed Offline'**
  String get alertTypeVisionStale;

  /// No description provided for @alertTypeVisionUnhealthyRate.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy Rate'**
  String get alertTypeVisionUnhealthyRate;

  /// No description provided for @alertTypeVisionActivityLow.
  ///
  /// In en, this message translates to:
  /// **'Low Activity'**
  String get alertTypeVisionActivityLow;

  /// No description provided for @alertTypeVisionBirdCountDrop.
  ///
  /// In en, this message translates to:
  /// **'Bird Count Drop'**
  String get alertTypeVisionBirdCountDrop;

  /// No description provided for @alertTypeVisionOvercrowding.
  ///
  /// In en, this message translates to:
  /// **'Overcrowding'**
  String get alertTypeVisionOvercrowding;

  /// No description provided for @alertTypeVisionFeedingStalled.
  ///
  /// In en, this message translates to:
  /// **'Feeding Stalled'**
  String get alertTypeVisionFeedingStalled;

  /// No description provided for @alertTypeVisionCombinedHealthActivity.
  ///
  /// In en, this message translates to:
  /// **'Health + Activity Risk'**
  String get alertTypeVisionCombinedHealthActivity;

  /// No description provided for @alertTypeVisionCombinedMortality.
  ///
  /// In en, this message translates to:
  /// **'Possible Mortality Event'**
  String get alertTypeVisionCombinedMortality;

  /// No description provided for @msgVisionStale.
  ///
  /// In en, this message translates to:
  /// **'No new AI analysis in {minutes} min — check the camera / desktop analyzer.'**
  String msgVisionStale(String minutes);

  /// No description provided for @msgVisionUnhealthyRate.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy detection rate at {pct}% ({unhealthy}/{total} birds).'**
  String msgVisionUnhealthyRate(String pct, String unhealthy, String total);

  /// No description provided for @msgVisionActivityLow.
  ///
  /// In en, this message translates to:
  /// **'Activity level has been low for {count} consecutive sessions.'**
  String msgVisionActivityLow(String count);

  /// No description provided for @msgVisionBirdCountDrop.
  ///
  /// In en, this message translates to:
  /// **'Tracked bird count dropped to {count}, more than {pct}% below the recent baseline (~{baseline}).'**
  String msgVisionBirdCountDrop(String count, String pct, String baseline);

  /// No description provided for @msgVisionOvercrowding.
  ///
  /// In en, this message translates to:
  /// **'Activity-hotspot intensity per bird spiked to {ratio} (~{multiplier}x recent baseline) near row {row}, col {col} — possible crowding/huddling.'**
  String msgVisionOvercrowding(
      String ratio, String multiplier, String row, String col);

  /// No description provided for @msgVisionFeedingStalled.
  ///
  /// In en, this message translates to:
  /// **'Eat/drink activity has been under {pct}% for {count} consecutive sessions — check feeder/waterer.'**
  String msgVisionFeedingStalled(String pct, String count);

  /// No description provided for @msgVisionCombinedHealthActivity.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy rate {pct}% together with sustained low activity — inactivity may indicate illness rather than rest.'**
  String msgVisionCombinedHealthActivity(String pct);

  /// No description provided for @msgVisionCombinedMortality.
  ///
  /// In en, this message translates to:
  /// **'Bird count dropped to {count} (baseline ~{baseline}) while unhealthy rate is {pct}% — possible mortality event.'**
  String msgVisionCombinedMortality(String count, String baseline, String pct);

  /// No description provided for @thresholdsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm thresholds'**
  String get thresholdsCardTitle;

  /// No description provided for @thresholdsSaveBtn.
  ///
  /// In en, this message translates to:
  /// **'Save thresholds'**
  String get thresholdsSaveBtn;

  /// No description provided for @thresholdsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get thresholdsSaved;

  /// No description provided for @thUnhealthyWarnPct.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy % (warning)'**
  String get thUnhealthyWarnPct;

  /// No description provided for @thUnhealthyCriticalPct.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy % (critical)'**
  String get thUnhealthyCriticalPct;

  /// No description provided for @thActivityLowSustainedCount.
  ///
  /// In en, this message translates to:
  /// **'Low-activity sessions to alarm'**
  String get thActivityLowSustainedCount;

  /// No description provided for @thBirdCountDropPct.
  ///
  /// In en, this message translates to:
  /// **'Bird count drop %'**
  String get thBirdCountDropPct;

  /// No description provided for @thBirdCountSustainedCount.
  ///
  /// In en, this message translates to:
  /// **'Drop sessions to alarm'**
  String get thBirdCountSustainedCount;

  /// No description provided for @thHotspotSpikeRatio.
  ///
  /// In en, this message translates to:
  /// **'Overcrowding spike ratio (x baseline)'**
  String get thHotspotSpikeRatio;

  /// No description provided for @thFeedingStalledPct.
  ///
  /// In en, this message translates to:
  /// **'Feeding-stalled % floor'**
  String get thFeedingStalledPct;

  /// No description provided for @thFeedingSustainedCount.
  ///
  /// In en, this message translates to:
  /// **'Feeding-stalled sessions to alarm'**
  String get thFeedingSustainedCount;

  /// No description provided for @thStaleMinutes.
  ///
  /// In en, this message translates to:
  /// **'Stale after (minutes)'**
  String get thStaleMinutes;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get settingsLanguageArabic;

  /// No description provided for @closeBtn.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeBtn;

  /// No description provided for @retryBtn.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryBtn;

  /// No description provided for @cancelBtnGeneric.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelBtnGeneric;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get navDevices;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @dashMyFarmTitle.
  ///
  /// In en, this message translates to:
  /// **'My Farm'**
  String get dashMyFarmTitle;

  /// No description provided for @noDeviceConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'No Device Connected'**
  String get noDeviceConnectedTitle;

  /// No description provided for @noDeviceConnectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your ESP32 to start'**
  String get noDeviceConnectedSubtitle;

  /// No description provided for @waitingForDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'WAITING FOR DEVICE'**
  String get waitingForDeviceLabel;

  /// No description provided for @connectYourDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Your Device'**
  String get connectYourDeviceTitle;

  /// No description provided for @connectYourDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Go to the Devices tab to add and configure your ESP32 controller'**
  String get connectYourDeviceBody;

  /// No description provided for @goToDevicesBtn.
  ///
  /// In en, this message translates to:
  /// **'Go to Devices'**
  String get goToDevicesBtn;

  /// No description provided for @farmControlTitle.
  ///
  /// In en, this message translates to:
  /// **'Farm Control'**
  String get farmControlTitle;

  /// No description provided for @disabledBadge.
  ///
  /// In en, this message translates to:
  /// **'DISABLED'**
  String get disabledBadge;

  /// No description provided for @controlsDisabledMsg.
  ///
  /// In en, this message translates to:
  /// **'Controls are disabled until a device connects'**
  String get controlsDisabledMsg;

  /// No description provided for @ventilationTitle.
  ///
  /// In en, this message translates to:
  /// **'Ventilation'**
  String get ventilationTitle;

  /// No description provided for @fanControlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fan Control'**
  String get fanControlSubtitle;

  /// No description provided for @coolingTitle.
  ///
  /// In en, this message translates to:
  /// **'Cooling'**
  String get coolingTitle;

  /// No description provided for @coolerControlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cooler Control'**
  String get coolerControlSubtitle;

  /// No description provided for @heaterTitle.
  ///
  /// In en, this message translates to:
  /// **'Heater'**
  String get heaterTitle;

  /// No description provided for @heatingControlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Heating Control'**
  String get heatingControlSubtitle;

  /// No description provided for @humidifierTitle.
  ///
  /// In en, this message translates to:
  /// **'Humidifier'**
  String get humidifierTitle;

  /// No description provided for @humidifierControlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Humidifier Control'**
  String get humidifierControlSubtitle;

  /// No description provided for @stateOn.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get stateOn;

  /// No description provided for @stateOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get stateOff;

  /// No description provided for @realtimeMonitoringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Real-time Monitoring'**
  String get realtimeMonitoringSubtitle;

  /// No description provided for @lastUpdateLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Update'**
  String get lastUpdateLabel;

  /// No description provided for @temperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperatureLabel;

  /// No description provided for @humidityLabel.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidityLabel;

  /// No description provided for @airQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Air Quality'**
  String get airQualityLabel;

  /// No description provided for @overallLabel.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get overallLabel;

  /// No description provided for @idealTempRange.
  ///
  /// In en, this message translates to:
  /// **'Ideal: {low}-{high}°C'**
  String idealTempRange(String low, String high);

  /// No description provided for @idealHumidityRange.
  ///
  /// In en, this message translates to:
  /// **'Ideal: {low}-{high}%'**
  String idealHumidityRange(String low, String high);

  /// No description provided for @goodGasRange.
  ///
  /// In en, this message translates to:
  /// **'Good: <{max} ppm'**
  String goodGasRange(String max);

  /// No description provided for @farmConditionLabel.
  ///
  /// In en, this message translates to:
  /// **'Farm Condition'**
  String get farmConditionLabel;

  /// No description provided for @autoBadge.
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get autoBadge;

  /// No description provided for @manualBadge.
  ///
  /// In en, this message translates to:
  /// **'MANUAL'**
  String get manualBadge;

  /// No description provided for @farmControlModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Farm Control Mode'**
  String get farmControlModeLabel;

  /// No description provided for @autoControlSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'System automatically controls farm'**
  String get autoControlSystemDesc;

  /// No description provided for @manualControlDesc.
  ///
  /// In en, this message translates to:
  /// **'Manual control of farm devices'**
  String get manualControlDesc;

  /// No description provided for @autoControlPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Control Paused'**
  String get autoControlPausedTitle;

  /// No description provided for @manualPriorityRemainingMsg.
  ///
  /// In en, this message translates to:
  /// **'Manual priority: ~{seconds}s remaining'**
  String manualPriorityRemainingMsg(String seconds);

  /// No description provided for @autoControlActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Control Active'**
  String get autoControlActiveTitle;

  /// No description provided for @safetyOverrideActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'🚨 SAFETY OVERRIDE ACTIVE'**
  String get safetyOverrideActiveTitle;

  /// No description provided for @safetyOverrideDefaultReason.
  ///
  /// In en, this message translates to:
  /// **'Critical safety limits triggered - controls locked'**
  String get safetyOverrideDefaultReason;

  /// No description provided for @recentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivityTitle;

  /// No description provided for @temperatureReadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature Reading'**
  String get temperatureReadingLabel;

  /// No description provided for @fanStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Fan Status'**
  String get fanStatusLabel;

  /// No description provided for @coolerStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Cooler Status'**
  String get coolerStatusLabel;

  /// No description provided for @heaterStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Heater Status'**
  String get heaterStatusLabel;

  /// No description provided for @loadingFarmData.
  ///
  /// In en, this message translates to:
  /// **'Loading farm data...'**
  String get loadingFarmData;

  /// No description provided for @healthCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get healthCritical;

  /// No description provided for @healthWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get healthWarning;

  /// No description provided for @healthExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get healthExcellent;

  /// No description provided for @lockedSafetyOverrideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Locked: Safety override active'**
  String get lockedSafetyOverrideTooltip;

  /// No description provided for @lockedAutomaticModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Locked: Automatic mode enabled'**
  String get lockedAutomaticModeTooltip;

  /// No description provided for @lockedAppControlTooltip.
  ///
  /// In en, this message translates to:
  /// **'Locked: Device LCD is in control'**
  String get lockedAppControlTooltip;

  /// No description provided for @appControlToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'App Control'**
  String get appControlToggleLabel;

  /// No description provided for @appControlEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'App is controlling the device'**
  String get appControlEnabledDesc;

  /// No description provided for @appControlDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Device LCD is controlling — app is view-only'**
  String get appControlDisabledDesc;

  /// No description provided for @noDeviceConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'Connect your farm controller to start monitoring\nand controlling your poultry environment'**
  String get noDeviceConnectedBody;

  /// No description provided for @addNewDeviceBtn.
  ///
  /// In en, this message translates to:
  /// **'Add New Device'**
  String get addNewDeviceBtn;

  /// No description provided for @wifiSetupHint.
  ///
  /// In en, this message translates to:
  /// **'This will guide you through WiFi setup'**
  String get wifiSetupHint;

  /// No description provided for @whatYouCanDoTitle.
  ///
  /// In en, this message translates to:
  /// **'What you can do:'**
  String get whatYouCanDoTitle;

  /// No description provided for @featureMonitoringTitle.
  ///
  /// In en, this message translates to:
  /// **'Real-time Monitoring'**
  String get featureMonitoringTitle;

  /// No description provided for @featureMonitoringDesc.
  ///
  /// In en, this message translates to:
  /// **'Track temperature, humidity & air quality'**
  String get featureMonitoringDesc;

  /// No description provided for @featureAutoControlTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic Control'**
  String get featureAutoControlTitle;

  /// No description provided for @featureAutoControlDesc.
  ///
  /// In en, this message translates to:
  /// **'Smart environmental adjustments'**
  String get featureAutoControlDesc;

  /// No description provided for @featureAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Instant Alerts'**
  String get featureAlertsTitle;

  /// No description provided for @featureAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Get notified of any issues'**
  String get featureAlertsDesc;

  /// No description provided for @connectAnotherControllerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect another farm controller'**
  String get connectAnotherControllerSubtitle;

  /// No description provided for @onlineBadge.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get onlineBadge;

  /// No description provided for @offlineBadge.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get offlineBadge;

  /// No description provided for @firmwareLabel.
  ///
  /// In en, this message translates to:
  /// **'Firmware: {firmware}'**
  String firmwareLabel(String firmware);

  /// No description provided for @viewDetailsOption.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetailsOption;

  /// No description provided for @editDeviceOption.
  ///
  /// In en, this message translates to:
  /// **'Edit Device'**
  String get editDeviceOption;

  /// No description provided for @refreshDataOption.
  ///
  /// In en, this message translates to:
  /// **'Refresh Data'**
  String get refreshDataOption;

  /// No description provided for @refreshingDeviceData.
  ///
  /// In en, this message translates to:
  /// **'Refreshing device data...'**
  String get refreshingDeviceData;

  /// No description provided for @troubleshootOption.
  ///
  /// In en, this message translates to:
  /// **'Troubleshoot'**
  String get troubleshootOption;

  /// No description provided for @deviceDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Details'**
  String get deviceDetailsTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @lastSeenLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Seen'**
  String get lastSeenLabel;

  /// No description provided for @deviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceIdLabel;

  /// No description provided for @firmwareOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get firmwareOnlyLabel;

  /// No description provided for @currentReadingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Readings:'**
  String get currentReadingsTitle;

  /// No description provided for @controlSettingsColonTitle.
  ///
  /// In en, this message translates to:
  /// **'Control Settings:'**
  String get controlSettingsColonTitle;

  /// No description provided for @controlModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Control Mode'**
  String get controlModeLabel;

  /// No description provided for @fanLabel.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get fanLabel;

  /// No description provided for @coolerLabel.
  ///
  /// In en, this message translates to:
  /// **'Cooler'**
  String get coolerLabel;

  /// No description provided for @statusOnlineValue.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnlineValue;

  /// No description provided for @statusOfflineValue.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOfflineValue;

  /// No description provided for @justNowSentence.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNowSentence;

  /// No description provided for @shortMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String shortMinutesAgo(String count);

  /// No description provided for @shortHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String shortHoursAgo(String count);

  /// No description provided for @shortDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String shortDaysAgo(String count);

  /// No description provided for @unknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownLabel;

  /// No description provided for @deviceOptionsDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Options'**
  String get deviceOptionsDefaultTitle;

  /// No description provided for @deviceTroubleshootingTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Troubleshooting'**
  String get deviceTroubleshootingTitle;

  /// No description provided for @deviceAppearsOfflineMsg.
  ///
  /// In en, this message translates to:
  /// **'Device \"{name}\" appears to be offline.'**
  String deviceAppearsOfflineMsg(String name);

  /// No description provided for @troubleshootingStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting steps:'**
  String get troubleshootingStepsTitle;

  /// No description provided for @stepCheckPower.
  ///
  /// In en, this message translates to:
  /// **'• Check device power connection'**
  String get stepCheckPower;

  /// No description provided for @stepVerifyWifi.
  ///
  /// In en, this message translates to:
  /// **'• Verify WiFi connectivity'**
  String get stepVerifyWifi;

  /// No description provided for @stepRestartDevice.
  ///
  /// In en, this message translates to:
  /// **'• Restart the device'**
  String get stepRestartDevice;

  /// No description provided for @stepCheckFirebase.
  ///
  /// In en, this message translates to:
  /// **'• Check Firebase connection'**
  String get stepCheckFirebase;

  /// No description provided for @lastSeenColonLabel.
  ///
  /// In en, this message translates to:
  /// **'Last seen: {value}'**
  String lastSeenColonLabel(String value);

  /// No description provided for @retryConnectionBtn.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get retryConnectionBtn;

  /// No description provided for @editDeviceComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Edit device feature coming soon!'**
  String get editDeviceComingSoon;

  /// No description provided for @appSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettingsTitle;

  /// No description provided for @darkModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkModeTitle;

  /// No description provided for @darkThemeActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dark theme active'**
  String get darkThemeActiveSubtitle;

  /// No description provided for @lightThemeActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Light theme active'**
  String get lightThemeActiveSubtitle;

  /// No description provided for @environmentalThresholdsTitle.
  ///
  /// In en, this message translates to:
  /// **'Environmental Thresholds'**
  String get environmentalThresholdsTitle;

  /// No description provided for @configureAutoControlTriggerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure automatic control trigger points'**
  String get configureAutoControlTriggerSubtitle;

  /// No description provided for @controlSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Control Settings'**
  String get controlSettingsTitle;

  /// No description provided for @configureAutoControlBehaviorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure automatic control behavior'**
  String get configureAutoControlBehaviorSubtitle;

  /// No description provided for @manualPriorityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Priority Timeout'**
  String get manualPriorityTimeoutTitle;

  /// No description provided for @manualPriorityTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Duration auto-control waits after manual commands'**
  String get manualPriorityTimeoutSubtitle;

  /// No description provided for @fanCycleTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan Cycle'**
  String get fanCycleTitle;

  /// No description provided for @fanCycleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled airing — cycles the fan on a timer, independent of gas/temp/humidity'**
  String get fanCycleSubtitle;

  /// No description provided for @fanCycleEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable scheduled cycle'**
  String get fanCycleEnabledLabel;

  /// No description provided for @fanCycleOnDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'ON duration'**
  String get fanCycleOnDurationLabel;

  /// No description provided for @fanCycleOffDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'OFF duration'**
  String get fanCycleOffDurationLabel;

  /// No description provided for @fanCycleActiveBanner.
  ///
  /// In en, this message translates to:
  /// **'Fan is on a scheduled cycle — manual fan control is locked while active'**
  String get fanCycleActiveBanner;

  /// No description provided for @saveBtn.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveBtn;

  /// No description provided for @systemSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemSectionTitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App version and information'**
  String get aboutSubtitle;

  /// No description provided for @connectedDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected Device'**
  String get connectedDeviceTitle;

  /// No description provided for @lotusFarmDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Lotus Farm'**
  String get lotusFarmDefaultName;

  /// No description provided for @deviceDisconnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Disconnected'**
  String get deviceDisconnectedTitle;

  /// No description provided for @unableToConnectDeviceMsg.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to device'**
  String get unableToConnectDeviceMsg;

  /// No description provided for @aboutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'About Lotus Power'**
  String get aboutDialogTitle;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String versionLabel(String version);

  /// No description provided for @builtWithFlutterFirebase.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter & Firebase'**
  String get builtWithFlutterFirebase;

  /// No description provided for @esp32IntegrationDesc.
  ///
  /// In en, this message translates to:
  /// **'ESP32 Integration for IoT monitoring'**
  String get esp32IntegrationDesc;

  /// No description provided for @copyrightLine.
  ///
  /// In en, this message translates to:
  /// **'© {year} Lotus Power'**
  String copyrightLine(String year);

  /// No description provided for @manualSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Setup'**
  String get manualSetupTitle;

  /// No description provided for @hysteresisLabel.
  ///
  /// In en, this message translates to:
  /// **'Hysteresis: {value}°'**
  String hysteresisLabel(String value);

  /// No description provided for @hysteresisDesc.
  ///
  /// In en, this message translates to:
  /// **'Prevents rapid on/off cycling'**
  String get hysteresisDesc;

  /// No description provided for @resetToDefaultsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to Recommended Defaults?'**
  String get resetToDefaultsDialogTitle;

  /// No description provided for @resetToDefaultsDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will reset all thresholds to scientifically-backed values optimized for adult broilers (5+ weeks):\n\n• Temperature: 18-24°C\n• Humidity: 50-70%\n• Gas Alert: 400 ppm\n• Hysteresis: 1.5\n\nThese values are based on Aviagen, USDA, and FAO poultry farming standards.'**
  String get resetToDefaultsDialogBody;

  /// No description provided for @resetBtn.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetBtn;

  /// No description provided for @thresholdsResetSuccessMsg.
  ///
  /// In en, this message translates to:
  /// **'✅ Thresholds reset to recommended defaults'**
  String get thresholdsResetSuccessMsg;

  /// No description provided for @errorResettingThresholds.
  ///
  /// In en, this message translates to:
  /// **'Error resetting thresholds: {error}'**
  String errorResettingThresholds(String error);

  /// No description provided for @resetToDefaultsBtnLong.
  ///
  /// In en, this message translates to:
  /// **'Reset to Recommended Defaults (Adult Birds)'**
  String get resetToDefaultsBtnLong;

  /// No description provided for @temperatureRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature Range'**
  String get temperatureRangeLabel;

  /// No description provided for @humidityRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Humidity Range'**
  String get humidityRangeLabel;

  /// No description provided for @gasLevelAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'Gas Level Alert'**
  String get gasLevelAlertLabel;

  /// No description provided for @genericErrorMsg.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String genericErrorMsg(String error);

  /// No description provided for @quickPresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Presets'**
  String get quickPresetsTitle;

  /// No description provided for @presetSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select a preset based on your poultry farming stage for optimal conditions'**
  String get presetSelectHint;

  /// No description provided for @temperaturePresetAppliedMsg.
  ///
  /// In en, this message translates to:
  /// **'Temperature preset applied successfully!'**
  String get temperaturePresetAppliedMsg;

  /// No description provided for @humidityPresetAppliedMsg.
  ///
  /// In en, this message translates to:
  /// **'Humidity preset applied successfully!'**
  String get humidityPresetAppliedMsg;

  /// No description provided for @resetToDefaultsBtnShort.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get resetToDefaultsBtnShort;

  /// No description provided for @thresholdsResetToDefaultsMsg.
  ///
  /// In en, this message translates to:
  /// **'Thresholds reset to defaults'**
  String get thresholdsResetToDefaultsMsg;

  /// No description provided for @chooseTimeoutDurationMsg.
  ///
  /// In en, this message translates to:
  /// **'Choose how long auto-control should wait after you manually adjust devices:'**
  String get chooseTimeoutDurationMsg;

  /// No description provided for @seconds15.
  ///
  /// In en, this message translates to:
  /// **'15 seconds'**
  String get seconds15;

  /// No description provided for @seconds30.
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get seconds30;

  /// No description provided for @minute1.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get minute1;

  /// No description provided for @minutes2.
  ///
  /// In en, this message translates to:
  /// **'2 minutes'**
  String get minutes2;

  /// No description provided for @minutes5.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get minutes5;

  /// No description provided for @manualPriorityTimeoutSetMsg.
  ///
  /// In en, this message translates to:
  /// **'Manual priority timeout set to {label}'**
  String manualPriorityTimeoutSetMsg(String label);

  /// No description provided for @minimumLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get minimumLabel;

  /// No description provided for @maximumLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get maximumLabel;

  /// No description provided for @validRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Valid range: {min}-{max} {unit}'**
  String validRangeLabel(String min, String max, String unit);

  /// No description provided for @customLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customLabel;

  /// No description provided for @plainRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'{min} - {max} {unit}'**
  String plainRangeLabel(String min, String max, String unit);

  /// No description provided for @customRangeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom {label} Range'**
  String customRangeDialogTitle(String label);

  /// No description provided for @minimumUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum {unit}'**
  String minimumUnitLabel(String unit);

  /// No description provided for @maximumUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum {unit}'**
  String maximumUnitLabel(String unit);

  /// No description provided for @applyBtn.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyBtn;

  /// No description provided for @presetChicks.
  ///
  /// In en, this message translates to:
  /// **'Chicks (0-1 week)'**
  String get presetChicks;

  /// No description provided for @presetYoung.
  ///
  /// In en, this message translates to:
  /// **'Young (1-2 weeks)'**
  String get presetYoung;

  /// No description provided for @presetGrowing.
  ///
  /// In en, this message translates to:
  /// **'Growing (3-4 weeks)'**
  String get presetGrowing;

  /// No description provided for @presetAdults.
  ///
  /// In en, this message translates to:
  /// **'Adults (5+ weeks)'**
  String get presetAdults;

  /// No description provided for @presetLayers.
  ///
  /// In en, this message translates to:
  /// **'Layers (optimal)'**
  String get presetLayers;

  /// No description provided for @presetDryClimate.
  ///
  /// In en, this message translates to:
  /// **'Dry Climate'**
  String get presetDryClimate;

  /// No description provided for @presetStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get presetStandard;

  /// No description provided for @presetHumidClimate.
  ///
  /// In en, this message translates to:
  /// **'Humid Climate'**
  String get presetHumidClimate;

  /// No description provided for @presetHatching.
  ///
  /// In en, this message translates to:
  /// **'Hatching'**
  String get presetHatching;

  /// No description provided for @pleaseEnterWifiCreds.
  ///
  /// In en, this message translates to:
  /// **'Please enter your WiFi network name and password'**
  String get pleaseEnterWifiCreds;

  /// No description provided for @deviceSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Setup'**
  String get deviceSetupTitle;

  /// No description provided for @deviceWifiSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Device WiFi Setup'**
  String get deviceWifiSetupTitle;

  /// No description provided for @configureDeviceWifiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure your device to connect to WiFi'**
  String get configureDeviceWifiSubtitle;

  /// No description provided for @beforeYouStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Before You Start'**
  String get beforeYouStartTitle;

  /// No description provided for @stepConnectDeviceWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to device WiFi'**
  String get stepConnectDeviceWifiTitle;

  /// No description provided for @stepConnectDeviceWifiDesc.
  ///
  /// In en, this message translates to:
  /// **'Go to WiFi settings → Connect to \"PoultryFarm_Setup\"'**
  String get stepConnectDeviceWifiDesc;

  /// No description provided for @stepEnterCredsTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter credentials below'**
  String get stepEnterCredsTitle;

  /// No description provided for @stepEnterCredsDesc.
  ///
  /// In en, this message translates to:
  /// **'Fill in your home WiFi details'**
  String get stepEnterCredsDesc;

  /// No description provided for @stepSendConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Send configuration'**
  String get stepSendConfigTitle;

  /// No description provided for @stepSendConfigDesc.
  ///
  /// In en, this message translates to:
  /// **'Device will connect to your network'**
  String get stepSendConfigDesc;

  /// No description provided for @wifiCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'WiFi Credentials'**
  String get wifiCredentialsTitle;

  /// No description provided for @networkNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Network Name (SSID)'**
  String get networkNameLabel;

  /// No description provided for @networkNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your WiFi name'**
  String get networkNameHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your WiFi password'**
  String get passwordHint;

  /// No description provided for @sendCredentialsBtn.
  ///
  /// In en, this message translates to:
  /// **'Send Credentials to Device'**
  String get sendCredentialsBtn;

  /// No description provided for @tryAgainBtn.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgainBtn;

  /// No description provided for @provisionCheckingPermissions.
  ///
  /// In en, this message translates to:
  /// **'Checking permissions...'**
  String get provisionCheckingPermissions;

  /// No description provided for @provisionSendingCredentials.
  ///
  /// In en, this message translates to:
  /// **'Sending credentials to device...'**
  String get provisionSendingCredentials;

  /// No description provided for @provisionSuccessMsg.
  ///
  /// In en, this message translates to:
  /// **'Provisioning successful! Device will restart and connect to your WiFi.'**
  String get provisionSuccessMsg;

  /// No description provided for @provisionAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required. Please log in and try again.'**
  String get provisionAuthRequired;

  /// No description provided for @provisionDeviceRestartedLikelySuccess.
  ///
  /// In en, this message translates to:
  /// **'Device restarted after receiving credentials. Provisioning likely successful - please check if your device appears online in the app.'**
  String get provisionDeviceRestartedLikelySuccess;

  /// No description provided for @provisionTimedOutLikelySuccess.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. The device may have restarted successfully - please wait a moment and check if it appears in your device list.'**
  String get provisionTimedOutLikelySuccess;

  /// No description provided for @provisionCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Cannot communicate with device. Please ensure:\n• You are connected to \"PoultryFarm_Setup\" WiFi\n• Device is powered on\n• Try moving closer to the device'**
  String get provisionCannotConnect;

  /// No description provided for @provisionAuthFailedReLogin.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please log out and log back in, then try again.'**
  String get provisionAuthFailedReLogin;

  /// No description provided for @provisionDeviceRejectedData.
  ///
  /// In en, this message translates to:
  /// **'Device rejected the data. Please ensure you are connected to the device WiFi and try again.'**
  String get provisionDeviceRejectedData;

  /// No description provided for @provisionDeviceInternalError.
  ///
  /// In en, this message translates to:
  /// **'Device internal error. Please restart the device and try again.'**
  String get provisionDeviceInternalError;

  /// No description provided for @provisionDeviceRejectedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Device could not process the credentials. Please check your WiFi password and try again.'**
  String get provisionDeviceRejectedCredentials;

  /// No description provided for @provisionLocationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission required. Please enable location services in app settings to configure WiFi.'**
  String get provisionLocationPermissionRequired;

  /// No description provided for @provisionPermissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'App permissions required. Please grant all requested permissions in settings.'**
  String get provisionPermissionsRequired;

  /// No description provided for @provisionGenericSetupError.
  ///
  /// In en, this message translates to:
  /// **'Setup error: {error}'**
  String provisionGenericSetupError(String error);

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline'**
  String get offlineTitle;

  /// No description provided for @couldNotConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to server'**
  String get couldNotConnectTitle;

  /// No description provided for @offlineBody.
  ///
  /// In en, this message translates to:
  /// **'Check your network connection and tap Retry.'**
  String get offlineBody;

  /// No description provided for @genericStartupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'An error occurred during startup. Tap Retry to try again.'**
  String get genericStartupErrorBody;

  /// No description provided for @tempLowGteHighError.
  ///
  /// In en, this message translates to:
  /// **'Temperature low must be less than temperature high'**
  String get tempLowGteHighError;

  /// No description provided for @tempRangeTooNarrowError.
  ///
  /// In en, this message translates to:
  /// **'Temperature range too narrow (minimum 2°C difference)'**
  String get tempRangeTooNarrowError;

  /// No description provided for @tempOutOfRangeError.
  ///
  /// In en, this message translates to:
  /// **'Temperature must be between {min}°C and {max}°C'**
  String tempOutOfRangeError(String min, String max);

  /// No description provided for @humidityLowGteHighError.
  ///
  /// In en, this message translates to:
  /// **'Humidity low must be less than humidity high'**
  String get humidityLowGteHighError;

  /// No description provided for @humidityRangeTooNarrowError.
  ///
  /// In en, this message translates to:
  /// **'Humidity range too narrow (minimum 5% difference)'**
  String get humidityRangeTooNarrowError;

  /// No description provided for @humidityOutOfRangeError.
  ///
  /// In en, this message translates to:
  /// **'Humidity must be between {min}% and {max}%'**
  String humidityOutOfRangeError(String min, String max);

  /// No description provided for @gasOutOfRangeError.
  ///
  /// In en, this message translates to:
  /// **'Gas threshold must be between 1 and {max} ppm'**
  String gasOutOfRangeError(String max);

  /// No description provided for @hysteresisOutOfRangeError.
  ///
  /// In en, this message translates to:
  /// **'Hysteresis must be between 0.5 and 10.0'**
  String get hysteresisOutOfRangeError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
