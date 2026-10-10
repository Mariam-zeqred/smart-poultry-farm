/*
 * firebase_stream.h - Firebase RTDB Server-Sent-Events streaming client
 *
 * Holds a long-lived HTTPS connection to a Firebase RTDB endpoint with
 * Accept: text/event-stream. Server pushes events whenever the underlying
 * data changes, eliminating REST polling lag.
 *
 * Usage:
 *   1. Call firebase_stream_begin() once after WiFi connected.
 *   2. Periodically call firebase_stream_loop() from a task. It returns
 *      false if the connection is broken — the caller must call
 *      firebase_stream_begin() again to reconnect.
 *   3. The callback fires from the calling task's context whenever the
 *      server sends a 'put' or 'patch' event. 'keep-alive' events are
 *      handled internally and do NOT invoke the callback.
 *
 * Protocol reference:
 *   https://firebase.google.com/docs/database/rest/retrieve-data#section-rest-streaming
 */

#ifndef FIREBASE_STREAM_H
#define FIREBASE_STREAM_H

#include <Arduino.h>
#include <ArduinoJson.h>

/**
 * Callback signature.
 *
 *  eventType - "put" or "patch"
 *  path      - Path of the changed node, relative to the streamed root.
 *              "/" for the entire root, "/control/state" for a subtree, etc.
 *  data      - Parsed JsonDocument of the data field. May be a primitive
 *              (bool/int/string), an object, or null (for deletions).
 */
typedef void (*FirebaseStreamCallback)(const char *eventType,
                                        const char *path,
                                        JsonDocument &data);

/**
 * Open the stream.
 *
 *  fullStreamUrl  - e.g. "https://xxx.firebaseio.com/farm.json"
 *  authToken      - Firebase auth token, or empty string
 *  callback       - Invoked on each put/patch event
 *
 * Returns true on success. After success, call firebase_stream_loop()
 * regularly to drain incoming events.
 */
bool firebase_stream_begin(const char *fullStreamUrl,
                            const char *authToken,
                            FirebaseStreamCallback callback);

/**
 * Drain pending events from the stream.
 *
 * Returns false if the connection is dead (read error, timeout, EOF) — the
 * caller should call firebase_stream_begin() again to reconnect.
 *
 * Returns true if connection is healthy (events may or may not have fired).
 */
bool firebase_stream_loop();

/** Close the stream and release resources. */
void firebase_stream_end();

/** True if the stream's TCP/TLS connection is currently open. */
bool firebase_stream_isConnected();

/**
 * millis() of the last byte received from the server (including keep-alive
 * events), or 0 if the stream is down / has never been up.
 *
 * This is the streaming half of the "is the cloud actually reachable"
 * signal — the server sends a keep-alive at least every 30 s, so a fresh
 * value here proves the round trip to Firebase is alive even when no data
 * has changed. ORed with firebase_lastSuccessMs() by cloudReachable() in
 * the main sketch; note that isConnected() is NOT a substitute, since a
 * TCP socket can stay open long after the far end became unreachable.
 *
 * Written on Core 0, read on Core 1 without a lock (aligned 32-bit).
 */
unsigned long firebase_stream_lastByteMs();

#endif
