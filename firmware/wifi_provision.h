/*
 * wifi_provision.h - WiFi provisioning portal via WebServer
 *
 * In AP mode, serves a config page at http://192.168.4.1/
 * User submits WiFi credentials + device ID → saved to Preferences → reboot
 */

#ifndef WIFI_PROVISION_H
#define WIFI_PROVISION_H

#include <Arduino.h>

// Start provisioning server (call after WiFi AP started)
void provision_start(int port);

// Must be called in loop() to handle HTTP requests
void provision_handle();

// millis() of the last request the portal served (0 = none since it
// started). Lets the caller tell "nobody is using the setup page" apart
// from "someone is typing their password into it right now" before doing
// anything disruptive, like rebooting.
unsigned long provision_lastRequestMs();

// Stop server
void provision_stop();

#endif
