/*
 * ota_update.h - Wireless firmware upload over local WiFi
 *
 * Serves a small upload page at http://<device-ip>/ (basic-auth protected)
 * that flashes a new .bin via the ESP32's built-in Update library. Only
 * runs while connected to WiFi in normal STA mode — never in AP-provisioning
 * mode, where wifi_provision.cpp's server already owns port 80.
 */

#ifndef OTA_UPDATE_H
#define OTA_UPDATE_H

#include <Arduino.h>

// Start OTA server (call once, after WiFi connects). Also starts mDNS so
// the device is reachable at http://<mdnsHostname>.local/ instead of
// needing to know its current DHCP-assigned IP.
void ota_start(int port, const char *user, const char *pass, const char *mdnsHostname);

// Must be called repeatedly (Core 0 — never from the Core 1 safety loop,
// since handling an upload blocks for the duration of the transfer)
void ota_handle();

void ota_stop();

#endif
