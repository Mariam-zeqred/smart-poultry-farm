import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/services/db_seeder.dart';

enum ProvisionState {
  idle,
  requestingPermission,
  sendingCredentials,
  done,
  error,
}

/// A StateNotifier has no BuildContext, so it can't call
/// AppLocalizations.of(context) directly. It emits a semantic key (+ an
/// optional raw param for the one message that embeds a caught exception's
/// text) instead of a baked English string; provision_screen.dart maps the
/// key to the localized string at render time.
enum ProvisionMessageKey {
  checkingPermissions,
  sendingCredentials,
  success,
  authRequired,
  deviceRestartedLikelySuccess,
  timedOutLikelySuccess,
  cannotConnect,
  authFailedReLogin,
  deviceRejectedData,
  deviceInternalError,
  deviceRejectedCredentials,
  locationPermissionRequired,
  permissionsRequired,
  genericSetupError,
}

class ProvisionStatus {
  final ProvisionState state;
  final ProvisionMessageKey? messageKey;
  final String? messageParam;
  ProvisionStatus(this.state, {this.messageKey, this.messageParam});
}

final provisioningControllerProvider =
    StateNotifierProvider<ProvisioningController, ProvisionStatus>(
  (ref) => ProvisioningController(ref),
);

class ProvisioningController extends StateNotifier<ProvisionStatus> {
  ProvisioningController(Ref ref) : super(ProvisionStatus(ProvisionState.idle));

  /// Send WiFi credentials to ESP32 device
  Future<void> sendCredentials({
    required String homeSsid,
    required String homePassword,
    Duration httpTimeout = const Duration(seconds: 15),
  }) async {
    try {
      state = ProvisionStatus(ProvisionState.requestingPermission,
                messageKey: ProvisionMessageKey.checkingPermissions);

      // Request necessary permissions
      await _ensurePermissions();

      state = ProvisionStatus(ProvisionState.sendingCredentials,
                messageKey: ProvisionMessageKey.sendingCredentials);

      // POST credentials - this will throw exception on failure or return success
      await _sendCredentials(homeSsid, homePassword, httpTimeout);

      state = ProvisionStatus(ProvisionState.done,
                messageKey: ProvisionMessageKey.success);

    } catch (e) {
      final (key, param) = _friendlyErrorKey(e.toString());
      state = ProvisionStatus(ProvisionState.error,
                messageKey: key, messageParam: param);
      rethrow;
    }
  }

  Future<void> _sendCredentials(String ssid, String password, Duration timeout) async {
    try {
      // Hardcoded ESP32 AP IP for provisioning
      const esp32IP = '192.168.4.1';
      
      final uri = Uri.parse('http://$esp32IP/provision');
      
      // Arduino WebServer expects form-encoded fields: ssid, pass, fb_url, dev_id, user_id
      final requestData = {
        'ssid': ssid,
        'pass': password,
        'dev_id': 'esp32_device',
      };
      
      // Debug logging
      print('Sending provisioning request to $uri');
      
      try {
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Connection': 'close',
          },
          body: requestData,  // http package auto-encodes Map as form data
        ).timeout(timeout);

        print('Provisioning response: ${response.statusCode} - ${response.body}');

        // Check for success response
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('Provisioning HTTP success: ${response.statusCode}');
          print('Response body: ${response.body}');
          // Arduino returns HTML "Saved!" page on success, not JSON
          // Seed the Firebase database structure now that provisioning succeeded
          await _seedFirebaseAfterProvision();
          return; // Success
        }
        
        // Handle error responses
        print('Provisioning failed: ${response.statusCode} - ${response.body}');
        String errorMsg = 'Device rejected credentials';
        
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMsg = responseData['message'];
          }
        } catch (e) {
          // Use generic error if JSON parsing fails
        }
        
        throw Exception('$errorMsg (HTTP ${response.statusCode})');
        
      } on TimeoutException catch (e) {
        print('Timeout Exception: $e');
        throw Exception('Request timed out. The device may have restarted - check if it appears in your device list.');
        
      } on SocketException catch (e) {
        print('Socket Exception: ${e.message}');
        
        // Connection issues after sending data usually mean success (ESP32 restarted)
        if (e.message.contains('Connection reset') || 
            e.message.contains('Connection refused') ||
            e.message.contains('Connection aborted') ||
            e.message.contains('Software caused connection abort')) {
          
          print('Connection terminated after sending data - this usually indicates successful provisioning');
          // Seed Firebase structure since provisioning likely succeeded
          await _seedFirebaseAfterProvision();
          // Wait for ESP32 to restart
          await Future.delayed(Duration(seconds: 2));
          return; // Consider this success
        }
        
        // Other socket errors
        throw Exception('Network connection error: ${e.message}. Ensure you are connected to the device WiFi network.');
        
      } on http.ClientException catch (e) {
        print('HTTP Client Exception: ${e.message}');
        
        // Connection termination after sending data is expected when ESP32 restarts
        if (e.message.contains('Connection reset') || 
            e.message.contains('Connection refused') ||
            e.message.contains('Connection closed') ||
            e.message.contains('Connection aborted') ||
            e.message.contains('Software caused connection abort')) {
          
          print('HTTP connection terminated - likely successful provisioning');
          await _seedFirebaseAfterProvision();
          await Future.delayed(Duration(seconds: 2));
          return; // Consider this success
        }
        
        throw Exception('HTTP error: ${e.message}');
        
      } catch (e) {
        print('Unexpected exception: $e');
        
        // Check if it's a connection termination issue
        String errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('connection reset') || 
            errorMsg.contains('connection refused') ||
            errorMsg.contains('connection closed') ||
            errorMsg.contains('connection aborted') ||
            errorMsg.contains('software caused connection abort')) {
          
          print('Unexpected connection termination - treating as successful provisioning');
          await _seedFirebaseAfterProvision();
          await Future.delayed(Duration(seconds: 2));
          return;
        }
        
        rethrow;
      }
    } catch (e) {
      // Re-throw with more context
      if (e.toString().contains('User not authenticated')) {
        rethrow;
      }
      throw Exception('Failed to communicate with device: ${e.toString()}');
    }
  }

  Future<void> _ensurePermissions() async {
    if (Platform.isAndroid) {
      // Check Android version
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      // Location permission is required for WiFi operations on Android 10+
      if (sdkVersion >= 29) {
        final locationStatus = await Permission.locationWhenInUse.request();
        if (!locationStatus.isGranted) {
          throw Exception('Location permission is required to configure WiFi');
        }
      }

      // Nearby devices permission for Android 13+
      if (sdkVersion >= 33) {
        final nearbyStatus = await Permission.nearbyWifiDevices.request();
        if (!nearbyStatus.isGranted) {
          throw Exception('Nearby devices permission is required');
        }
      }

      // Additional WiFi permissions
      final wifiStatus = await Permission.location.request();
      if (!wifiStatus.isGranted) {
        throw Exception('WiFi access permission is required');
      }
    }
  }

  (ProvisionMessageKey, String?) _friendlyErrorKey(String error) {
    if (error.contains('User not authenticated')) {
      return (ProvisionMessageKey.authRequired, null);
    } else if (error.contains('Connection reset') ||
               error.contains('Connection closed') ||
               error.contains('Connection refused') ||
               error.contains('Connection aborted') ||
               error.contains('Software caused connection abort')) {
      return (ProvisionMessageKey.deviceRestartedLikelySuccess, null);
    } else if (error.contains('timed out') || error.contains('Timed out')) {
      return (ProvisionMessageKey.timedOutLikelySuccess, null);
    } else if (error.contains('Cannot connect to device') ||
               error.contains('Network connection error') ||
               error.contains('Connection error')) {
      return (ProvisionMessageKey.cannotConnect, null);
    } else if (error.contains('HTTP 401') || error.contains('HTTP 403')) {
      return (ProvisionMessageKey.authFailedReLogin, null);
    } else if (error.contains('HTTP 400')) {
      return (ProvisionMessageKey.deviceRejectedData, null);
    } else if (error.contains('HTTP 500')) {
      return (ProvisionMessageKey.deviceInternalError, null);
    } else if (error.contains('Device rejected credentials')) {
      return (ProvisionMessageKey.deviceRejectedCredentials, null);
    } else if (error.contains('Location permission')) {
      return (ProvisionMessageKey.locationPermissionRequired, null);
    } else if (error.contains('permission')) {
      return (ProvisionMessageKey.permissionsRequired, null);
    }
    return (
      ProvisionMessageKey.genericSetupError,
      error.length > 100 ? '${error.substring(0, 100)}...' : error,
    );
  }

  /// Seed the Firebase database structure after successful provisioning.
  /// This creates the device node so the app can start monitoring.
  Future<void> _seedFirebaseAfterProvision() async {
    try {
      print('🌱 Seeding Firebase after provisioning...');
      await DbSeeder.initializeFirebaseData();
      print('✅ Firebase seeded successfully');
    } catch (e) {
      print('⚠️ Failed to seed Firebase (non-fatal): $e');
    }
  }

    // Reset state to idle
    void reset() {
      state = ProvisionStatus(ProvisionState.idle);
    }
  }