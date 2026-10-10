/*
 * config_loader.h - Load configuration from SPIFFS + NVS (Preferences)
 *
 * Priority: NVS overrides > SPIFFS config.csv > hardcoded defaults
 *
 * Upload config.csv to SPIFFS:
 *   Arduino IDE → Tools → ESP32 Sketch Data Upload
 *   (requires "ESP32 Sketch Data Upload" plugin)
 *   Place config.csv in a "data" folder next to the .ino
 */

#ifndef CONFIG_LOADER_H
#define CONFIG_LOADER_H

#include <Arduino.h>

struct AppConfig {
    char wifiSsid[32];
    char wifiPass[64];
    char firebaseUrl[128];
    char firebasePath[32];
    char firebaseToken[128];
    char deviceId[64];
    char userId[64];
    char apSsid[32];
    char apPass[32];
    int  httpPort;
    bool autoControl;
    bool forceApMode;  // one-shot: set when a long SELECT hold requested AP-mode reset
};

// Initialize SPIFFS, load config.csv, overlay NVS credentials
bool config_load(AppConfig *cfg);

#endif
