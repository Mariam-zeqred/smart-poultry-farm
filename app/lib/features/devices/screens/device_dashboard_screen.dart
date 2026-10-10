/// Main screen and bottom-navigation host. Tabs: My Farm (this file),
/// AI Monitor ([VisionScreen]) and Settings ([SettingsScreen]).
///
/// The My Farm tab shows live temperature/humidity/gas cards, the four
/// actuator toggles (Ventilation, Cooling, Heater, Humidifier), the
/// Auto/Manual switch, the App Control ownership toggle, and the safety /
/// auto-control status banners. The app-bar bell ([NotificationBadgeIcon])
/// opens the alerts list.
///
/// Every control is greyed out under the same rules the firmware applies
/// (safety > app control > auto > fan cycle > manual) so the UI never offers
/// an action the device would reject.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/device_provider.dart';
import '../../../core/models/sensor_model.dart';
import '../../../core/models/device_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notification_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../vision/providers/vision_repository.dart';
import '../../vision/screens/vision_screen.dart';
import 'devices_screen.dart';
import 'settings_screen.dart';

class DeviceDashboardScreen extends ConsumerStatefulWidget {
  const DeviceDashboardScreen({super.key});

  @override
  ConsumerState<DeviceDashboardScreen> createState() =>
      _DeviceDashboardScreenState();
}

class _DeviceDashboardScreenState
    extends ConsumerState<DeviceDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = [
    const DashboardContent(),
    const DevicesScreen(),
    const VisionScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider);
    final colors = Theme.of(context).colorScheme;

    // This screen is only ever built once AppStartup's Firebase-init gate
    // has resolved (it's AppStartup's `data` child), so it's the right
    // place to start the vision evaluator — watching it any earlier (e.g.
    // directly in App.build()) hits FirebaseDatabase before
    // Firebase.initializeApp() has run.
    ref.watch(visionEvaluatorProvider);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : colors.surface,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDarkMode ? Colors.grey[900] : colors.surface,
        elevation: 0,
        iconTheme:
            IconThemeData(color: isDarkMode ? Colors.white : colors.onSurface),
        actions: const [NotificationBadgeIcon()],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: isDarkMode ? Colors.grey[900] : colors.surface,
          selectedItemColor: colors.primary,
          unselectedItemColor:
              isDarkMode ? Colors.grey[400] : Colors.grey[600],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.home),
              label: AppLocalizations.of(context).navDashboard,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.cpu),
              label: AppLocalizations.of(context).navDevices,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.eye),
              label: AppLocalizations.of(context).visionTabLabel,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.setting),
              label: AppLocalizations.of(context).navSettings,
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    final l10n = AppLocalizations.of(context);
    switch (_selectedIndex) {
      case 0:
        return 'Lotus Power';
      case 1:
        return l10n.dashMyFarmTitle;
      case 2:
        return l10n.visionTabLabel;
      case 3:
        return l10n.navSettings;
      default:
        return 'Lotus Power';
    }
  }
}

class DashboardContent extends ConsumerStatefulWidget {
  const DashboardContent({super.key});

  @override
  ConsumerState<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<DashboardContent> {
  // Note: Removed local _isAutomaticMode state - now using Firebase directly

  // Optimistic UI state for control switches
  bool? _optimisticFanState;
  bool? _optimisticCoolerState;
  bool? _optimisticHeaterState;
  bool? _optimisticHumidifierState;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider);
    final deviceAsync = ref.watch(deviceProvider);

    return deviceAsync.when(
      data: (data) {
        // watchDevice() already verified the device has connected
        // (lastSeen > 0 or sensorTs > 0). Metadata may arrive a few ms
        // after sensors, so don't gate on it here.
        final hasConnected = (data.metadata?.lastSeen ?? 0) > 0 || data.latest.ts > 0;

        if (!hasConnected) {
          return _buildNoDeviceConnected(context, isDarkMode);
        }

        final repo = ref.read(deviceRepoProvider);
        return _buildDashboard(data, repo, context, isDarkMode);
      },
      loading: () => _buildLoadingState(),
      error: (_, __) => _buildNoDeviceConnected(context, isDarkMode),
    );
  }

  Widget _buildNoDeviceConnected(BuildContext context, bool isDarkMode) {
    final l10n = AppLocalizations.of(context);
    // Create empty sensor data (all zeros)
    final emptySensors = SensorLatest(
      temperature: 0.0,
      humidity: 0.0,
      gas: 0.0,
      ts: 0,
    );
    
    // Create empty control state (all off)
    final emptyControls = ControlState(
      fanState: false,
      coolerState: false,
      heaterState: false,
      humidifierState: false,
      controlMode: 'manual',
      reason: null,
    );
    
    // Create empty metadata
    final emptyMetadata = DeviceMetadata(
      deviceName: 'Farm Controller',
      firmware: '---',
      status: 'offline',
      owner: 'unknown',
      lastSeen: 0,
      startupTime: 0,
    );
    
    return CustomScrollView(
      slivers: [
        // Header with "No Device Connected" message
        SliverToBoxAdapter(
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade400,
                  Colors.grey.shade500,
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 20,
                  top: 20,
                  child: Icon(
                    Iconsax.cpu,
                    size: 80,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Iconsax.close_circle,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.noDeviceConnectedTitle,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.noDeviceConnectedSubtitle,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.waitingForDeviceLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Main Content with disabled state
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Quick Stats Cards (showing zeros)
                _buildQuickStats(emptySensors, emptyMetadata, context),
                const SizedBox(height: 24),

                // Control Section (all disabled)
                _buildDisabledControlSection(emptyControls, context),
                const SizedBox(height: 24),

                // Info Card
                _buildConnectDeviceInfoCard(context, isDarkMode),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectDeviceInfoCard(BuildContext context, bool isDarkMode) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Iconsax.info_circle,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.connectYourDeviceTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.connectYourDeviceBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Switch to devices tab (index 1)
                if (context.findAncestorStateOfType<_DeviceDashboardScreenState>() != null) {
                  context.findAncestorStateOfType<_DeviceDashboardScreenState>()!._onItemTapped(1);
                }
              },
              icon: const Icon(Iconsax.add_circle),
              label: Text(l10n.goToDevicesBtn),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledControlSection(ControlState controls, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.farmControlTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.disabledBadge,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Disabled message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.controlsDisabledMsg,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Disabled Grid Layout for Controls
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: [
                _buildModernControlCard(
                  context: context,
                  icon: Iconsax.wind,
                  title: l10n.ventilationTitle,
                  subtitle: l10n.fanControlSubtitle,
                  value: l10n.stateOff,
                  color: Colors.grey,
                  isActive: false,
                  enabled: false,
                  isReadOnly: true,
                ),
                _buildModernControlCard(
                  context: context,
                  icon: Icons.ac_unit,
                  title: l10n.coolingTitle,
                  subtitle: l10n.coolerControlSubtitle,
                  value: l10n.stateOff,
                  color: Colors.grey,
                  isActive: false,
                  enabled: false,
                  isReadOnly: true,
                ),
                _buildModernControlCard(
                  context: context,
                  icon: Icons.local_fire_department,
                  title: l10n.heaterTitle,
                  subtitle: l10n.heatingControlSubtitle,
                  value: l10n.stateOff,
                  color: Colors.grey,
                  isActive: false,
                  enabled: false,
                  isReadOnly: true,
                ),
                _buildModernControlCard(
                  context: context,
                  icon: Icons.water_drop,
                  title: l10n.humidifierTitle,
                  subtitle: l10n.humidifierControlSubtitle,
                  value: l10n.stateOff,
                  color: Colors.grey,
                  isActive: false,
                  enabled: false,
                  isReadOnly: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(DeviceSnapshot data, DeviceRepository repo, BuildContext context, bool isDarkMode) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      slivers: [
        // Modern Header Design
        SliverToBoxAdapter(
          child: Container(
            height: 200, // Reduced height after removing automatic control
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.9),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Stack(
              children: [
                // Background decorative elements
                Positioned(
                  right: 20,
                  top: 20,
                  child: Icon(
                    Iconsax.cpu,
                    size: 80,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                Positioned(
                  left: 30,
                  bottom: 30,
                  child: Icon(
                    Iconsax.activity,
                    size: 60,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/LP.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Lotus Power",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.realtimeMonitoringSubtitle,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status and quick stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _headerStatusBadge(context, data.latest, data.metadata),
                          _headerStatItem(
                            icon: Iconsax.clock,
                            value: _formatTime(data.latest.ts),
                            label: l10n.lastUpdateLabel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Main Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Quick Stats Cards
                _buildQuickStats(data.latest, data.metadata, context),
                const SizedBox(height: 24),

                // Control Section
                _buildControlSection(data.state, data.fanCycle, repo, context),
                const SizedBox(height: 24),

                // Recent Activity
                _buildRecentActivity(data.latest, data.state, data.metadata, context),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerStatusBadge(BuildContext context, SensorLatest sensors, DeviceMetadata? metadata) {
    final status = _getHealthStatus(context, sensors, metadata);
    final color = _getHealthColor(sensors, metadata);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStatItem({required IconData icon, required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(SensorLatest sensors, DeviceMetadata? metadata, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Use dynamic thresholds if available, otherwise use defaults
    final thresholds = metadata?.thresholds ?? SensorThresholds(
      temperatureHigh: SensorThresholds.defaultTempHigh,
      temperatureLow: SensorThresholds.defaultTempLow,
      humidityHigh: SensorThresholds.defaultHumidityHigh,
      humidityLow: SensorThresholds.defaultHumidityLow,
      gasHigh: SensorThresholds.defaultGasHigh,
    );

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _statCard(
          context: context,
          icon: Icons.thermostat,
          title: l10n.temperatureLabel,
          value: "${sensors.temperature.toStringAsFixed(1)}°C",
          unit: l10n.idealTempRange(thresholds.temperatureLow.toStringAsFixed(0), thresholds.temperatureHigh.toStringAsFixed(0)),
          color: Colors.orange,
          trend: sensors.temperature > thresholds.temperatureHigh ? Iconsax.arrow_up : Iconsax.arrow_down,
        ),
        _statCard(
          context: context,
          icon: Icons.water_drop,
          title: l10n.humidityLabel,
          value: "${sensors.humidity.toStringAsFixed(0)}%",
          unit: l10n.idealHumidityRange(thresholds.humidityLow.toStringAsFixed(0), thresholds.humidityHigh.toStringAsFixed(0)),
          color: Colors.blue,
          trend: sensors.humidity > thresholds.humidityHigh ? Iconsax.arrow_up : Iconsax.arrow_down,
        ),
        _statCard(
          context: context,
          icon: Iconsax.wind,
          title: l10n.airQualityLabel,
          value: "${sensors.gas.toStringAsFixed(1)} ppm",
          unit: l10n.goodGasRange(thresholds.gasHigh.toStringAsFixed(0)),
          color: sensors.gas > thresholds.gasHigh ? Colors.red : Colors.green,
          trend: sensors.gas > thresholds.gasHigh ? Iconsax.arrow_up : Iconsax.arrow_down,
        ),
        _statCard(
          context: context,
          icon: Iconsax.health,
          title: l10n.overallLabel,
          value: _getHealthStatus(context, sensors, metadata),
          unit: l10n.farmConditionLabel,
          color: _getHealthColor(sensors, metadata),
          trend: Iconsax.activity,
        ),
      ],
    );
  }

  Widget _buildControlSection(ControlState controls, FanCycleConfig fanCycle, DeviceRepository repo, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Get control mode from Firebase state, not local widget state
    final isAutomaticMode = controls.controlMode == 'automatic';

    return Container(
      margin: const EdgeInsets.all(12), // Reduced margin
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Prevent overflow
          children: [
            // Header with mode indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.farmControlTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAutomaticMode
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAutomaticMode ? Colors.green : Colors.blue,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAutomaticMode ? Icons.smart_toy : Icons.touch_app,
                        size: 14,
                        color: isAutomaticMode ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAutomaticMode ? l10n.autoBadge : l10n.manualBadge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isAutomaticMode ? Colors.green : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // Reduced spacing

            // App Control toggle moved to the Settings screen (2026-08-30,
            // user request) — see SettingsScreen's "Device Control" section.
            // Farm Controls Mode Toggle — greyed out below alongside the
            // description text whenever the LCD currently owns control.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.farmControlModeLabel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          !controls.appControlEnabled
                            ? l10n.appControlDisabledDesc
                            : (isAutomaticMode
                                ? l10n.autoControlSystemDesc
                                : l10n.manualControlDesc),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: isAutomaticMode,
                    onChanged: (controls.safetyOverride == true || !controls.appControlEnabled)
                      ? null  // Disable toggle during safety override or while the LCD owns control
                      : (value) {
                        // Update Firebase directly, no setState needed
                        repo.setControlMode(value ? 'automatic' : 'manual');
                      },
                    activeColor: Colors.green,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Auto-Control Status Banner (shows when auto-control is active with reason).
            // No more "manual priority paused" banner — Auto and Manual are
            // mutually exclusive now (see isActuatorLocked()-equivalent
            // `enabled:` gating on the control cards below), so there's
            // never a "temporarily paused for a manual override" state to
            // show anymore.
            if (isAutomaticMode && controls.reason != null && controls.reason!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.green.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.smart_toy, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.autoControlActiveTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            controls.reason!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            
            // Safety Override Warning Banner
            if (controls.safetyOverride == true)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.safetyOverrideActiveTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controls.reason ?? l10n.safetyOverrideDefaultReason,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Fan Cycle Active Banner (only when safety isn't already showing)
            if (controls.safetyOverride != true && fanCycle.enabled)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.repeat, color: Colors.teal.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.fanCycleActiveBanner,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Modern Grid Layout for Controls
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82, // Taller cards to prevent text overlap
              children: [
                // Fan Control Card (locked while Auto is selected or a
                // scheduled cycle owns it — see isAutomaticMode above)
                _buildModernControlCard(
                  context: context,
                  icon: Iconsax.wind,
                  title: l10n.ventilationTitle,
                  subtitle: fanCycle.enabled ? l10n.fanCycleTitle : l10n.fanControlSubtitle,
                  value: (_optimisticFanState ?? controls.fanState) ? l10n.stateOn : l10n.stateOff,
                  color: Colors.blue,
                  isActive: _optimisticFanState ?? controls.fanState,
                  enabled: controls.safetyOverride != true && controls.appControlEnabled && !isAutomaticMode && !fanCycle.enabled,
                  safetyOverride: controls.safetyOverride == true,
                  lockedByAppControl: controls.safetyOverride != true && !controls.appControlEnabled,
                  child: (controls.safetyOverride != true && controls.appControlEnabled && !isAutomaticMode && !fanCycle.enabled) ? _buildControlSwitch(
                    _optimisticFanState ?? controls.fanState,
                    (value) {
                      setState(() => _optimisticFanState = value);
                      repo.setFanState(value).then((_) {
                        Future.delayed(const Duration(seconds: 8), () {
                          if (mounted) setState(() => _optimisticFanState = null);
                        });
                      }).catchError((e) {
                        if (mounted) setState(() => _optimisticFanState = null);
                      });
                    },
                    Colors.blue
                  ) : null,
                ),

                // Cooler Control Card
                _buildModernControlCard(
                  context: context,
                  icon: Icons.ac_unit,
                  title: l10n.coolingTitle,
                  subtitle: l10n.coolerControlSubtitle,
                  value: (_optimisticCoolerState ?? controls.coolerState) ? l10n.stateOn : l10n.stateOff,
                  color: Colors.cyan,
                  isActive: _optimisticCoolerState ?? controls.coolerState,
                  enabled: controls.safetyOverride != true && controls.appControlEnabled && !isAutomaticMode,
                  safetyOverride: controls.safetyOverride == true,
                  lockedByAppControl: controls.safetyOverride != true && !controls.appControlEnabled,
                  child: (controls.safetyOverride != true && controls.appControlEnabled && !isAutomaticMode) ? _buildControlSwitch(
                    _optimisticCoolerState ?? controls.coolerState,
                    (value) {
                      setState(() => _optimisticCoolerState = value);
                      repo.setCoolerState(value).then((_) {
                        Future.delayed(const Duration(seconds: 8), () {
                          if (mounted) setState(() => _optimisticCoolerState = null);
                        });
                      }).catchError((e) {
                        if (mounted) setState(() => _optimisticCoolerState = null);
                      });
                    },
                    Colors.cyan
                  ) : null,
                ),
                
                // Heater Control Card
                _buildModernControlCard(
                  context: context,
                  icon: Icons.local_fire_department,
                  title: l10n.heaterTitle,
                  subtitle: l10n.heatingControlSubtitle,
                  value: (_optimisticHeaterState ?? controls.heaterState) ? l10n.stateOn : l10n.stateOff,
                  color: Colors.orange,
                  isActive: _optimisticHeaterState ?? controls.heaterState,
                  enabled: controls.safetyOverride != true && controls.appControlEnabled && !isAutomaticMode,
                  safetyOverride: controls.safetyOverride == true,
                  lockedByAppControl: controls.safetyOverride != true && !controls.appControlEnabled,
                  child: (controls.safetyOverride != true && controls.appControlEnabled && !isAutomaticMode) ? _buildControlSwitch(
                    _optimisticHeaterState ?? controls.heaterState, 
                    (value) {
                      setState(() => _optimisticHeaterState = value);
                      repo.setHeaterState(value).then((_) {
                        Future.delayed(const Duration(seconds: 8), () {
                          if (mounted) setState(() => _optimisticHeaterState = null);
                        });
                      }).catchError((e) {
                        if (mounted) setState(() => _optimisticHeaterState = null);
                      });
                    }, 
                    Colors.orange
                  ) : null,
                ),
                
                // Humidifier Control Card (locked while Auto is selected or safety override is active)
                _buildModernControlCard(
                  context: context,
                  icon: Icons.water_drop,
                  title: l10n.humidifierTitle,
                  subtitle: l10n.humidifierControlSubtitle,
                  value: (_optimisticHumidifierState ?? controls.humidifierState) ? l10n.stateOn : l10n.stateOff,
                  color: Colors.green,
                  isActive: _optimisticHumidifierState ?? controls.humidifierState,
                  enabled: controls.safetyOverride != true && controls.appControlEnabled && !isAutomaticMode,
                  safetyOverride: controls.safetyOverride == true,
                  lockedByAppControl: controls.safetyOverride != true && !controls.appControlEnabled,
                  child: (controls.safetyOverride != true && controls.appControlEnabled && !isAutomaticMode) ? _buildControlSwitch(
                    _optimisticHumidifierState ?? controls.humidifierState,
                    (value) {
                      setState(() => _optimisticHumidifierState = value);
                      repo.setHumidifierState(value).then((_) {
                        Future.delayed(const Duration(seconds: 8), () {
                          if (mounted) setState(() => _optimisticHumidifierState = null);
                        });
                      }).catchError((e) {
                        if (mounted) setState(() => _optimisticHumidifierState = null);
                      });
                    },
                    Colors.green
                  ) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(SensorLatest sensors, ControlState controls, DeviceMetadata? metadata, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Use dynamic thresholds if available, otherwise use defaults
    final thresholds = metadata?.thresholds ?? SensorThresholds(
      temperatureHigh: SensorThresholds.defaultTempHigh,
      temperatureLow: SensorThresholds.defaultTempLow,
      humidityHigh: SensorThresholds.defaultHumidityHigh,
      humidityLow: SensorThresholds.defaultHumidityLow,
      gasHigh: SensorThresholds.defaultGasHigh,
    );
    
    final activities = [
      {
        'icon': Icons.thermostat,
        'title': l10n.temperatureReadingLabel,
        'value': '${sensors.temperature.toStringAsFixed(1)}°C',
        'time': _formatTime(sensors.ts),
        'status': sensors.temperature > thresholds.temperatureHigh ? 'warning' : 'normal',
      },
      {
        'icon': Iconsax.wind,
        'title': l10n.fanStatusLabel,
        'value': controls.fanState ? l10n.stateOn : l10n.stateOff,
        'time': _formatTime(sensors.ts),
        'status': controls.fanState ? 'normal' : 'warning',
      },
      {
        'icon': Icons.ac_unit,
        'title': l10n.coolerStatusLabel,
        'value': controls.coolerState ? l10n.stateOn : l10n.stateOff,
        'time': _formatTime(sensors.ts),
        'status': controls.coolerState ? 'normal' : 'warning',
      },
      {
        'icon': Icons.local_fire_department,
        'title': l10n.heaterStatusLabel,
        'value': controls.heaterState ? l10n.stateOn : l10n.stateOff,
        'time': _formatTime(sensors.ts),
        'status': controls.heaterState ? 'normal' : 'warning',
      },
    ];


    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recentActivityTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...activities.map((activity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activity['status'] == 'warning' 
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activity['icon'] as IconData,
                      color: activity['status'] == 'warning' ? Colors.orange : Colors.green,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'] as String,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          activity['value'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    activity['time'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    required IconData trend,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(trend, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            // Forced LTR: "value"/"unit" mix digits with a unit word (e.g.
            // "0.0 ppm", "Ideal: 18-24°C"). Confirmed on a real RTL device
            // that Flutter/ICU doesn't isolate these automatically — bidi
            // visually reorders "0.0 ppm" to "ppm 0.0" and "18-24" to
            // "24-18" inside an RTL ancestor even though the data is
            // correct. Pure-Arabic values (e.g. the Overall card's health
            // status word) render fine under forced LTR too since a
            // same-direction run isn't reordered.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                unit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context).loadingFarmData, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  String _getHealthStatus(BuildContext context, SensorLatest sensors, DeviceMetadata? metadata) {
    final l10n = AppLocalizations.of(context);
    // Use dynamic thresholds if available, otherwise use defaults
    final thresholds = metadata?.thresholds ?? SensorThresholds(
      temperatureHigh: SensorThresholds.defaultTempHigh,
      temperatureLow: SensorThresholds.defaultTempLow,
      humidityHigh: SensorThresholds.defaultHumidityHigh,
      humidityLow: SensorThresholds.defaultHumidityLow,
      gasHigh: SensorThresholds.defaultGasHigh,
    );

    // Get status for each sensor
    final tempStatus = thresholds.getTemperatureStatus(sensors.temperature);
    final humidityStatus = thresholds.getHumidityStatus(sensors.humidity);
    final gasStatus = thresholds.getGasStatus(sensors.gas);

    // Critical: Any sensor in critical state
    if (tempStatus.isCritical || humidityStatus.isCritical || gasStatus.isCritical) {
      return l10n.healthCritical;
    }

    // Warning: Any sensor needs action
    if (tempStatus.needsAction || humidityStatus.needsAction || gasStatus.needsAction) {
      return l10n.healthWarning;
    }

    return l10n.healthExcellent;
  }

  Color _getHealthColor(SensorLatest sensors, DeviceMetadata? metadata) {
    // Use dynamic thresholds if available, otherwise use defaults
    final thresholds = metadata?.thresholds ?? SensorThresholds(
      temperatureHigh: SensorThresholds.defaultTempHigh,
      temperatureLow: SensorThresholds.defaultTempLow,
      humidityHigh: SensorThresholds.defaultHumidityHigh,
      humidityLow: SensorThresholds.defaultHumidityLow,
      gasHigh: SensorThresholds.defaultGasHigh,
    );
    
    // Get status for each sensor
    final tempStatus = thresholds.getTemperatureStatus(sensors.temperature);
    final humidityStatus = thresholds.getHumidityStatus(sensors.humidity);
    final gasStatus = thresholds.getGasStatus(sensors.gas);
    
    // Critical: Any sensor in critical state
    if (tempStatus.isCritical || humidityStatus.isCritical || gasStatus.isCritical) {
      return Colors.red;
    }
    
    // Warning: Any sensor needs action
    if (tempStatus.needsAction || humidityStatus.needsAction || gasStatus.needsAction) {
      return Colors.orange;
    }
    
    return Colors.green;
  }

  String _formatTime(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  // Modern control card widget
  Widget _buildModernControlCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color color,
    required bool isActive,
    required bool enabled,
    Widget? child,
    bool isReadOnly = false,
    bool safetyOverride = false, // NEW: Indicate if disabled due to safety override
    bool lockedByAppControl = false, // Disabled because the LCD owns control (2026-08-29)
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive 
          ? color.withValues(alpha: 0.1) 
          : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: safetyOverride 
            ? Colors.red  // Red border for safety override
            : (isActive ? color : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
          width: safetyOverride ? 3 : 2, // Thicker border for safety override
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6), // Reduced padding
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18), // Reduced icon size
                ),
                const Spacer(),
                if (!isReadOnly && !enabled)
                  Tooltip(
                    message: safetyOverride
                      ? AppLocalizations.of(context).lockedSafetyOverrideTooltip
                      : lockedByAppControl
                        ? AppLocalizations.of(context).lockedAppControlTooltip
                        : AppLocalizations.of(context).lockedAutomaticModeTooltip,
                    child: Icon(
                      safetyOverride ? Icons.warning : Icons.lock,
                      size: 16,
                      color: safetyOverride ? Colors.red : Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8), // Reduced spacing
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2), // Reduced spacing
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            const SizedBox(height: 4), // Reduced spacing
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isActive ? color : Theme.of(context).textTheme.labelLarge?.color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (child != null) ...[
              const SizedBox(height: 4), // Reduced spacing
              Align(
                alignment: Alignment.centerRight,
                child: child,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Control switch widget (unified for all ON/OFF controls)
  Widget _buildControlSwitch(bool currentState, Function(bool) onChanged, Color activeColor) {
    return SizedBox(
      height: 30, // Fixed height to prevent overflow
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Switch.adaptive(
            value: currentState,
            onChanged: onChanged,
            activeColor: activeColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

