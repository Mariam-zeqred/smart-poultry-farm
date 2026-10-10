/// "Devices" screen: shows the one controller (name, online state, firmware,
/// IP for the OTA page) and the entry point to WiFi provisioning.
///
/// The app is single-device by design, so this is a status card and a
/// "set up WiFi" button rather than a real multi-device list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/device_provider.dart';
import '../../provisioning/screens/provision_screen.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider);
    final colors = Theme.of(context).colorScheme;
    final deviceAsync = ref.watch(deviceProvider);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : colors.surface,
      body: deviceAsync.when(
        data: (deviceData) => _buildDevicesList([deviceData], isDarkMode, colors),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildNoDeviceState(isDarkMode, colors),
      ),
    );
  }

  Widget _buildNoDeviceState(bool isDarkMode, ColorScheme colors) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Device Icon with Gradient Background
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF47A2C6), Color(0xFF63B897)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF47A2C6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Iconsax.devices,
                size: 60,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Title
            Text(
              l10n.noDeviceConnectedTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : colors.onSurface,
              ),
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              l10n.noDeviceConnectedBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Add Device Button with Gradient
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 300),
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF47A2C6), Color(0xFF63B897)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF47A2C6).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RealProvisionScreen(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Iconsax.add_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.addNewDeviceBtn,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Help Text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.info_circle,
                  size: 16,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.wifiSetupHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Features Preview
            _buildFeatureList(isDarkMode, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList(bool isDarkMode, ColorScheme colors) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.whatYouCanDoTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Iconsax.chart,
            title: l10n.featureMonitoringTitle,
            description: l10n.featureMonitoringDesc,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: Iconsax.setting_2,
            title: l10n.featureAutoControlTitle,
            description: l10n.featureAutoControlDesc,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: Iconsax.notification,
            title: l10n.featureAlertsTitle,
            description: l10n.featureAlertsDesc,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDarkMode,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF47A2C6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF47A2C6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesList(List<DeviceSnapshot> devices, bool isDarkMode, ColorScheme colors) {
    return RefreshIndicator(
      onRefresh: () async {
        final _ = ref.refresh(deviceProvider);
        // Wait a bit for the refresh to complete
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: devices.length + 1, // +1 for the Add Device button
        itemBuilder: (context, index) {
          // Show Add Device button at the top
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildAddDeviceButton(isDarkMode, colors),
            );
          }
          
          // Show device cards
          final device = devices[index - 1];
          return _buildEnhancedDeviceCard(device, isDarkMode, colors);
        },
      ),
    );
  }

  Widget _buildAddDeviceButton(bool isDarkMode, ColorScheme colors) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF47A2C6), Color(0xFF63B897)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF47A2C6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RealProvisionScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.add_circle,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.addNewDeviceBtn,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.connectAnotherControllerSubtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedDeviceCard(DeviceSnapshot device, bool isDarkMode, ColorScheme colors) {
    final l10n = AppLocalizations.of(context);
    final lastSeenText = _formatLastSeen(device.metadata?.lastSeen ?? 0);

    return Card(
      color: isDarkMode ? Colors.grey[800] : colors.surface,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Device Status Indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: device.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Device Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.metadata?.deviceName ?? l10n.lotusFarmDefaultName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.firmwareLabel(device.metadata?.firmware ?? l10n.unknownLabel),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: device.isOnline 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    device.isOnline ? l10n.onlineBadge : l10n.offlineBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: device.isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Options Menu
                IconButton(
                  icon: Icon(
                    Iconsax.more,
                    color: isDarkMode ? Colors.white70 : colors.onSurface.withOpacity(0.7),
                  ),
                  onPressed: () => _showDeviceOptions(device),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Device Metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricChip(
                    icon: Icons.thermostat,
                    label: l10n.temperatureLabel,
                    value: '${device.latest.temperature.toStringAsFixed(1)}°C',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricChip(
                    icon: Icons.water_drop,
                    label: l10n.humidityLabel,
                    value: '${device.latest.humidity.toStringAsFixed(0)}%',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricChip(
                    icon: Iconsax.wind,
                    label: l10n.airQualityLabel,
                    value: '${device.latest.gas.toStringAsFixed(1)} ppm',
                    color: device.latest.gas > 5 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Last Seen & Control Mode
            Row(
              children: [
                Icon(
                  Iconsax.clock,
                  size: 14,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  lastSeenText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (device.state.controlMode != null) ...[
                  Icon(
                    device.state.controlMode == 'automatic' ? Iconsax.autobrightness : Iconsax.setting_2,
                    size: 14,
                    color: device.state.controlMode == 'automatic' ? Colors.blue : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    device.state.controlMode == 'automatic' ? l10n.autoBadge : l10n.manualBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: device.state.controlMode == 'automatic' ? Colors.blue : Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          // Forced LTR: mixes digits with a unit word (e.g. "0.0 ppm") —
          // see the matching comment in device_dashboard_screen.dart's
          // _statCard for why this needs an explicit override under RTL.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(int timestamp) {
    final l10n = AppLocalizations.of(context);
    if (timestamp == 0) return l10n.unknownLabel;

    final now = DateTime.now();
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return l10n.justNowSentence;
    } else if (difference.inMinutes < 60) {
      return l10n.shortMinutesAgo('${difference.inMinutes}');
    } else if (difference.inHours < 24) {
      return l10n.shortHoursAgo('${difference.inHours}');
    } else {
      return l10n.shortDaysAgo('${difference.inDays}');
    }
  }

  void _showDeviceOptions(DeviceSnapshot device) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(
            device.metadata?.deviceName ?? l10n.deviceOptionsDefaultTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Iconsax.eye),
            title: Text(l10n.viewDetailsOption),
            onTap: () {
              Navigator.pop(context);
              _showDeviceDetails(device);
            },
          ),
          ListTile(
            leading: const Icon(Iconsax.edit),
            title: Text(l10n.editDeviceOption),
            onTap: () {
              Navigator.pop(context);
              _editDevice(device);
            },
          ),
          ListTile(
            leading: Icon(Iconsax.refresh, color: Colors.blue),
            title: Text(l10n.refreshDataOption, style: TextStyle(color: Colors.blue)),
            onTap: () {
              Navigator.pop(context);
              final _ = ref.refresh(deviceProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.refreshingDeviceData)),
              );
            },
          ),
          if (!device.isOnline) ...[
            ListTile(
              leading: Icon(Iconsax.warning_2, color: Colors.orange),
              title: Text(l10n.troubleshootOption, style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(context);
                _showTroubleshootDialog(device);
              },
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showDeviceDetails(DeviceSnapshot device) {
    final isDarkMode = ref.read(themeProvider);
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[800] : colors.surface,
        title: Text(
          l10n.deviceDetailsTitle,
          style: TextStyle(color: isDarkMode ? Colors.white : colors.onSurface),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(l10n.nameLabel, device.metadata?.deviceName ?? l10n.unknownLabel),
              _buildDetailRow(l10n.firmwareOnlyLabel, device.metadata?.firmware ?? l10n.unknownLabel),
              _buildDetailRow(l10n.statusLabel, device.isOnline ? l10n.statusOnlineValue : l10n.statusOfflineValue),
              _buildDetailRow(l10n.lastSeenLabel, _formatLastSeen(device.metadata?.lastSeen ?? 0)),
              _buildDetailRow(l10n.deviceIdLabel, device.deviceId),
              const SizedBox(height: 16),
              Text(
                l10n.currentReadingsTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(l10n.temperatureLabel, '${device.latest.temperature.toStringAsFixed(1)}°C'),
              _buildDetailRow(l10n.humidityLabel, '${device.latest.humidity.toStringAsFixed(1)}%'),
              _buildDetailRow(l10n.airQualityLabel, '${device.latest.gas.toStringAsFixed(1)} ppm'),
              const SizedBox(height: 16),
              Text(
                l10n.controlSettingsColonTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(l10n.controlModeLabel, device.state.controlMode == 'automatic' ? l10n.autoBadge : l10n.manualBadge),
              _buildDetailRow(l10n.fanLabel, device.state.fanState ? l10n.stateOn : l10n.stateOff),
              _buildDetailRow(l10n.coolerLabel, device.state.coolerState ? l10n.stateOn : l10n.stateOff),
              _buildDetailRow(l10n.heaterTitle, device.state.heaterState ? l10n.stateOn : l10n.stateOff),
              _buildDetailRow(l10n.humidifierTitle, device.state.humidifierState ? l10n.stateOn : l10n.stateOff),
            ],
          ),
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

  Widget _buildDetailRow(String label, String value) {
    final isDarkMode = ref.read(themeProvider);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            // Forced LTR: most values here are numeric+unit (temperature,
            // humidity, timestamps) — see _statCard's comment for why RTL
            // needs this override. Harmless for the plain-word values
            // (Online/ON/device name) mixed into the same shared row.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                value,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTroubleshootDialog(DeviceSnapshot device) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deviceTroubleshootingTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deviceAppearsOfflineMsg(device.metadata?.deviceName ?? l10n.unknownLabel)),
            const SizedBox(height: 16),
            Text(l10n.troubleshootingStepsTitle),
            const SizedBox(height: 8),
            Text(l10n.stepCheckPower),
            Text(l10n.stepVerifyWifi),
            Text(l10n.stepRestartDevice),
            Text(l10n.stepCheckFirebase),
            const SizedBox(height: 16),
            Text(
              l10n.lastSeenColonLabel(_formatLastSeen(device.metadata?.lastSeen ?? 0)),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.closeBtn),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final _ = ref.refresh(deviceProvider);
            },
            child: Text(l10n.retryConnectionBtn),
          ),
        ],
      ),
    );
  }

  void _editDevice(DeviceSnapshot device) {
    // Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).editDeviceComingSoon)),
    );
  }
}