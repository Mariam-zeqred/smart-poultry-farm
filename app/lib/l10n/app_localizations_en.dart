// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get visionTabLabel => 'AI Monitor';

  @override
  String get visionScreenSubtitle => 'Vision analysis & alerts';

  @override
  String get snapshotCardTitle => 'Vision Analysis Snapshot';

  @override
  String get statBirdsTracked => 'Birds tracked';

  @override
  String get statActivityLevel => 'Activity level';

  @override
  String get statHealthyUnhealthy => 'Healthy / Unhealthy';

  @override
  String get behaviorMixLabel => 'Behavior mix (eat-drink / moving / rest)';

  @override
  String get behaviorEatDrink => 'eat-drink';

  @override
  String get behaviorMoving => 'moving';

  @override
  String get behaviorRest => 'rest';

  @override
  String hotspotInfo(String row, String col, String intensity) {
    return 'Hotspot: row $row, col $col (intensity $intensity)';
  }

  @override
  String get hotspotUnknown => 'Hotspot: —';

  @override
  String lastUpdated(String age) {
    return 'Last updated $age';
  }

  @override
  String lastUpdatedStale(String age) {
    return 'Last updated $age — stale';
  }

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String get noDataYet =>
      'No analysis received yet — waiting for the vision camera/analyzer to report in.';

  @override
  String get statusNormal => 'NORMAL';

  @override
  String get statusWatch => 'WATCH';

  @override
  String get statusAlert => 'ALERT';

  @override
  String get statusStale => 'STALE';

  @override
  String get statusNoData => 'NO DATA';

  @override
  String get activityHigh => 'High';

  @override
  String get activityMedium => 'Medium';

  @override
  String get activityLow => 'Low';

  @override
  String get activityUnknown => '—';

  @override
  String get trendsCardTitle => 'Trends';

  @override
  String get trendsHint => 'Last sessions logged locally';

  @override
  String get trendBirdCount => 'Bird count';

  @override
  String get trendUnhealthyPct => 'Unhealthy %';

  @override
  String get alertsCardTitle => 'Alerts';

  @override
  String get showResolved => 'Show resolved';

  @override
  String get noAlertsYet => 'No alerts yet — try a Simulate scenario.';

  @override
  String get acknowledgeBtn => 'Acknowledge';

  @override
  String get acknowledgedBtn => 'Acknowledged';

  @override
  String get resolveBtn => 'Resolve';

  @override
  String get resolvedBtn => 'Resolved';

  @override
  String get alertTypeTemperatureHigh => 'High Temperature';

  @override
  String get alertTypeTemperatureLow => 'Low Temperature';

  @override
  String get alertTypeHumidityHigh => 'High Humidity';

  @override
  String get alertTypeHumidityLow => 'Low Humidity';

  @override
  String get alertTypeGasDetected => 'Gas Detection';

  @override
  String get alertTypeGasCritical => 'Critical Gas Level';

  @override
  String get alertTypeTempCriticalLow => 'Critical Low Temperature';

  @override
  String get alertTypeTempCriticalHigh => 'Critical High Temperature';

  @override
  String get alertTypeHumCriticalLow => 'Critical Low Humidity';

  @override
  String get alertTypeHumCriticalHigh => 'Critical High Humidity';

  @override
  String get alertTypeVisionStale => 'AI Feed Offline';

  @override
  String get alertTypeVisionUnhealthyRate => 'Unhealthy Rate';

  @override
  String get alertTypeVisionActivityLow => 'Low Activity';

  @override
  String get alertTypeVisionBirdCountDrop => 'Bird Count Drop';

  @override
  String get alertTypeVisionOvercrowding => 'Overcrowding';

  @override
  String get alertTypeVisionFeedingStalled => 'Feeding Stalled';

  @override
  String get alertTypeVisionCombinedHealthActivity => 'Health + Activity Risk';

  @override
  String get alertTypeVisionCombinedMortality => 'Possible Mortality Event';

  @override
  String msgVisionStale(String minutes) {
    return 'No new AI analysis in $minutes min — check the camera / desktop analyzer.';
  }

  @override
  String msgVisionUnhealthyRate(String pct, String unhealthy, String total) {
    return 'Unhealthy detection rate at $pct% ($unhealthy/$total birds).';
  }

  @override
  String msgVisionActivityLow(String count) {
    return 'Activity level has been low for $count consecutive sessions.';
  }

  @override
  String msgVisionBirdCountDrop(String count, String pct, String baseline) {
    return 'Tracked bird count dropped to $count, more than $pct% below the recent baseline (~$baseline).';
  }

  @override
  String msgVisionOvercrowding(
      String ratio, String multiplier, String row, String col) {
    return 'Activity-hotspot intensity per bird spiked to $ratio (~${multiplier}x recent baseline) near row $row, col $col — possible crowding/huddling.';
  }

  @override
  String msgVisionFeedingStalled(String pct, String count) {
    return 'Eat/drink activity has been under $pct% for $count consecutive sessions — check feeder/waterer.';
  }

  @override
  String msgVisionCombinedHealthActivity(String pct) {
    return 'Unhealthy rate $pct% together with sustained low activity — inactivity may indicate illness rather than rest.';
  }

  @override
  String msgVisionCombinedMortality(String count, String baseline, String pct) {
    return 'Bird count dropped to $count (baseline ~$baseline) while unhealthy rate is $pct% — possible mortality event.';
  }

  @override
  String get thresholdsCardTitle => 'Alarm thresholds';

  @override
  String get thresholdsSaveBtn => 'Save thresholds';

  @override
  String get thresholdsSaved => 'Saved';

  @override
  String get thUnhealthyWarnPct => 'Unhealthy % (warning)';

  @override
  String get thUnhealthyCriticalPct => 'Unhealthy % (critical)';

  @override
  String get thActivityLowSustainedCount => 'Low-activity sessions to alarm';

  @override
  String get thBirdCountDropPct => 'Bird count drop %';

  @override
  String get thBirdCountSustainedCount => 'Drop sessions to alarm';

  @override
  String get thHotspotSpikeRatio => 'Overcrowding spike ratio (x baseline)';

  @override
  String get thFeedingStalledPct => 'Feeding-stalled % floor';

  @override
  String get thFeedingSustainedCount => 'Feeding-stalled sessions to alarm';

  @override
  String get thStaleMinutes => 'Stale after (minutes)';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get closeBtn => 'Close';

  @override
  String get retryBtn => 'Retry';

  @override
  String get cancelBtnGeneric => 'Cancel';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navDevices => 'Devices';

  @override
  String get navSettings => 'Settings';

  @override
  String get dashMyFarmTitle => 'My Farm';

  @override
  String get noDeviceConnectedTitle => 'No Device Connected';

  @override
  String get noDeviceConnectedSubtitle => 'Connect your ESP32 to start';

  @override
  String get waitingForDeviceLabel => 'WAITING FOR DEVICE';

  @override
  String get connectYourDeviceTitle => 'Connect Your Device';

  @override
  String get connectYourDeviceBody =>
      'Go to the Devices tab to add and configure your ESP32 controller';

  @override
  String get goToDevicesBtn => 'Go to Devices';

  @override
  String get farmControlTitle => 'Farm Control';

  @override
  String get disabledBadge => 'DISABLED';

  @override
  String get controlsDisabledMsg =>
      'Controls are disabled until a device connects';

  @override
  String get ventilationTitle => 'Ventilation';

  @override
  String get fanControlSubtitle => 'Fan Control';

  @override
  String get coolingTitle => 'Cooling';

  @override
  String get coolerControlSubtitle => 'Cooler Control';

  @override
  String get heaterTitle => 'Heater';

  @override
  String get heatingControlSubtitle => 'Heating Control';

  @override
  String get humidifierTitle => 'Humidifier';

  @override
  String get humidifierControlSubtitle => 'Humidifier Control';

  @override
  String get stateOn => 'ON';

  @override
  String get stateOff => 'OFF';

  @override
  String get realtimeMonitoringSubtitle => 'Real-time Monitoring';

  @override
  String get lastUpdateLabel => 'Last Update';

  @override
  String get temperatureLabel => 'Temperature';

  @override
  String get humidityLabel => 'Humidity';

  @override
  String get airQualityLabel => 'Air Quality';

  @override
  String get overallLabel => 'Overall';

  @override
  String idealTempRange(String low, String high) {
    return 'Ideal: $low-$high°C';
  }

  @override
  String idealHumidityRange(String low, String high) {
    return 'Ideal: $low-$high%';
  }

  @override
  String goodGasRange(String max) {
    return 'Good: <$max ppm';
  }

  @override
  String get farmConditionLabel => 'Farm Condition';

  @override
  String get autoBadge => 'AUTO';

  @override
  String get manualBadge => 'MANUAL';

  @override
  String get farmControlModeLabel => 'Farm Control Mode';

  @override
  String get autoControlSystemDesc => 'System automatically controls farm';

  @override
  String get manualControlDesc => 'Manual control of farm devices';

  @override
  String get autoControlPausedTitle => 'Auto-Control Paused';

  @override
  String manualPriorityRemainingMsg(String seconds) {
    return 'Manual priority: ~${seconds}s remaining';
  }

  @override
  String get autoControlActiveTitle => 'Auto-Control Active';

  @override
  String get safetyOverrideActiveTitle => '🚨 SAFETY OVERRIDE ACTIVE';

  @override
  String get safetyOverrideDefaultReason =>
      'Critical safety limits triggered - controls locked';

  @override
  String get recentActivityTitle => 'Recent Activity';

  @override
  String get temperatureReadingLabel => 'Temperature Reading';

  @override
  String get fanStatusLabel => 'Fan Status';

  @override
  String get coolerStatusLabel => 'Cooler Status';

  @override
  String get heaterStatusLabel => 'Heater Status';

  @override
  String get loadingFarmData => 'Loading farm data...';

  @override
  String get healthCritical => 'Critical';

  @override
  String get healthWarning => 'Warning';

  @override
  String get healthExcellent => 'Excellent';

  @override
  String get lockedSafetyOverrideTooltip => 'Locked: Safety override active';

  @override
  String get lockedAutomaticModeTooltip => 'Locked: Automatic mode enabled';

  @override
  String get lockedAppControlTooltip => 'Locked: Device LCD is in control';

  @override
  String get appControlToggleLabel => 'App Control';

  @override
  String get appControlEnabledDesc => 'App is controlling the device';

  @override
  String get appControlDisabledDesc =>
      'Device LCD is controlling — app is view-only';

  @override
  String get noDeviceConnectedBody =>
      'Connect your farm controller to start monitoring\nand controlling your poultry environment';

  @override
  String get addNewDeviceBtn => 'Add New Device';

  @override
  String get wifiSetupHint => 'This will guide you through WiFi setup';

  @override
  String get whatYouCanDoTitle => 'What you can do:';

  @override
  String get featureMonitoringTitle => 'Real-time Monitoring';

  @override
  String get featureMonitoringDesc =>
      'Track temperature, humidity & air quality';

  @override
  String get featureAutoControlTitle => 'Automatic Control';

  @override
  String get featureAutoControlDesc => 'Smart environmental adjustments';

  @override
  String get featureAlertsTitle => 'Instant Alerts';

  @override
  String get featureAlertsDesc => 'Get notified of any issues';

  @override
  String get connectAnotherControllerSubtitle =>
      'Connect another farm controller';

  @override
  String get onlineBadge => 'ONLINE';

  @override
  String get offlineBadge => 'OFFLINE';

  @override
  String firmwareLabel(String firmware) {
    return 'Firmware: $firmware';
  }

  @override
  String get viewDetailsOption => 'View Details';

  @override
  String get editDeviceOption => 'Edit Device';

  @override
  String get refreshDataOption => 'Refresh Data';

  @override
  String get refreshingDeviceData => 'Refreshing device data...';

  @override
  String get troubleshootOption => 'Troubleshoot';

  @override
  String get deviceDetailsTitle => 'Device Details';

  @override
  String get nameLabel => 'Name';

  @override
  String get statusLabel => 'Status';

  @override
  String get lastSeenLabel => 'Last Seen';

  @override
  String get deviceIdLabel => 'Device ID';

  @override
  String get firmwareOnlyLabel => 'Firmware';

  @override
  String get currentReadingsTitle => 'Current Readings:';

  @override
  String get controlSettingsColonTitle => 'Control Settings:';

  @override
  String get controlModeLabel => 'Control Mode';

  @override
  String get fanLabel => 'Fan';

  @override
  String get coolerLabel => 'Cooler';

  @override
  String get statusOnlineValue => 'Online';

  @override
  String get statusOfflineValue => 'Offline';

  @override
  String get justNowSentence => 'Just now';

  @override
  String shortMinutesAgo(String count) {
    return '${count}m ago';
  }

  @override
  String shortHoursAgo(String count) {
    return '${count}h ago';
  }

  @override
  String shortDaysAgo(String count) {
    return '${count}d ago';
  }

  @override
  String get unknownLabel => 'Unknown';

  @override
  String get deviceOptionsDefaultTitle => 'Device Options';

  @override
  String get deviceTroubleshootingTitle => 'Device Troubleshooting';

  @override
  String deviceAppearsOfflineMsg(String name) {
    return 'Device \"$name\" appears to be offline.';
  }

  @override
  String get troubleshootingStepsTitle => 'Troubleshooting steps:';

  @override
  String get stepCheckPower => '• Check device power connection';

  @override
  String get stepVerifyWifi => '• Verify WiFi connectivity';

  @override
  String get stepRestartDevice => '• Restart the device';

  @override
  String get stepCheckFirebase => '• Check Firebase connection';

  @override
  String lastSeenColonLabel(String value) {
    return 'Last seen: $value';
  }

  @override
  String get retryConnectionBtn => 'Retry Connection';

  @override
  String get editDeviceComingSoon => 'Edit device feature coming soon!';

  @override
  String get appSettingsTitle => 'App Settings';

  @override
  String get darkModeTitle => 'Dark Mode';

  @override
  String get darkThemeActiveSubtitle => 'Dark theme active';

  @override
  String get lightThemeActiveSubtitle => 'Light theme active';

  @override
  String get environmentalThresholdsTitle => 'Environmental Thresholds';

  @override
  String get configureAutoControlTriggerSubtitle =>
      'Configure automatic control trigger points';

  @override
  String get controlSettingsTitle => 'Control Settings';

  @override
  String get configureAutoControlBehaviorSubtitle =>
      'Configure automatic control behavior';

  @override
  String get manualPriorityTimeoutTitle => 'Manual Priority Timeout';

  @override
  String get manualPriorityTimeoutSubtitle =>
      'Duration auto-control waits after manual commands';

  @override
  String get fanCycleTitle => 'Fan Cycle';

  @override
  String get fanCycleSubtitle =>
      'Scheduled airing — cycles the fan on a timer, independent of gas/temp/humidity';

  @override
  String get fanCycleEnabledLabel => 'Enable scheduled cycle';

  @override
  String get fanCycleOnDurationLabel => 'ON duration';

  @override
  String get fanCycleOffDurationLabel => 'OFF duration';

  @override
  String get fanCycleActiveBanner =>
      'Fan is on a scheduled cycle — manual fan control is locked while active';

  @override
  String get saveBtn => 'Save';

  @override
  String get systemSectionTitle => 'System';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutSubtitle => 'App version and information';

  @override
  String get connectedDeviceTitle => 'Connected Device';

  @override
  String get lotusFarmDefaultName => 'Lotus Farm';

  @override
  String get deviceDisconnectedTitle => 'Device Disconnected';

  @override
  String get unableToConnectDeviceMsg => 'Unable to connect to device';

  @override
  String get aboutDialogTitle => 'About Lotus Power';

  @override
  String versionLabel(String version) {
    return 'Version: $version';
  }

  @override
  String get builtWithFlutterFirebase => 'Built with Flutter & Firebase';

  @override
  String get esp32IntegrationDesc => 'ESP32 Integration for IoT monitoring';

  @override
  String copyrightLine(String year) {
    return '© $year Lotus Power';
  }

  @override
  String get manualSetupTitle => 'Manual Setup';

  @override
  String hysteresisLabel(String value) {
    return 'Hysteresis: $value°';
  }

  @override
  String get hysteresisDesc => 'Prevents rapid on/off cycling';

  @override
  String get resetToDefaultsDialogTitle => 'Reset to Recommended Defaults?';

  @override
  String get resetToDefaultsDialogBody =>
      'This will reset all thresholds to scientifically-backed values optimized for adult broilers (5+ weeks):\n\n• Temperature: 18-24°C\n• Humidity: 50-70%\n• Gas Alert: 400 ppm\n• Hysteresis: 1.5\n\nThese values are based on Aviagen, USDA, and FAO poultry farming standards.';

  @override
  String get resetBtn => 'Reset';

  @override
  String get thresholdsResetSuccessMsg =>
      '✅ Thresholds reset to recommended defaults';

  @override
  String errorResettingThresholds(String error) {
    return 'Error resetting thresholds: $error';
  }

  @override
  String get resetToDefaultsBtnLong =>
      'Reset to Recommended Defaults (Adult Birds)';

  @override
  String get temperatureRangeLabel => 'Temperature Range';

  @override
  String get humidityRangeLabel => 'Humidity Range';

  @override
  String get gasLevelAlertLabel => 'Gas Level Alert';

  @override
  String genericErrorMsg(String error) {
    return 'Error: $error';
  }

  @override
  String get quickPresetsTitle => 'Quick Presets';

  @override
  String get presetSelectHint =>
      'Select a preset based on your poultry farming stage for optimal conditions';

  @override
  String get temperaturePresetAppliedMsg =>
      'Temperature preset applied successfully!';

  @override
  String get humidityPresetAppliedMsg =>
      'Humidity preset applied successfully!';

  @override
  String get resetToDefaultsBtnShort => 'Reset to Defaults';

  @override
  String get thresholdsResetToDefaultsMsg => 'Thresholds reset to defaults';

  @override
  String get chooseTimeoutDurationMsg =>
      'Choose how long auto-control should wait after you manually adjust devices:';

  @override
  String get seconds15 => '15 seconds';

  @override
  String get seconds30 => '30 seconds';

  @override
  String get minute1 => '1 minute';

  @override
  String get minutes2 => '2 minutes';

  @override
  String get minutes5 => '5 minutes';

  @override
  String manualPriorityTimeoutSetMsg(String label) {
    return 'Manual priority timeout set to $label';
  }

  @override
  String get minimumLabel => 'Minimum';

  @override
  String get maximumLabel => 'Maximum';

  @override
  String validRangeLabel(String min, String max, String unit) {
    return 'Valid range: $min-$max $unit';
  }

  @override
  String get customLabel => 'Custom';

  @override
  String plainRangeLabel(String min, String max, String unit) {
    return '$min - $max $unit';
  }

  @override
  String customRangeDialogTitle(String label) {
    return 'Custom $label Range';
  }

  @override
  String minimumUnitLabel(String unit) {
    return 'Minimum $unit';
  }

  @override
  String maximumUnitLabel(String unit) {
    return 'Maximum $unit';
  }

  @override
  String get applyBtn => 'Apply';

  @override
  String get presetChicks => 'Chicks (0-1 week)';

  @override
  String get presetYoung => 'Young (1-2 weeks)';

  @override
  String get presetGrowing => 'Growing (3-4 weeks)';

  @override
  String get presetAdults => 'Adults (5+ weeks)';

  @override
  String get presetLayers => 'Layers (optimal)';

  @override
  String get presetDryClimate => 'Dry Climate';

  @override
  String get presetStandard => 'Standard';

  @override
  String get presetHumidClimate => 'Humid Climate';

  @override
  String get presetHatching => 'Hatching';

  @override
  String get pleaseEnterWifiCreds =>
      'Please enter your WiFi network name and password';

  @override
  String get deviceSetupTitle => 'Device Setup';

  @override
  String get deviceWifiSetupTitle => 'Device WiFi Setup';

  @override
  String get configureDeviceWifiSubtitle =>
      'Configure your device to connect to WiFi';

  @override
  String get beforeYouStartTitle => 'Before You Start';

  @override
  String get stepConnectDeviceWifiTitle => 'Connect to device WiFi';

  @override
  String get stepConnectDeviceWifiDesc =>
      'Go to WiFi settings → Connect to \"PoultryFarm_Setup\"';

  @override
  String get stepEnterCredsTitle => 'Enter credentials below';

  @override
  String get stepEnterCredsDesc => 'Fill in your home WiFi details';

  @override
  String get stepSendConfigTitle => 'Send configuration';

  @override
  String get stepSendConfigDesc => 'Device will connect to your network';

  @override
  String get wifiCredentialsTitle => 'WiFi Credentials';

  @override
  String get networkNameLabel => 'Network Name (SSID)';

  @override
  String get networkNameHint => 'Enter your WiFi name';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your WiFi password';

  @override
  String get sendCredentialsBtn => 'Send Credentials to Device';

  @override
  String get tryAgainBtn => 'Try Again';

  @override
  String get provisionCheckingPermissions => 'Checking permissions...';

  @override
  String get provisionSendingCredentials => 'Sending credentials to device...';

  @override
  String get provisionSuccessMsg =>
      'Provisioning successful! Device will restart and connect to your WiFi.';

  @override
  String get provisionAuthRequired =>
      'Authentication required. Please log in and try again.';

  @override
  String get provisionDeviceRestartedLikelySuccess =>
      'Device restarted after receiving credentials. Provisioning likely successful - please check if your device appears online in the app.';

  @override
  String get provisionTimedOutLikelySuccess =>
      'Request timed out. The device may have restarted successfully - please wait a moment and check if it appears in your device list.';

  @override
  String get provisionCannotConnect =>
      'Cannot communicate with device. Please ensure:\n• You are connected to \"PoultryFarm_Setup\" WiFi\n• Device is powered on\n• Try moving closer to the device';

  @override
  String get provisionAuthFailedReLogin =>
      'Authentication failed. Please log out and log back in, then try again.';

  @override
  String get provisionDeviceRejectedData =>
      'Device rejected the data. Please ensure you are connected to the device WiFi and try again.';

  @override
  String get provisionDeviceInternalError =>
      'Device internal error. Please restart the device and try again.';

  @override
  String get provisionDeviceRejectedCredentials =>
      'Device could not process the credentials. Please check your WiFi password and try again.';

  @override
  String get provisionLocationPermissionRequired =>
      'Location permission required. Please enable location services in app settings to configure WiFi.';

  @override
  String get provisionPermissionsRequired =>
      'App permissions required. Please grant all requested permissions in settings.';

  @override
  String provisionGenericSetupError(String error) {
    return 'Setup error: $error';
  }

  @override
  String get offlineTitle => 'You appear to be offline';

  @override
  String get couldNotConnectTitle => 'Could not connect to server';

  @override
  String get offlineBody => 'Check your network connection and tap Retry.';

  @override
  String get genericStartupErrorBody =>
      'An error occurred during startup. Tap Retry to try again.';

  @override
  String get tempLowGteHighError =>
      'Temperature low must be less than temperature high';

  @override
  String get tempRangeTooNarrowError =>
      'Temperature range too narrow (minimum 2°C difference)';

  @override
  String tempOutOfRangeError(String min, String max) {
    return 'Temperature must be between $min°C and $max°C';
  }

  @override
  String get humidityLowGteHighError =>
      'Humidity low must be less than humidity high';

  @override
  String get humidityRangeTooNarrowError =>
      'Humidity range too narrow (minimum 5% difference)';

  @override
  String humidityOutOfRangeError(String min, String max) {
    return 'Humidity must be between $min% and $max%';
  }

  @override
  String gasOutOfRangeError(String max) {
    return 'Gas threshold must be between 1 and $max ppm';
  }

  @override
  String get hysteresisOutOfRangeError =>
      'Hysteresis must be between 0.5 and 10.0';
}
