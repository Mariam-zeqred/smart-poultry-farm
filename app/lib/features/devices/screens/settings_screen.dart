/// Settings tab: comfort-range thresholds (temperature, humidity, gas) with
/// the hysteresis info banner, the fan-cycle schedule, dark/light theme and
/// English/Arabic language.
///
/// Threshold edits are written to `farm/config/thresholds`; the firmware
/// polls that node every 30 s, so a change takes up to half a minute to
/// reach the relays.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/device_model.dart';
import '../../../core/models/sensor_model.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/device_provider.dart';
import '../widgets/threshold_input_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final locale = ref.watch(localeProvider);
    final localeNotifier = ref.read(localeProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final deviceAsync = ref.watch(deviceProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : colors.surface,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Information Section
          deviceAsync.when(
            data: (deviceData) => _buildDeviceInfoSection(deviceData, isDarkMode, colors, context),
            loading: () => _buildLoadingCard(isDarkMode, colors),
            error: (error, stack) => _buildErrorCard(error, isDarkMode, colors, context),
          ),
          
          const SizedBox(height: 24),
          
          // App Settings
          Text(
            l10n.appSettingsTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDarkMode ? Colors.grey[800] : colors.surface,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    isDarkMode ? Iconsax.moon : Iconsax.sun_1,
                    color: colors.primary,
                  ),
                  title: Text(
                    l10n.darkModeTitle,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : colors.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    isDarkMode ? l10n.darkThemeActiveSubtitle : l10n.lightThemeActiveSubtitle,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  trailing: Switch(
                    value: isDarkMode,
                    onChanged: (value) => themeNotifier.toggleTheme(),
                    activeColor: colors.primary,
                  ),
                ),
                Divider(height: 1, color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
                ListTile(
                  leading: Icon(Iconsax.global, color: colors.primary),
                  title: Text(
                    l10n.settingsLanguageTitle,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : colors.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    locale.languageCode == 'ar' ? l10n.settingsLanguageArabic : l10n.settingsLanguageEnglish,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('EN')),
                      ButtonSegment(value: 'ar', label: Text('AR')),
                    ],
                    selected: {locale.languageCode},
                    onSelectionChanged: (selection) {
                      localeNotifier.setLocale(Locale(selection.first));
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      selectedBackgroundColor: colors.primary.withValues(alpha: 0.15),
                      selectedForegroundColor: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Device Control Section — App Control ownership toggle, moved
          // here from the Dashboard (2026-08-30, user request): it's a
          // device-configuration setting (hands control between the app and
          // the device LCD), not something that needs to sit front-and-
          // center on the live monitoring screen.
          Text(
            l10n.appControlToggleLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDarkMode ? Colors.grey[800] : colors.surface,
            child: deviceAsync.when(
              data: (deviceData) => SwitchListTile(
                secondary: Icon(
                  deviceData.state.appControlEnabled ? Icons.smartphone : Icons.dvr,
                  color: deviceData.state.appControlEnabled ? Colors.blue : Colors.orange,
                ),
                title: Text(
                  l10n.appControlToggleLabel,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  deviceData.state.appControlEnabled
                      ? l10n.appControlEnabledDesc
                      : l10n.appControlDisabledDesc,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                value: deviceData.state.appControlEnabled,
                activeColor: Colors.blue,
                onChanged: deviceData.state.safetyOverride == true
                    ? null // Disable toggle when safety override active
                    : (value) => ref.read(deviceRepoProvider).setAppControlEnabled(value),
              ),
              loading: () => const ListTile(
                title: SizedBox(height: 20, child: LinearProgressIndicator()),
              ),
              error: (error, stack) => const SizedBox.shrink(),
            ),
          ),

          const SizedBox(height: 24),

          // Threshold Configuration Section
          Text(
            l10n.environmentalThresholdsTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.configureAutoControlTriggerSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          
          deviceAsync.when(
            data: (deviceData) => _buildThresholdSettings(
              context, 
              deviceData, 
              ref.read(deviceRepoProvider),
              isDarkMode, 
              colors,
            ),
            loading: () => _buildLoadingCard(isDarkMode, colors),
            error: (error, stack) => const SizedBox.shrink(),
          ),
          
          const SizedBox(height: 24),

          // Fan Cycle Section
          Text(
            l10n.fanCycleTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.fanCycleSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDarkMode ? Colors.grey[800] : colors.surface,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.repeat, color: Colors.teal, size: 24),
              ),
              title: Text(
                l10n.fanCycleTitle,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                deviceAsync.value != null
                    ? (deviceAsync.value!.fanCycle.enabled
                        ? '${_formatDuration(deviceAsync.value!.fanCycle.onSec)} ON / ${_formatDuration(deviceAsync.value!.fanCycle.offSec)} OFF'
                        : l10n.stateOff)
                    : l10n.stateOff,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                icon: Icon(Icons.settings, color: colors.primary),
                onPressed: () => _showFanCycleDialog(
                  context,
                  ref.read(deviceRepoProvider),
                  deviceAsync.value,
                  isDarkMode,
                  colors,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // System
          Text(
            l10n.systemSectionTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDarkMode ? Colors.grey[800] : colors.surface,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Iconsax.info_circle,
                    color: colors.primary,
                  ),
                  title: Text(
                    l10n.aboutTitle,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : colors.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    l10n.aboutSubtitle,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    Iconsax.arrow_right_3,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onTap: () => _showAboutDialog(context, isDarkMode, colors),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoSection(DeviceSnapshot deviceData, bool isDarkMode, ColorScheme colors, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.connectedDeviceTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isDarkMode ? Colors.grey[800] : colors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: deviceData.isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        deviceData.metadata?.deviceName ?? l10n.lotusFarmDefaultName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : colors.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: deviceData.isOnline 
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        deviceData.isOnline ? l10n.onlineBadge : l10n.offlineBadge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: deviceData.isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDeviceDetailRow(l10n.firmwareOnlyLabel, deviceData.metadata?.firmware ?? l10n.unknownLabel, isDarkMode),
                const SizedBox(height: 8),
                _buildDeviceDetailRow(l10n.deviceIdLabel, deviceData.deviceId, isDarkMode),
                const SizedBox(height: 8),
                _buildDeviceDetailRow(l10n.controlModeLabel,
                  deviceData.state.controlMode == 'automatic' ? l10n.autoBadge : l10n.manualBadge, isDarkMode),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceDetailRow(String label, String value, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          // Forced LTR — see _statCard's comment in device_dashboard_screen.dart.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(bool isDarkMode, ColorScheme colors) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[800] : colors.surface,
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorCard(Object error, bool isDarkMode, ColorScheme colors, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[800] : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Iconsax.wifi_square, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              l10n.deviceDisconnectedTitle,
              style: TextStyle(
                color: isDarkMode ? Colors.white : colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.unableToConnectDeviceMsg,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, bool isDarkMode, ColorScheme colors) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[800] : colors.surface,
        title: Text(l10n.aboutDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.versionLabel('1.0.0')),
            const SizedBox(height: 8),
            Text(l10n.builtWithFlutterFirebase),
            const SizedBox(height: 8),
            Text(l10n.esp32IntegrationDesc),
            const SizedBox(height: 16),
            Text(l10n.copyrightLine('2024')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.closeBtn),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdSettings(
    BuildContext context, 
    DeviceSnapshot deviceData,
    DeviceRepository repo,
    bool isDarkMode, 
    ColorScheme colors,
  ) {
    // Get current thresholds from device metadata, or use defaults
    final thresholds = deviceData.metadata?.thresholds ?? SensorThresholds(
      temperatureHigh: SensorThresholds.defaultTempHigh,
      temperatureLow: SensorThresholds.defaultTempLow,
      humidityHigh: SensorThresholds.defaultHumidityHigh,
      humidityLow: SensorThresholds.defaultHumidityLow,
      gasHigh: SensorThresholds.defaultGasHigh,
      hysteresis: SensorThresholds.defaultHysteresis,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[800] : colors.surface,
      child: Column(
        children: [
          _buildManualSetupTab(
            context,
            thresholds,
            repo,
            isDarkMode,
            colors,
          ),
          Divider(height: 1, color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
          _buildQuickPresetsTab(
            context,
            thresholds,
            repo,
            isDarkMode,
            colors,
          ),
        ],
      ),
    );
  }

  Widget _buildManualSetupTab(
    BuildContext context,
    SensorThresholds thresholds,
    DeviceRepository repo,
    bool isDarkMode,
    ColorScheme colors,
  ) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.manualSetupTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          // Validation status
          if (thresholds.validate() != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _describeThresholdValidationError(l10n, thresholds.validate()!),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.red.shade200 : Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
          // Hysteresis info banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade50, Colors.blue.shade50],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.hysteresisLabel(thresholds.hysteresis.toStringAsFixed(1)),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.purple.shade200 : Colors.purple.shade900,
                        ),
                      ),
                      Text(
                        l10n.hysteresisDesc,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Reset to Defaults Button
          OutlinedButton.icon(
            onPressed: () async {
              // Show confirmation dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.resetToDefaultsDialogTitle),
                  content: Text(l10n.resetToDefaultsDialogBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancelBtnGeneric),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.resetBtn),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                try {
                  await repo.updateThresholds(
                    temperatureHigh: SensorThresholds.defaultTempHigh,
                    temperatureLow: SensorThresholds.defaultTempLow,
                    humidityHigh: SensorThresholds.defaultHumidityHigh,
                    humidityLow: SensorThresholds.defaultHumidityLow,
                    gasHigh: SensorThresholds.defaultGasHigh,
                    hysteresis: SensorThresholds.defaultHysteresis,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.thresholdsResetSuccessMsg),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.errorResettingThresholds('$e')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.resetToDefaultsBtnLong),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(
                color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                width: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Temperature Stepper Input
          ThresholdStepperInput(
            label: l10n.temperatureRangeLabel,
            icon: Icons.thermostat,
            iconColor: Colors.orange,
            unit: '°C',
            minValue: thresholds.temperatureLow,
            maxValue: thresholds.temperatureHigh,
            absoluteMin: SensorThresholds.tempMin,
            absoluteMax: SensorThresholds.tempMax,
            step: 0.5,
            onChanged: (low, high) async {
              try {
                await repo.updateThresholds(
                  temperatureHigh: high,
                  temperatureLow: low,
                  humidityHigh: thresholds.humidityHigh,
                  humidityLow: thresholds.humidityLow,
                  gasHigh: thresholds.gasHigh,
                  hysteresis: thresholds.hysteresis,
                );
                return true;
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.genericErrorMsg('$e')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return false;
              }
            },
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),
          
          // Humidity Stepper Input
          ThresholdStepperInput(
            label: l10n.humidityRangeLabel,
            icon: Icons.water_drop,
            iconColor: Colors.blue,
            unit: '%',
            minValue: thresholds.humidityLow,
            maxValue: thresholds.humidityHigh,
            absoluteMin: SensorThresholds.humidityMin,
            absoluteMax: SensorThresholds.humidityMax,
            step: 1.0,
            onChanged: (low, high) async {
              try {
                await repo.updateThresholds(
                  temperatureHigh: thresholds.temperatureHigh,
                  temperatureLow: thresholds.temperatureLow,
                  humidityHigh: high,
                  humidityLow: low,
                  gasHigh: thresholds.gasHigh,
                  hysteresis: thresholds.hysteresis,
                );
                return true;
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.genericErrorMsg('$e')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return false;
              }
            },
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),
          
          // Gas Threshold (Single Value)
          // Gas threshold control (only max value - min is always 0 for gas detection)
          ThresholdStepperInput(
            label: l10n.gasLevelAlertLabel,
            icon: Iconsax.wind,
            iconColor: Colors.red,
            unit: 'ppm',
            minValue: 0.0,
            maxValue: thresholds.gasHigh,
            absoluteMin: 0.0,
            absoluteMax: SensorThresholds.gasMax,
            step: 5.0,
            onChanged: (min, max) async {
              try {
                await repo.updateThresholds(
                  temperatureHigh: thresholds.temperatureHigh,
                  temperatureLow: thresholds.temperatureLow,
                  humidityHigh: thresholds.humidityHigh,
                  humidityLow: thresholds.humidityLow,
                  gasHigh: max, // Only use max value for gas
                  hysteresis: thresholds.hysteresis,
                );
                return true;
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.genericErrorMsg('$e')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return false;
              }
            },
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetsTab(
    BuildContext context,
    SensorThresholds thresholds,
    DeviceRepository repo,
    bool isDarkMode,
    ColorScheme colors,
  ) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.quickPresetsTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          // Info Banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.green.shade50],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.presetSelectHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Temperature Preset Selector
          PresetThresholdSelector(
            key: ValueKey('temp_${thresholds.temperatureLow}_${thresholds.temperatureHigh}'),
            label: l10n.temperatureLabel,
            icon: Icons.thermostat,
            iconColor: Colors.orange,
            unit: '°C',
            minValue: thresholds.temperatureLow,
            maxValue: thresholds.temperatureHigh,
            presets: PoultryPresets.temperature,
            onChanged: (min, max) async {
              try {
                await repo.updateThresholds(
                  temperatureHigh: max,
                  temperatureLow: min,
                  humidityHigh: thresholds.humidityHigh,
                  humidityLow: thresholds.humidityLow,
                  gasHigh: thresholds.gasHigh,
                  hysteresis: thresholds.hysteresis,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.temperaturePresetAppliedMsg),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.genericErrorMsg('$e')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),

          // Humidity Preset Selector
          PresetThresholdSelector(
            key: ValueKey('humidity_${thresholds.humidityLow}_${thresholds.humidityHigh}'),
            label: l10n.humidityLabel,
            icon: Icons.water_drop,
            iconColor: Colors.blue,
            unit: '%',
            minValue: thresholds.humidityLow,
            maxValue: thresholds.humidityHigh,
            presets: PoultryPresets.humidity,
            onChanged: (min, max) async {
              try {
                await repo.updateThresholds(
                  temperatureHigh: thresholds.temperatureHigh,
                  temperatureLow: thresholds.temperatureLow,
                  humidityHigh: max,
                  humidityLow: min,
                  gasHigh: thresholds.gasHigh,
                  hysteresis: thresholds.hysteresis,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.humidityPresetAppliedMsg),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.genericErrorMsg('$e')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 24),

          // Reset to Defaults Button
          Center(
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await repo.updateThresholds(
                    temperatureHigh: SensorThresholds.defaultTempHigh,
                    temperatureLow: SensorThresholds.defaultTempLow,
                    humidityHigh: SensorThresholds.defaultHumidityHigh,
                    humidityLow: SensorThresholds.defaultHumidityLow,
                    gasHigh: SensorThresholds.defaultGasHigh,
                    hysteresis: SensorThresholds.defaultHysteresis,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.thresholdsResetToDefaultsMsg),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.genericErrorMsg('$e')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.resetToDefaultsBtnShort),
            ),
          ),
        ],
      ),
    );
  }

  void _showFanCycleDialog(
    BuildContext context,
    DeviceRepository repo,
    DeviceSnapshot? deviceData,
    bool isDarkMode,
    ColorScheme colors,
  ) {
    final l10n = AppLocalizations.of(context);
    final current = deviceData?.fanCycle ?? FanCycleConfig.defaults;
    bool enabled = current.enabled;

    // User types a plain number and picks its unit (min/hour) rather than
    // choosing from a fixed preset list (2026-08-30, user request) — the
    // firmware just stores whole seconds, so any positive duration is a
    // valid schedule, not only the presets that used to be offered.
    final onDecomposed = _decomposeSeconds(current.onSec);
    final offDecomposed = _decomposeSeconds(current.offSec);
    String onUnit = onDecomposed.unit;
    String offUnit = offDecomposed.unit;
    final onController = TextEditingController(text: onDecomposed.amount.toString());
    final offController = TextEditingController(text: offDecomposed.amount.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : colors.surface,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.repeat, color: Colors.teal, size: 20),
              ),
              const SizedBox(width: 12),
              Text(l10n.fanCycleTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.fanCycleEnabledLabel,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : colors.onSurface,
                    fontSize: 14,
                  ),
                ),
                value: enabled,
                activeColor: colors.primary,
                onChanged: (value) => setState(() => enabled = value),
              ),
              if (enabled) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.fanCycleOnDurationLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                _buildDurationInput(
                  controller: onController,
                  unit: onUnit,
                  onUnitChanged: (u) => setState(() => onUnit = u),
                  isDarkMode: isDarkMode,
                  colors: colors,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.fanCycleOffDurationLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                _buildDurationInput(
                  controller: offController,
                  unit: offUnit,
                  onUnitChanged: (u) => setState(() => offUnit = u),
                  isDarkMode: isDarkMode,
                  colors: colors,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.fanCycleActiveBanner,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? Colors.amber.shade200 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancelBtnGeneric),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final onAmount = int.tryParse(onController.text) ?? 0;
                  final offAmount = int.tryParse(offController.text) ?? 0;
                  if (enabled && (onAmount < 1 || offAmount < 1)) {
                    throw Exception('Duration must be at least 1 minute');
                  }
                  await repo.updateFanCycle(FanCycleConfig(
                    enabled: enabled,
                    onSec: _toSeconds(onAmount, onUnit),
                    offSec: _toSeconds(offAmount, offUnit),
                  ));
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.genericErrorMsg('$e')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(l10n.saveBtn),
            ),
          ],
        ),
      ),
    ).then((_) {
      onController.dispose();
      offController.dispose();
    });
  }

  // Amount + unit input for a fan-cycle duration — replaces the old fixed
  // preset dropdown (2026-08-30, user request) so the user can type any
  // duration directly instead of picking from a preset list.
  static Widget _buildDurationInput({
    required TextEditingController controller,
    required String unit,
    required ValueChanged<String> onUnitChanged,
    required bool isDarkMode,
    required ColorScheme colors,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            style: TextStyle(color: isDarkMode ? Colors.white : colors.onSurface),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'min', label: Text('min')),
            ButtonSegment(value: 'hour', label: Text('hr')),
          ],
          selected: {unit},
          onSelectionChanged: (selection) => onUnitChanged(selection.first),
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            selectedBackgroundColor: colors.primary.withValues(alpha: 0.15),
            selectedForegroundColor: colors.primary,
          ),
        ),
      ],
    );
  }

  // Splits a stored second-count back into an {amount, unit} pair for the
  // input fields above — whole hours display as hours, everything else
  // (including odd values written directly via Firebase) displays in
  // minutes, rounded to the nearest whole minute.
  static ({int amount, String unit}) _decomposeSeconds(int totalSec) {
    if (totalSec > 0 && totalSec % 3600 == 0) {
      return (amount: totalSec ~/ 3600, unit: 'hour');
    }
    return (amount: (totalSec / 60).round(), unit: 'min');
  }

  static int _toSeconds(int amount, String unit) =>
      amount * (unit == 'hour' ? 3600 : 60);

  static String _formatDuration(int seconds) {
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final hours = seconds / 3600;
    return hours == hours.roundToDouble()
        ? '${hours.round()}h'
        : '${hours.toStringAsFixed(1)}h';
  }

}

/// SensorThresholds.validate() has no BuildContext to localize with, so it
/// returns a ThresholdValidationError key — this maps that key to text in
/// whichever locale is active.
String _describeThresholdValidationError(AppLocalizations l10n, ThresholdValidationError error) {
  switch (error) {
    case ThresholdValidationError.tempLowGteHigh:
      return l10n.tempLowGteHighError;
    case ThresholdValidationError.tempRangeTooNarrow:
      return l10n.tempRangeTooNarrowError;
    case ThresholdValidationError.tempOutOfRange:
      return l10n.tempOutOfRangeError(
        SensorThresholds.tempMin.toStringAsFixed(0),
        SensorThresholds.tempMax.toStringAsFixed(0),
      );
    case ThresholdValidationError.humidityLowGteHigh:
      return l10n.humidityLowGteHighError;
    case ThresholdValidationError.humidityRangeTooNarrow:
      return l10n.humidityRangeTooNarrowError;
    case ThresholdValidationError.humidityOutOfRange:
      return l10n.humidityOutOfRangeError(
        SensorThresholds.humidityMin.toStringAsFixed(0),
        SensorThresholds.humidityMax.toStringAsFixed(0),
      );
    case ThresholdValidationError.gasOutOfRange:
      return l10n.gasOutOfRangeError(SensorThresholds.gasMax.toStringAsFixed(0));
    case ThresholdValidationError.hysteresisOutOfRange:
      return l10n.hysteresisOutOfRangeError;
  }
}
