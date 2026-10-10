/*
 * secrets.example.h - Template for secrets.h
 *
 * Copy this file to secrets.h (same folder) and fill in the real values.
 * secrets.h is gitignored so credentials never reach the repository.
 *
 *   cp secrets.example.h secrets.h
 *
 * Every macro below is required by config.h. Leave the OneSignal pair as
 * empty strings if you don't want push notifications — the firmware
 * detects that and skips them.
 */

#ifndef SECRETS_H
#define SECRETS_H

// ---- WiFi fallback credentials ----
// Compiled-in fallback only. The device is normally provisioned in the
// field through its setup portal (AP "PoultryFarm_Setup"); credentials
// saved there override these. Must be a 2.4 GHz network — the ESP32 has
// no 5 GHz radio. Plain WPA2-PSK/AES networks are the most reliable.
#define WIFI_SSID       "YOUR_WIFI_SSID"
#define WIFI_PASS       "YOUR_WIFI_PASSWORD"

// ---- Firebase ----
// Realtime Database secret, or an ID token if you move to rule-based auth.
// Firebase console: Project settings > Service accounts > Database secrets.
// Sent as ?auth=<token> on every REST/stream request.
#define FIREBASE_TOKEN  "YOUR_FIREBASE_DATABASE_SECRET"

// ---- OneSignal (push notifications) ----
// OneSignal dashboard: Settings > Keys & IDs. The App ID must match the
// one compiled into the Flutter app (push_notification_service.dart).
#define ONESIGNAL_APP_ID        ""
#define ONESIGNAL_REST_API_KEY  ""

#endif
