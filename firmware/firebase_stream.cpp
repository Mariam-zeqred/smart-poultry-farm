/*
 * firebase_stream.cpp - SSE client for Firebase RTDB.
 *
 * Wire format from the server:
 *
 *   event: put
 *   data: {"path":"/control/state","data":{"fanState":true,...}}
 *
 *   event: patch
 *   data: {"path":"/control/state","data":{"fanState":false}}
 *
 *   event: keep-alive
 *   data: null
 *
 *   event: cancel
 *   data: null
 *
 *   event: auth_revoked
 *   data: ...
 *
 * Each event is two lines (event + data) separated by a blank line.
 * The connection stays open; events arrive as data changes.
 *
 * Implementation notes:
 *   - We do NOT use HTTPClient for streaming because it buffers, which
 *     defeats the realtime property. We talk to WiFiClientSecure directly.
 *   - We do NOT block in firebase_stream_loop() — only read what's
 *     available and return. Caller controls cadence.
 *   - Lines are read into a fixed buffer; over-long lines are truncated
 *     and the stream is reset.
 *   - A read timeout > 0 means an idle stream returns false; we set it
 *     to 0 (non-blocking) and rely on `available()` instead.
 */

#include "firebase_stream.h"
#include <WiFiClientSecure.h>

static WiFiClientSecure *g_streamClient = nullptr;
static FirebaseStreamCallback g_callback = nullptr;

// SSE accumulator. Firebase's initial event after subscribing always sends
// the ENTIRE current subtree at the streamed path as one line — since we
// stream the whole /farm node (sensors/alerts/vision history included),
// this routinely exceeded 1024 bytes, causing a permanent overflow/reset/
// resubscribe loop (visible in serial logs as repeated "Line buffer
// overflow, resetting") that never let the stream stay up. Each reset
// tears down and recreates a WiFiClientSecure (~40KB of TLS session heap),
// and that churn happening every couple seconds is a prime suspect for the
// heap-corruption reboots the HW team hit (2026-08-26). Bumped generously;
// if /farm keeps growing (more sensor history/alerts) this may need to
// grow again, or the ESP should subscribe to a narrower path than the
// whole farm tree.
//static const size_t LINE_BUF_SIZE = 8192;
static const size_t LINE_BUF_SIZE = 16384;
static char  g_lineBuf[LINE_BUF_SIZE];
static size_t g_lineLen = 0;
static char  g_pendingEvent[16] = {0};   // "put", "patch", "keep-alive", ...
// volatile: written on Core 0 (firebaseTask), read on Core 1 (loop/UI) via
// firebase_stream_lastByteMs() without a lock.
static volatile unsigned long g_lastByteAt = 0;

// Server should send a keep-alive at least every 30 s. If we go silent
// for >60 s, treat the connection as dead.
static const unsigned long STREAM_IDLE_TIMEOUT_MS = 60000UL;

// Cap how long a single firebase_stream_loop() call may spend draining.
// Confirmed live (2026-08-30): a burst of back-to-back control events (in
// that case, a self-reinforcing echo loop — see the .ino's onStreamEvent()
// fix for the actual cause) kept available() perpetually true, so this
// call never returned control to firebaseTask's for(;;) loop — starving
// firebase_sendSensors()/firebase_updateStatus() (meta.lastSeen froze)
// for as long as it ran. Whatever's left unread just stays buffered in the
// OS socket for the next call a few ms later; nothing is lost.
static const unsigned long STREAM_DRAIN_BUDGET_MS = 200UL;

// ---- Helpers ----

static void resetClient() {
    if (g_streamClient) {
        g_streamClient->stop();
        delete g_streamClient;
        g_streamClient = nullptr;
    }
    g_lineLen = 0;
    g_pendingEvent[0] = '\0';
    g_lastByteAt = 0;
}

// Parse "https://host[:port]/path?query" into host, port, target.
// Returns false if URL malformed.
static bool parseHttpsUrl(const char *url, String &host, uint16_t &port,
                          String &target) {
    String s(url);
    if (!s.startsWith("https://")) return false;
    s = s.substring(8);
    int slash = s.indexOf('/');
    String hostPort = (slash >= 0) ? s.substring(0, slash) : s;
    target          = (slash >= 0) ? s.substring(slash) : String("/");
    int colon = hostPort.indexOf(':');
    if (colon >= 0) {
        host = hostPort.substring(0, colon);
        port = (uint16_t)hostPort.substring(colon + 1).toInt();
    } else {
        host = hostPort;
        port = 443;
    }
    return host.length() > 0 && target.length() > 0;
}

// Dispatch one complete event (g_pendingEvent + accumulated data).
static void dispatchEvent(const char *dataLine) {
    if (g_pendingEvent[0] == '\0') return;
    if (strcmp(g_pendingEvent, "keep-alive") == 0) return;
    if (strcmp(g_pendingEvent, "cancel") == 0) {
        Serial.println("[STREAM] Server canceled subscription");
        resetClient();
        return;
    }
    if (strcmp(g_pendingEvent, "auth_revoked") == 0) {
        Serial.println("[STREAM] Auth revoked, dropping connection");
        resetClient();
        return;
    }
    if (strcmp(g_pendingEvent, "put") != 0 &&
        strcmp(g_pendingEvent, "patch") != 0) {
        return;  // unknown event, ignore
    }

    // dataLine is JSON: {"path":"...", "data":...}
    JsonDocument envelope;
    DeserializationError err = deserializeJson(envelope, dataLine);
    if (err) {
        Serial.printf("[STREAM] JSON parse error: %s\n", err.c_str());
        return;
    }

    const char *path = envelope["path"] | "/";

    // Extract the data sub-object into its own document so the callback
    // can use it independently.
    JsonDocument dataDoc;
    JsonVariantConst dataVar = envelope["data"];
    dataDoc.set(dataVar);

    if (g_callback) {
        g_callback(g_pendingEvent, path, dataDoc);
    }
}

// Process one fully-received line of the SSE stream.
static void processLine(const char *line) {
    g_lastByteAt = millis();

    if (line[0] == '\0') {
        // Blank line — end of one event. (We've already dispatched on the
        // data: line below; nothing extra to do here.)
        return;
    }

    if (strncmp(line, "event:", 6) == 0) {
        const char *p = line + 6;
        while (*p == ' ') p++;
        strncpy(g_pendingEvent, p, sizeof(g_pendingEvent) - 1);
        g_pendingEvent[sizeof(g_pendingEvent) - 1] = '\0';
        return;
    }

    if (strncmp(line, "data:", 5) == 0) {
        const char *p = line + 5;
        while (*p == ' ') p++;
        dispatchEvent(p);
        g_pendingEvent[0] = '\0';
        return;
    }

    // Unrecognized line — ignore (could be a comment, e.g. ":")
}

// ---- Public API ----

bool firebase_stream_begin(const char *fullStreamUrl,
                            const char *authToken,
                            FirebaseStreamCallback callback) {
    resetClient();
    g_callback = callback;

    String host, target;
    uint16_t port;
    if (!parseHttpsUrl(fullStreamUrl, host, port, target)) {
        Serial.println("[STREAM] Bad URL");
        return false;
    }
    if (authToken && strlen(authToken) > 0) {
        target += (target.indexOf('?') >= 0 ? "&" : "?");
        target += "auth=";
        target += authToken;
    }

    g_streamClient = new WiFiClientSecure();
    if (!g_streamClient) {
        Serial.println("[STREAM] FATAL: heap exhaustion");
        return false;
    }
    g_streamClient->setInsecure();  // TODO: replace with setCACert in production
    g_streamClient->setTimeout(10);  // 10s connect timeout

    if (!g_streamClient->connect(host.c_str(), port)) {
        Serial.printf("[STREAM] connect() failed to %s:%u\n", host.c_str(), port);
        resetClient();
        return false;
    }

    // Send the SSE request. RTDB requires GET + Accept: text/event-stream.
    String req;
    req.reserve(256);
    req += "GET ";
    req += target;
    req += " HTTP/1.1\r\nHost: ";
    req += host;
    req += "\r\nAccept: text/event-stream\r\n";
    req += "Connection: keep-alive\r\n";
    req += "User-Agent: ESP32-PoultryFarm/1.0\r\n\r\n";
    g_streamClient->print(req);

    // Wait for status line + skip headers
    unsigned long deadline = millis() + 10000;
    bool gotStatus = false;
    int statusCode = 0;
    while (millis() < deadline) {
        String line = g_streamClient->readStringUntil('\n');
        if (line.length() == 0) {
            delay(10);
            continue;
        }
        line.trim();
        if (!gotStatus) {
            int sp1 = line.indexOf(' ');
            int sp2 = (sp1 >= 0) ? line.indexOf(' ', sp1 + 1) : -1;
            if (sp1 >= 0 && sp2 > sp1) {
                statusCode = line.substring(sp1 + 1, sp2).toInt();
                gotStatus = true;
            }
            continue;
        }
        if (line.length() == 0) break;  // end of headers
        if (line == "\r") break;
    }

    // gotStatus=false means we never saw a parseable status line at all
    // (malformed/no response) — that must fail, not be treated as success.
    if (!gotStatus || (statusCode != 200 && statusCode != 307)) {
        Serial.printf("[STREAM] Bad status: %d%s\n", statusCode,
                      gotStatus ? "" : " (no status line received)");
        resetClient();
        return false;
    }

    g_lastByteAt = millis();
    Serial.printf("[STREAM] Subscribed to %s:%u%s\n", host.c_str(), port,
                  target.c_str());
    return true;
}

bool firebase_stream_loop() {
    if (!g_streamClient) return false;
    if (!g_streamClient->connected()) {
        Serial.println("[STREAM] TCP disconnected");
        resetClient();
        return false;
    }

    // Drain whatever is currently buffered. We DO NOT block waiting for more,
    // and we do not drain forever either — see STREAM_DRAIN_BUDGET_MS.
    unsigned long drainDeadline = millis() + STREAM_DRAIN_BUDGET_MS;
    while (g_streamClient->available()) {
        if (millis() >= drainDeadline) break;
        int c = g_streamClient->read();
        if (c < 0) break;
        g_lastByteAt = millis();

        if (c == '\r') continue;          // ignore CR
        if (c == '\n') {
            g_lineBuf[g_lineLen] = '\0';
            processLine(g_lineBuf);
            g_lineLen = 0;
            continue;
        }

        if (g_lineLen >= LINE_BUF_SIZE - 1) {
            // Over-long line — likely corrupted. Reset stream.
            Serial.println("[STREAM] Line buffer overflow, resetting");
            resetClient();
            return false;
        }
        g_lineBuf[g_lineLen++] = (char)c;
    }

    // Idle-timeout check (server should send keep-alive every 30 s)
    if (g_lastByteAt > 0 && (millis() - g_lastByteAt) > STREAM_IDLE_TIMEOUT_MS) {
        Serial.println("[STREAM] Idle timeout — assuming dead connection");
        resetClient();
        return false;
    }

    return true;
}

void firebase_stream_end() {
    resetClient();
    g_callback = nullptr;
}

bool firebase_stream_isConnected() {
    return g_streamClient && g_streamClient->connected();
}

unsigned long firebase_stream_lastByteMs() {
    // resetClient() zeroes this, so a torn-down/reconnecting stream
    // correctly reports "no recent contact" rather than a stale timestamp.
    return g_lastByteAt;
}
