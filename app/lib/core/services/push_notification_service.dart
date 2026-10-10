import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Push notifications for farm alerts (gas/temp/humidity safety trips,
/// vision alerts) — real OS-level notifications that show on the lock
/// screen even if the app is fully closed, not just the in-app bell badge.
///
/// Uses OneSignal instead of talking to Firebase Cloud Messaging directly:
/// the ESP32 firmware itself POSTs to OneSignal's REST API the moment it
/// writes a new alert (see onesignal_client.cpp in the firmware) — no
/// Firebase Cloud Function needed, which meant no Blaze (paid) plan
/// requirement, and this app never needs to track/sync device tokens
/// through Firebase either. OneSignal's own SDK/backend handles device
/// registration entirely on its own — this class's only job is to
/// initialize the SDK and ask for notification permission.
class PushNotificationService {
  PushNotificationService._();

  /// From the OneSignal dashboard: Settings > Keys & IDs > OneSignal App ID.
  static const String _appId = 'b3786860-2aa1-4e45-b007-a4ccae02acbb';

  /// Call once during app startup, after Firebase.initializeApp(). Safe to
  /// call even if the user denies permission — the rest of the app is
  /// unaffected either way.
  static Future<void> initialize() async {
    OneSignal.initialize(_appId);
    await OneSignal.Notifications.requestPermission(false);
  }
}
