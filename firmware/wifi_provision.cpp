/*
 * wifi_provision.cpp - WiFi provisioning portal
 *
 * Serves a simple HTML form. On submit, saves credentials
 * to Preferences (NVS) and restarts the ESP32.
 */

#include "wifi_provision.h"
#include <WebServer.h>
#include <Preferences.h>

static WebServer *server = NULL;

// millis() of the last request the portal served, 0 = nothing yet.
// Read by the main sketch (provision_lastRequestMs()) so its AP-mode
// recovery never reboots the device out from under someone who is in the
// middle of filling in the setup form.
static unsigned long lastRequestMs = 0;

static const char PAGE[] PROGMEM = R"rawliteral(
<!DOCTYPE html><html><head>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<title>Poultry Farm Setup</title>
<style>
body{font-family:Arial;margin:40px;background:#f0f0f0}
.c{max-width:380px;margin:auto;background:#fff;padding:25px;border-radius:10px;
   box-shadow:0 2px 10px rgba(0,0,0,.1)}
h1{color:#2e7d32;text-align:center;font-size:22px}
label{display:block;margin-top:12px;font-weight:bold;font-size:14px}
input{width:100%;padding:10px;margin:4px 0 0;box-sizing:border-box;
      border:1px solid #ccc;border-radius:4px}
button{width:100%;padding:12px;margin-top:18px;background:#2e7d32;color:#fff;
       border:none;border-radius:4px;font-size:16px;cursor:pointer}
button:hover{background:#1b5e20}
.n{color:#888;text-align:center;font-size:12px;margin-top:10px}
</style></head><body>
<div class='c'>
<h1>&#x1F414; Poultry Farm Setup</h1>
<form method='POST' action='/provision'>
<label>WiFi SSID</label><input name='ssid' required>
<label>WiFi Password</label><input name='pass' type='password'>
<label>Firebase URL</label><input name='fb_url' placeholder='https://xxx.firebaseio.com'>
<label>User ID</label><input name='user_id' placeholder='Firebase UID'>
<button type='submit'>Save &amp; Connect</button>
</form>
<p class='n'>Device will restart after saving.</p>
</div></body></html>
)rawliteral";

static void handleRoot() {
    lastRequestMs = millis();
    Serial.printf("[PROVISION] Setup page requested by %s\n",
                  server->client().remoteIP().toString().c_str());
    server->send(200, "text/html", PAGE);
}

static void handleProvision() {
    lastRequestMs = millis();
    String ssid   = server->arg("ssid");
    String pass   = server->arg("pass");
    String fbUrl  = server->arg("fb_url");
    String userId = server->arg("user_id");

    Serial.printf("[PROVISION] Form submitted: ssid=%s fb_url=%s user_id=%s\n",
                  ssid.c_str(), fbUrl.c_str(), userId.c_str());

    if (ssid.length() == 0) {
        Serial.println("[PROVISION] Rejected: SSID missing");
        server->send(400, "text/plain", "SSID is required");
        return;
    }

    // Save to NVS
    Preferences prefs;
    prefs.begin("wifi_creds", false);
    prefs.putString("ssid", ssid);
    prefs.putString("pass", pass);
    prefs.end();

    // fb_url/user_id: only overwrite when provided, so leaving them blank
    // keeps whatever was set before (or the compiled-in default).
    //
    // No "Device ID" field here on purpose — it used to let a user nest
    // this device's data under farm/<deviceId>/... instead of the flat
    // farm/... root the app actually reads, which silently broke the app's
    // "online" check (HW team hit exactly this, 2026-08-26: WiFi connected
    // fine, app stayed "Offline" because it was reading a different path
    // than the device was writing to). firebase_init() now always uses the
    // flat path regardless of any stored Device ID, so removing the field
    // here just removes a setting that could never help and could only
    // confuse a non-technical user into breaking connectivity by typing
    // something into it.
    prefs.begin("device_cfg", false);
    if (fbUrl.length() > 0) prefs.putString("fb_url", fbUrl);
    if (userId.length() > 0) prefs.putString("user_id", userId);
    prefs.end();

    server->send(200, "text/html",
        "<html><body><h1>Saved!</h1>"
        "<p>Connecting to <b>" + ssid + "</b>...</p>"
        "<p>Device will restart now.</p></body></html>");

    Serial.printf("[PROVISION] Saved SSID=%s, restarting...\n", ssid.c_str());
    delay(2000);
    ESP.restart();
}

// ---- Public API ----

void provision_start(int port) {
    if (server) return;
    server = new WebServer(port);
    server->on("/", HTTP_GET, handleRoot);
    server->on("/provision", HTTP_GET, handleRoot);
    server->on("/provision", HTTP_POST, handleProvision);
    server->begin();
    Serial.printf("[PROVISION] Server started on port %d\n", port);
}

void provision_handle() {
    if (server) server->handleClient();
}

unsigned long provision_lastRequestMs() {
    return lastRequestMs;
}

void provision_stop() {
    if (server) {
        server->stop();
        delete server;
        server = NULL;
    }
}
