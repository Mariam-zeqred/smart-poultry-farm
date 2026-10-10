/*
 * config_loader.cpp - SPIFFS CSV parser + NVS Preferences overlay
 *
 * Loads data/config.csv from SPIFFS (key,value CSV),
 * then overlays with credentials saved by the provisioning portal.
 */

#include "config_loader.h"
#include "config.h"
#include <SPIFFS.h>
#include <Preferences.h>

// Fill cfg with hardcoded defaults first
static void setDefaults(AppConfig *cfg) {
    strncpy(cfg->wifiSsid,     WIFI_SSID,      sizeof(cfg->wifiSsid));
    strncpy(cfg->wifiPass,     WIFI_PASS,       sizeof(cfg->wifiPass));
    strncpy(cfg->firebaseUrl,  FIREBASE_URL,    sizeof(cfg->firebaseUrl));
    strncpy(cfg->firebasePath, FIREBASE_PATH,   sizeof(cfg->firebasePath));
    strncpy(cfg->firebaseToken,FIREBASE_TOKEN,  sizeof(cfg->firebaseToken));
    strncpy(cfg->deviceId,     DEVICE_ID,       sizeof(cfg->deviceId));
    strncpy(cfg->userId,       USER_ID,         sizeof(cfg->userId));
    strncpy(cfg->apSsid,       AP_SSID,         sizeof(cfg->apSsid));
    strncpy(cfg->apPass,       AP_PASS,         sizeof(cfg->apPass));
    cfg->httpPort    = AP_PORT;
    cfg->autoControl = true;
    cfg->forceApMode = false;
}

// Parse one CSV line: KEY,VALUE
static void parseLine(const String &line, AppConfig *cfg) {
    int comma = line.indexOf(',');
    if (comma < 0) return;

    String key = line.substring(0, comma);
    String val = line.substring(comma + 1);
    key.trim(); val.trim();

    if      (key == "DATABASE_URL")   val.toCharArray(cfg->firebaseUrl,  sizeof(cfg->firebaseUrl));
    else if (key == "PATH")           val.toCharArray(cfg->firebasePath, sizeof(cfg->firebasePath));
    else if (key == "AUTH_TOKEN" && val != "NULL")
                                      val.toCharArray(cfg->firebaseToken,sizeof(cfg->firebaseToken));
    else if (key == "AP_SSID")        val.toCharArray(cfg->apSsid,      sizeof(cfg->apSsid));
    else if (key == "AP_PASS")        val.toCharArray(cfg->apPass,      sizeof(cfg->apPass));
    else if (key == "HTTP_PORT")      cfg->httpPort = val.toInt();
    else if (key == "DEVICE_ID")      val.toCharArray(cfg->deviceId,    sizeof(cfg->deviceId));
    else if (key == "USER_ID")        val.toCharArray(cfg->userId,      sizeof(cfg->userId));
}

bool config_load(AppConfig *cfg) {
    // 1. Start with compiled-in defaults
    setDefaults(cfg);

    // 2. Try SPIFFS config.csv
    if (SPIFFS.begin(true)) {
        File f = SPIFFS.open("/config.csv", "r");
        if (f) {
            Serial.println("[CFG] Loading /config.csv from SPIFFS");
            while (f.available()) {
                String line = f.readStringUntil('\n');
                line.trim();
                if (line.length() > 0 && line[0] != '#') {
                    parseLine(line, cfg);
                }
            }
            f.close();
        } else {
            Serial.println("[CFG] No config.csv in SPIFFS, using defaults");
        }
    } else {
        Serial.println("[CFG] SPIFFS mount failed, using defaults");
    }

    // 3. Overlay with NVS credentials (provisioning portal saves here)
    Preferences prefs;

    // Not read-only: the "force_ap" flag below is a one-shot signal set by
    // a long SELECT hold (see ui_manager.cpp / onUiApReset() in the main
    // sketch) and must be consumed (removed) here so it doesn't keep
    // forcing AP mode on every subsequent boot after the user reprovisions.
    prefs.begin("wifi_creds", false);
    if (prefs.isKey("ssid")) {
        prefs.getString("ssid", cfg->wifiSsid, sizeof(cfg->wifiSsid));
        prefs.getString("pass", cfg->wifiPass, sizeof(cfg->wifiPass));
        Serial.println("[CFG] WiFi credentials loaded from NVS");
    }
    if (prefs.isKey("force_ap") && prefs.getBool("force_ap", false)) {
        cfg->forceApMode = true;
        prefs.remove("force_ap");
        Serial.println("[CFG] Force-AP-mode flag consumed (long SELECT hold) -> skipping WiFi, going straight to setup portal");
    }
    prefs.end();

    prefs.begin("device_cfg", true);  // read-only
    if (prefs.isKey("fb_url"))  prefs.getString("fb_url",  cfg->firebaseUrl, sizeof(cfg->firebaseUrl));
    if (prefs.isKey("dev_id"))  prefs.getString("dev_id",  cfg->deviceId,    sizeof(cfg->deviceId));
    if (prefs.isKey("user_id")) prefs.getString("user_id", cfg->userId,      sizeof(cfg->userId));
    prefs.end();

    Serial.printf("[CFG] Final: SSID=%s  Firebase=%s  Device=%s\n",
                  cfg->wifiSsid, cfg->firebaseUrl, cfg->deviceId);

    return true;
}
