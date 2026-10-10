/// WiFi provisioning wizard: walks the user through joining the controller's
/// setup hotspot ("PoultryFarm_Setup"), entering the farm WiFi credentials,
/// and posting them to the device's captive portal (wifi_provision.cpp).
///
/// All user-visible messages are localisation keys resolved here — the
/// provider layer emits [ProvisionMessageKey]s, never English strings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/provision_provider.dart';

String _localizedProvisionMessage(AppLocalizations l10n, ProvisionMessageKey? key, String? param) {
  switch (key) {
    case ProvisionMessageKey.checkingPermissions:
      return l10n.provisionCheckingPermissions;
    case ProvisionMessageKey.sendingCredentials:
      return l10n.provisionSendingCredentials;
    case ProvisionMessageKey.success:
      return l10n.provisionSuccessMsg;
    case ProvisionMessageKey.authRequired:
      return l10n.provisionAuthRequired;
    case ProvisionMessageKey.deviceRestartedLikelySuccess:
      return l10n.provisionDeviceRestartedLikelySuccess;
    case ProvisionMessageKey.timedOutLikelySuccess:
      return l10n.provisionTimedOutLikelySuccess;
    case ProvisionMessageKey.cannotConnect:
      return l10n.provisionCannotConnect;
    case ProvisionMessageKey.authFailedReLogin:
      return l10n.provisionAuthFailedReLogin;
    case ProvisionMessageKey.deviceRejectedData:
      return l10n.provisionDeviceRejectedData;
    case ProvisionMessageKey.deviceInternalError:
      return l10n.provisionDeviceInternalError;
    case ProvisionMessageKey.deviceRejectedCredentials:
      return l10n.provisionDeviceRejectedCredentials;
    case ProvisionMessageKey.locationPermissionRequired:
      return l10n.provisionLocationPermissionRequired;
    case ProvisionMessageKey.permissionsRequired:
      return l10n.provisionPermissionsRequired;
    case ProvisionMessageKey.genericSetupError:
      return l10n.provisionGenericSetupError(param ?? '');
    case null:
      return '';
  }
}

class RealProvisionScreen extends ConsumerStatefulWidget {
  const RealProvisionScreen({super.key});

  @override
  ConsumerState<RealProvisionScreen> createState() => _RealProvisionScreenState();
}

class _RealProvisionScreenState extends ConsumerState<RealProvisionScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _provisionDevice() async {
    if (!mounted) return;
    
    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pleaseEnterWifiCreds),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final provisionNotifier = ref.read(provisioningControllerProvider.notifier);
      await provisionNotifier.sendCredentials(
        homeSsid: _ssidController.text,
        homePassword: _passwordController.text,
      );
    } catch (e, stackTrace) {
      print('🔴 Error provisioning device: $e');
      print('Stack trace: $stackTrace');
      // Error handled by provider state, but log for debugging
    }
  }

  @override
  Widget build(BuildContext context) {
    final provisionState = ref.watch(provisioningControllerProvider);
    final isDarkMode = ref.watch(themeProvider);
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceSetupTitle),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: isDarkMode ? Colors.grey[900] : colors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Icon
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.wifi,
                      size: 40,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.deviceWifiSetupTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.configureDeviceWifiSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Setup Instructions
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.info_circle, color: colors.primary, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          l10n.beforeYouStartTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionStep(
                      number: 1,
                      title: l10n.stepConnectDeviceWifiTitle,
                      description: l10n.stepConnectDeviceWifiDesc,
                    ),
                    _buildInstructionStep(
                      number: 2,
                      title: l10n.stepEnterCredsTitle,
                      description: l10n.stepEnterCredsDesc,
                    ),
                    _buildInstructionStep(
                      number: 3,
                      title: l10n.stepSendConfigTitle,
                      description: l10n.stepSendConfigDesc,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // WiFi Credentials Form
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.wifiCredentialsTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ssidController,
                      decoration: InputDecoration(
                        labelText: l10n.networkNameLabel,
                        hintText: l10n.networkNameHint,
                        prefixIcon: Icon(Iconsax.wifi, color: colors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[700] : Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        hintText: l10n.passwordHint,
                        prefixIcon: Icon(Iconsax.lock, color: colors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[700] : Colors.grey[100],
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                            color: colors.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isButtonDisabled(provisionState.state) ? null : _provisionDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isButtonDisabled(provisionState.state)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.sendCredentialsBtn,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            // Status Display
            if (provisionState.messageKey != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(provisionState.state, colors),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusBorderColor(provisionState.state, colors),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(provisionState.state),
                      color: _getStatusIconColor(provisionState.state, colors),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _localizedProvisionMessage(l10n, provisionState.messageKey, provisionState.messageParam),
                        style: TextStyle(
                          color: _getStatusTextColor(provisionState.state, colors),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Retry Button for Errors
            if (provisionState.state == ProvisionState.error) ...[
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(provisioningControllerProvider.notifier).reset();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.tryAgainBtn),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep({required int number, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isButtonDisabled(ProvisionState state) {
    return state == ProvisionState.sendingCredentials ||
            state == ProvisionState.requestingPermission;
  }

  Color _getStatusColor(ProvisionState state, ColorScheme colors) {
    switch (state) {
      case ProvisionState.error:
        return colors.error.withOpacity(0.1);
      case ProvisionState.done:
        return colors.primary.withOpacity(0.1);
      default:
        return colors.primary.withOpacity(0.05);
    }
  }

  Color _getStatusBorderColor(ProvisionState state, ColorScheme colors) {
    switch (state) {
      case ProvisionState.error:
        return colors.error;
      case ProvisionState.done:
        return colors.primary;
      default:
        return colors.primary.withOpacity(0.3);
    }
  }

  Color _getStatusTextColor(ProvisionState state, ColorScheme colors) {
    switch (state) {
      case ProvisionState.error:
        return colors.error;
      case ProvisionState.done:
        return colors.primary;
      default:
        return colors.onSurface;
    }
  }

  Color _getStatusIconColor(ProvisionState state, ColorScheme colors) {
    return _getStatusTextColor(state, colors);
  }

  IconData _getStatusIcon(ProvisionState state) {
    switch (state) {
      case ProvisionState.error:
        return Icons.error_outline;
      case ProvisionState.done:
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }
}