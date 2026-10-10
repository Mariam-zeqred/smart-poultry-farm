/*
 * ota_update.cpp - Wireless firmware upload portal
 *
 * Basic-auth-gated page at "/". Uploading a .bin streams straight into
 * the ESP32's OTA flash partition via Update.h — no SD card, no serial
 * cable. On success the device reboots into the new firmware.
 */

#include "ota_update.h"
#include "config.h"
#include <WebServer.h>
#include <Update.h>
#include <ESPmDNS.h>

static WebServer *server = NULL;
static const char *otaUser = NULL;
static const char *otaPass = NULL;
static bool uploadOk = false;

static const char PAGE_TEMPLATE[] PROGMEM = R"rawliteral(
<!DOCTYPE html><html><head>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<title>Poultry Farm OTA Update</title>
<style>
body{font-family:Arial;margin:40px;background:#f0f0f0}
.c{max-width:380px;margin:auto;background:#fff;padding:25px;border-radius:10px;
   box-shadow:0 2px 10px rgba(0,0,0,.1)}
h1{color:#2e7d32;text-align:center;font-size:22px}
.v{color:#888;text-align:center;font-size:13px;margin-top:-8px}
input[type=file]{width:100%%;margin:16px 0;font-size:14px}
button{width:100%%;padding:12px;background:#2e7d32;color:#fff;
       border:none;border-radius:4px;font-size:16px;cursor:pointer}
button:hover{background:#1b5e20}
.n{color:#888;text-align:center;font-size:12px;margin-top:14px}
</style></head><body>
<div class='c'>
<h1>&#x1F425; Firmware Update</h1>
<p class='v'>Running: %s</p>
<form method='POST' action='/update' enctype='multipart/form-data'>
<input type='file' name='firmware' accept='.bin' required>
<button type='submit'>Upload &amp; Flash</button>
</form>
<p class='n'>Select the .bin compiled for this board. Device reboots automatically on success — don't close this page or power off mid-upload.</p>
</div></body></html>
)rawliteral";

static void handleRoot() {
    if (!server->authenticate(otaUser, otaPass)) return server->requestAuthentication();
    char page[sizeof(PAGE_TEMPLATE) + 32];
    snprintf(page, sizeof(page), PAGE_TEMPLATE, FIRMWARE_VERSION);
    server->send(200, "text/html", page);
}

static void handleUploadResult() {
    if (!server->authenticate(otaUser, otaPass)) return server->requestAuthentication();
    server->send(200, "text/html",
        uploadOk
            ? "<html><body><h1>Flashed OK — rebooting...</h1></body></html>"
            : "<html><body><h1>Update FAILED</h1><p>Check Serial log for details. Device did not reboot.</p></body></html>");
    if (uploadOk) {
        delay(500);
        ESP.restart();
    }
}

static void handleUpload() {
    HTTPUpload &upload = server->upload();

    if (upload.status == UPLOAD_FILE_START) {
        uploadOk = false;
        Serial.printf("[OTA] Upload start: %s\n", upload.filename.c_str());
        if (!Update.begin(UPDATE_SIZE_UNKNOWN)) {
            Serial.println("[OTA] Update.begin() failed:");
            Update.printError(Serial);
        }
    } else if (upload.status == UPLOAD_FILE_WRITE) {
        if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) {
            Serial.println("[OTA] Update.write() failed:");
            Update.printError(Serial);
        }
    } else if (upload.status == UPLOAD_FILE_END) {
        uploadOk = Update.end(true);
        if (uploadOk) {
            Serial.printf("[OTA] Upload complete: %u bytes — rebooting after response\n", upload.totalSize);
        } else {
            Serial.println("[OTA] Update.end() failed:");
            Update.printError(Serial);
        }
    } else if (upload.status == UPLOAD_FILE_ABORTED) {
        Serial.println("[OTA] Upload aborted by client");
        Update.abort();
    }
}

// ---- Public API ----

void ota_start(int port, const char *user, const char *pass, const char *mdnsHostname) {
    if (server) return;
    otaUser = user;
    otaPass = pass;
    server = new WebServer(port);
    server->on("/", HTTP_GET, handleRoot);
    server->on("/update", HTTP_POST, handleUploadResult, handleUpload);
    server->begin();
    Serial.printf("[OTA] Server started on port %d\n", port);

    // mDNS so the upload page is reachable at a fixed name instead of
    // whatever IP DHCP happens to hand out this time — the IP changes
    // between networks/reboots, the hostname doesn't.
    if (MDNS.begin(mdnsHostname)) {
        MDNS.addService("http", "tcp", port);
        Serial.printf("[OTA] Reachable at http://%s.local/\n", mdnsHostname);
    } else {
        Serial.println("[OTA] mDNS start failed — use the device's IP instead (printed above at connect time)");
    }
    Serial.printf("[OTA] If .local doesn't resolve on your device, the current IP is also in farm/meta.localIp\n");
}

void ota_handle() {
    if (server) server->handleClient();
}

void ota_stop() {
    if (server) {
        server->stop();
        delete server;
        server = NULL;
    }
}
