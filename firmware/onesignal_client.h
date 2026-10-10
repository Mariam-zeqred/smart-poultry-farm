/*
 * onesignal_client.h - Push notifications via OneSignal's REST API
 */

#ifndef ONESIGNAL_CLIENT_H
#define ONESIGNAL_CLIENT_H

#include <Arduino.h>

// Sends a push notification via OneSignal to every subscribed phone.
// Blocking (~1-3s for a fresh TLS handshake) — only ever call from Core 0
// (firebaseTask), never Core 1. Returns false (harmlessly) if
// ONESIGNAL_APP_ID/ONESIGNAL_REST_API_KEY aren't configured in config.h.
bool onesignal_sendAlert(const char *title, const char *message);

#endif
