/*
 * onesignal_client.cpp - Push notifications via OneSignal's REST API
 *
 * Sends a push directly from the ESP32 to OneSignal (api.onesignal.com)
 * whenever a safety alert fires — deliberately NOT routed through a
 * Firebase Cloud Function, since Cloud Functions require the Firebase
 * project to be on the paid Blaze plan just to deploy at all, regardless
 * of what the function does. OneSignal's own backend fans the push out to
 * every phone that has the app installed with notifications enabled; this
 * device never needs to know which phones exist or track their tokens —
 * that bookkeeping lives entirely on OneSignal's side now.
 *
 * Uses its own short-lived WiFiClientSecure per call rather than a
 * persistent one like firebase_client.cpp — different host, and alerts are
 * infrequent (capped by ALERT_COOLDOWN in the main sketch), so there's
 * nothing worth optimizing here.
 */

#include "onesignal_client.h"
#include "config.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>

bool onesignal_sendAlert(const char *title, const char *message) {
    if (strlen(ONESIGNAL_APP_ID) == 0 || strlen(ONESIGNAL_REST_API_KEY) == 0) {
        return false;  // not configured — silently skip, not a fatal error
    }

    WiFiClientSecure client;
    // TODO: replace with setCACert in production (same tradeoff already
    // accepted for firebase_client.cpp/firebase_stream.cpp — see their
    // own TODOs).
    client.setInsecure();

    HTTPClient http;
    http.setTimeout(8000);
    if (!http.begin(client, "https://api.onesignal.com/notifications")) {
        Serial.println("[ONESIGNAL] begin() failed");
        return false;
    }
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Authorization", String("Key ") + ONESIGNAL_REST_API_KEY);

    JsonDocument doc;
    doc["app_id"]              = ONESIGNAL_APP_ID;
    doc["target_channel"]      = "push";
    doc["included_segments"][0] = "Subscribed Users";
    doc["headings"]["en"]      = title;
    doc["contents"]["en"]      = message;
    // OneSignal's documented default priority on Android is NORMAL, which
    // lets FCM delay or batch delivery. A gas trip is exactly the payload
    // that must not be batched, so ask for high priority explicitly.
    doc["priority"]            = 10;
    // Post to the app's OWN notification channel rather than OneSignal's
    // default "Miscellaneous" one. That default is created with PRIVATE
    // lockscreen visibility, so on any phone with "hide sensitive
    // notification content" enabled the alert text is hidden on the lock
    // screen — the app name shows and nothing else. On Android 8+ the
    // channel's visibility governs and CANNOT be overridden from this
    // payload, so the fix has to live in the channel: see
    // createAlertNotificationChannel() in MainActivity.kt, which declares it
    // PUBLIC + IMPORTANCE_HIGH.
    //
    // Deliberately NOT paired with an "android_visibility" field: that
    // already defaults to 1 (Public) and is ignored once a channel applies,
    // so setting it would just be misleading noise.
    doc["existing_android_channel_id"] = ONESIGNAL_ANDROID_CHANNEL_ID;

    String json;
    serializeJson(doc, json);

    int code = http.POST(json);
    bool success = (code >= 200 && code < 300);
    Serial.printf("[ONESIGNAL] POST notifications -> %d %s\n", code,
                  success ? "OK" : "FAIL");
    if (!success) {
        // Response body carries the actual error reason (bad app_id, bad
        // key, no subscribed devices yet, etc.) — worth logging for
        // debugging a misconfigured App ID/REST key.
        Serial.println(http.getString());
    }

    http.end();
    return success;
}
