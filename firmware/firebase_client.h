/*
 * firebase_client.h - Firebase Realtime Database REST client
 */

#ifndef FIREBASE_CLIENT_H
#define FIREBASE_CLIENT_H

#include <Arduino.h>
#include <ArduinoJson.h>

// Initialize Firebase with runtime config (call after WiFi connected)
bool firebase_init(const char *url, const char *path, const char *deviceId,
                    const char *userId, const char *token);

// Send sensor readings to sensors/latest
bool firebase_sendSensors(float temp, float hum, float gas);

// Read JSON from a subpath (e.g., "control/state")
bool firebase_read(const char *subPath, JsonDocument &doc);

// Write JSON to control/state
bool firebase_writeControl(JsonDocument &doc);

// Update device status (online/offline)
bool firebase_updateStatus(bool online);

// Send device metadata
bool firebase_sendMeta();

// Write thresholds to config/thresholds
bool firebase_writeThresholds(float tempHigh, float tempLow,
                               float humHigh, float humLow,
                               float gasHigh);

// Write fan cycle config to config/fanCycle
bool firebase_writeFanCycle(bool enabled, unsigned long onSec, unsigned long offSec);

// Generic PATCH to any sub-path (for reuse)
bool firebase_patch(const char *subPath, const char *json);

// millis() of the last Firebase request that came back 2xx, or 0 if the
// cloud has never been reached since boot. This is the REST half of the
// "is the cloud actually reachable" signal — WiFi association alone does
// NOT mean Firebase is reachable (router up / WAN down), so the firmware
// must not infer one from the other. See cloudReachable() in the .ino,
// which ORs this with firebase_stream_lastByteMs().
//
// Written on Core 0 (firebaseTask), read on Core 1 (loop/UI) — a plain
// unsynchronized read of an aligned 32-bit value. Deliberately takes NO
// mutex: Core 1 must never block behind an in-flight 5-second HTTPS
// request just to read a timestamp.
unsigned long firebase_lastSuccessMs();

// Send an alert
bool firebase_sendAlert(const char *type, const char *severity, const char *msg,
                         float value, float threshold);

#endif
