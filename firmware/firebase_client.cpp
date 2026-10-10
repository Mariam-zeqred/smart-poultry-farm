/*
 * firebase_client.cpp - Firebase RTDB via HTTPS REST API
 *
 * Uses a PERSISTENT TLS connection to avoid repeated handshakes (~1-3s each).
 * Connection is reused across requests via HTTP keep-alive.
 *
 * Required library: ArduinoJson (install via Library Manager)
 *
 * SECURITY NOTE: setInsecure() skips certificate verification and is
 * vulnerable to MITM attacks. Replace with setCACert(FIREBASE_ROOT_CA)
 * using the DigiCert Global Root G2 certificate before production use.
 */

#include "firebase_client.h"
#include "config.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <WiFi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

static String dbRootUrl;    // Database root (e.g., "https://xxx.firebaseio.com")
static String baseUrl;      // Full URL to device node
static String authToken;    // Auth token (runtime)
static String devId;        // Device ID (runtime)
static String ownerId;      // User ID (runtime)

// Last time any request came back 2xx (see firebase_lastSuccessMs()).
// volatile: written on Core 0, read on Core 1 without a lock.
static volatile unsigned long lastSuccessMs = 0;

// Serialize all Firebase HTTP operations across cores/tasks.
// Without this, concurrent HTTPClient/WiFiClientSecure use can corrupt heap.
static SemaphoreHandle_t firebaseMutex = nullptr;

static void ensureFirebaseMutex() {
    if (firebaseMutex == nullptr) {
        firebaseMutex = xSemaphoreCreateMutex();
    }
}

// ---- Persistent TLS connection ----
// Reusing this avoids a 1-3 second TLS handshake on every single request.
// First request does the handshake; subsequent ones reuse the session.
static WiFiClientSecure *sslClient = nullptr;

static void ensureClient() {
    if (!sslClient) {
        sslClient = new WiFiClientSecure();
        if (!sslClient) {
            Serial.println("[FB] FATAL: heap exhausted, cannot allocate WiFiClientSecure");
            return;
        }
        // TODO: replace with setCACert(FIREBASE_ROOT_CA) before production
        sslClient->setInsecure();
        Serial.println("[FB] New TLS session created");
    }
}

static void resetClient() {
    if (sslClient) {
        delete sslClient;
        sslClient = nullptr;
        Serial.println("[FB] TLS session reset");
    }
}

// Build relative URL: baseUrl + "/" + subPath + ".json" [+ ?auth=token]
static String buildUrl(const char *subPath) {
    String url = baseUrl + "/" + subPath + ".json";
    if (authToken.length() > 0) {
        url += "?auth=" + authToken;
    }
    return url;
}

// Core HTTP helper — used by all public API functions.
// Takes a FULL url (caller builds it via buildUrl or manually).
static bool firebaseRequestUrl(const char *method, const String &url,
                                const char *body, String *response) {
    ensureFirebaseMutex();
    if (firebaseMutex) xSemaphoreTake(firebaseMutex, portMAX_DELAY);

    ensureClient();
    if (!sslClient) {
        if (firebaseMutex) xSemaphoreGive(firebaseMutex);
        return false;
    }

    HTTPClient http;
    http.setReuse(true);
    http.setTimeout(5000);

    if (!http.begin(*sslClient, url)) {
        Serial.println("[FB] begin() failed");
        if (firebaseMutex) xSemaphoreGive(firebaseMutex);
        return false;
    }
    http.addHeader("Content-Type", "application/json");

    int code;
    if (strcmp(method, "GET") == 0)        code = http.GET();
    else if (strcmp(method, "PUT") == 0)   code = http.PUT(body ? body : "");
    else if (strcmp(method, "PATCH") == 0) code = http.PATCH(body ? body : "");
    else if (strcmp(method, "POST") == 0)  code = http.POST(body ? body : "");
    else if (strcmp(method, "DELETE") == 0) code = http.sendRequest("DELETE");
    else {
        http.end();
        if (firebaseMutex) xSemaphoreGive(firebaseMutex);
        return false;
    }

    bool success = (code >= 200 && code < 300);
    // Cloud-reachability heartbeat. Set on ANY 2xx — a successful GET
    // proves the round trip to Firebase just as well as a successful PUT.
    if (success) lastSuccessMs = millis();
    if (response) *response = http.getString();
    http.end();

    // Log every request's outcome — path only, NEVER the "?auth=" token —
    // so Serial Monitor gives a full, safe audit trail of cloud connectivity.
    {
        int qm = url.indexOf('?');
        String logUrl = (qm >= 0) ? url.substring(0, qm) : url;
        Serial.printf("[FB] %s %s -> %d %s\n", method, logUrl.c_str(), code,
                      success ? "OK" : "FAIL");
    }

    // Negative code = transport/connection error → reset for fresh TLS next time
    if (code < 0) {
        Serial.printf("[FB] Transport error %d, resetting TLS\n", code);
        resetClient();
    }

    if (firebaseMutex) xSemaphoreGive(firebaseMutex);
    return success;
}

// Convenience wrapper: builds URL from subPath then delegates to firebaseRequestUrl
static bool firebaseRequest(const char *method, const char *subPath,
                             const char *body, String *response) {
    return firebaseRequestUrl(method, buildUrl(subPath), body, response);
}

unsigned long firebase_lastSuccessMs() {
    return lastSuccessMs;
}

// ---- Public API ----

bool firebase_init(const char *url, const char *path, const char *deviceId,
                    const char *userId, const char *token) {
    ensureFirebaseMutex();
    dbRootUrl = String(url);
    // ALWAYS flat — never nest under deviceId. The app has always read the
    // flat farm/... root (see device_provider.dart's _farmPath) and this
    // schema is single-farm by design (there is only ever one device). A
    // previous version of this function nested everything under
    // farm/<deviceId>/... whenever the "Device ID" provisioning-form field
    // was non-empty, which silently broke the app's connectivity check
    // (farm/meta/lastSeen never got written, so the app showed "Offline"
    // even though the device was online and working) — invisible to anyone
    // who just typed something into that field without knowing it changed
    // the storage path. deviceId is kept only as a label (see devId below,
    // written into meta.deviceId / alert.deviceId), never as part of a URL.
    baseUrl   = String(url) + "/" + path;
    authToken = (token && strlen(token) > 0) ? String(token) : "";
    devId     = String(deviceId);
    ownerId   = String(userId);
    ensureClient();
    Serial.printf("[FB] Initialized: %s\n", baseUrl.c_str());
    return true;
}

bool firebase_sendSensors(float temp, float hum, float gas) {
    JsonDocument doc;
    doc["temperature"] = temp;
    doc["humidity"]    = hum;
    doc["gas"]         = gas;
    doc["ts"][".sv"]   = "timestamp";

    String json;
    serializeJson(doc, json);
    return firebaseRequest("PUT", "sensors/latest", json.c_str(), NULL);
}

bool firebase_read(const char *subPath, JsonDocument &doc) {
    String response;
    if (!firebaseRequest("GET", subPath, NULL, &response)) return false;
    if (response == "null" || response.length() < 2) return false;

    DeserializationError err = deserializeJson(doc, response);
    return (err == DeserializationError::Ok);
}

bool firebase_writeControl(JsonDocument &doc) {
    String json;
    serializeJson(doc, json);
    return firebaseRequest("PUT", "control/state", json.c_str(), NULL);
}

bool firebase_updateStatus(bool online) {
    JsonDocument doc;
    doc["online"]          = online;
    doc["lastSeen"][".sv"] = "timestamp";

    String json;
    serializeJson(doc, json);
    return firebaseRequest("PATCH", "meta", json.c_str(), NULL);
}

bool firebase_sendMeta() {
    // Identity fields the ESP owns and may overwrite freely on every boot.
    // User-mutable preferences (deviceName) are INTENTIONALLY OMITTED —
    // the app may have customized them and we must not clobber that on
    // power-cycle.
    JsonDocument doc;
    doc["firmware"]            = FIRMWARE_VERSION;
    // OTA-page discovery fallback for when mDNS (.local) doesn't resolve on
    // a given phone/browser — the IP changes across networks/reboots, this
    // field always reflects the current one.
    doc["localIp"]             = WiFi.localIP().toString();
    doc["status"]              = "online";
    doc["owner"]               = ownerId;
    doc["lastSeen"][".sv"]     = "timestamp";
    doc["startupTime"][".sv"]  = "timestamp";

    String json;
    serializeJson(doc, json);
    if (!firebaseRequest("PATCH", "meta", json.c_str(), NULL)) return false;

    // Seed defaults ONLY if the field doesn't already exist in the cloud.
    // Uses RTDB's PUT-if-empty-via-condition isn't a thing, so we read first.
    JsonDocument check;
    if (firebase_read("meta", check)) {
        JsonDocument seed;
        bool needSeed = false;
        if (!check.containsKey("deviceName")) {
            seed["deviceName"] = "Mr.Mahmoud_Device";
            needSeed = true;
        }
        if (needSeed) {
            String s;
            serializeJson(seed, s);
            firebaseRequest("PATCH", "meta", s.c_str(), NULL);
            Serial.println("[FB] Seeded missing meta defaults (first boot)");
        }
    }

    return true;
}

bool firebase_writeFanCycle(bool enabled, unsigned long onSec, unsigned long offSec) {
    JsonDocument doc;
    doc["enabled"] = enabled;
    doc["onSec"]   = onSec;
    doc["offSec"]  = offSec;

    String json;
    serializeJson(doc, json);
    return firebaseRequest("PUT", "config/fanCycle", json.c_str(), NULL);
}

bool firebase_patch(const char *subPath, const char *json) {
    return firebaseRequest("PATCH", subPath, json, NULL);
}

bool firebase_writeThresholds(float tempHigh, float tempLow,
                               float humHigh, float humLow,
                               float gasHigh) {
    JsonDocument doc;
    doc["temperatureHigh"] = tempHigh;
    doc["temperatureLow"]  = tempLow;
    doc["humidityHigh"]    = humHigh;
    doc["humidityLow"]     = humLow;
    doc["gasHigh"]         = gasHigh;

    String json;
    serializeJson(doc, json);
    return firebaseRequest("PUT", "config/thresholds", json.c_str(), NULL);
}

bool firebase_sendAlert(const char *type, const char *severity, const char *msg,
                         float value, float threshold) {
    JsonDocument doc;
    doc["type"]              = type;
    doc["severity"]          = severity;
    doc["message"]           = msg;
    doc["value"]             = value;
    doc["threshold"]         = threshold;
    doc["createdAt"][".sv"]  = "timestamp";
    doc["deviceId"]          = devId;

    String json;
    serializeJson(doc, json);

    // Alerts at farm/alerts — same farm node, consistent with app schema
    return firebaseRequest("POST", "alerts", json.c_str(), NULL);
}
