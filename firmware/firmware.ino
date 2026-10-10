/*
 * Smart Poultry Farm IoT Controller — FreeRTOS dual-core
 * Arduino IDE sketch for ESP32
 *
 * What this device does
 * ---------------------
 * Reads temperature, humidity and gas (ammonia) inside a poultry house,
 * drives four relays (Fan, Cooler, Heater, Humidifier) to keep the birds
 * in a comfortable range, enforces hard safety limits locally, and mirrors
 * everything to a Firebase Realtime Database so the Flutter app can watch
 * and control it from anywhere. A 16x2 LCD + 4 buttons give full local
 * control with no phone at all.
 *
 * Architecture
 * ------------
 *   Core 1 (loop):         UI + sensors + safety + auto-control + fan cycle
 *                          — runs every ~10ms and NEVER blocks on network I/O
 *   Core 0 (firebaseTask): every blocking HTTPS call (REST + SSE stream +
 *                          OneSignal + OTA) — blocking is fine here
 *
 * Shared state (fanOn, autoMode, thresholds, ...) is protected by a FreeRTOS
 * mutex (LOCK()/UNLOCK()). Core 1 never calls the network directly: it sets
 * "pending" flags (requestControlPush(), requestAlert(), thresholdsDirty,
 * fanCycleDirty) and Core 0 drains them. That split is what keeps buttons
 * and safety checks responsive even during a 5-second TLS timeout.
 *
 * Control priority (highest first)
 * --------------------------------
 *   1. checkSafety()        hard limits (GAS_ABS_MAX, TEMP_ABS_*, HUM_ABS_*)
 *                           — overrides everyone, sets all four relays explicitly
 *   2. evaluateFanCycle()   scheduled airing owns the Fan while enabled
 *   3. evaluateAutoControl() sensor-driven logic (sensors_evaluate())
 *      while controlMode == "automatic"
 *   4. Manual commands      from the app (stream/REST) or the LCD buttons,
 *      only while controlMode == "manual"
 *   applyStates() is the single choke point every path goes through before
 *   a relay is actually driven; it also enforces Heater/Cooler exclusion and
 *   "Cooler on forces Fan on".
 *
 * Who is allowed to command (control ownership)
 * ---------------------------------------------
 *   appOwnsControl() = appControlEnabled && wifiOk && cloudReachable()
 *   True  -> the app commands, the LCD is monitor-only.
 *   False -> the LCD commands. This flips automatically after
 *            CLOUD_STALE_MS of silence from Firebase, so a router that is
 *            up but off the internet never strands the farmer.
 *
 * Module map
 * ----------
 *   config.h            every pin, threshold, timing constant (+ secrets.h)
 *   config_loader.*     defaults -> SPIFFS config.csv -> NVS overlay
 *   sensors.*           AM2302/DHT22 + MQ135 drivers, sensors_evaluate() rules
 *   command_handler.*   relay GPIO writes (polarity-aware)
 *   firebase_client.*   REST client (persistent TLS session, mutex-guarded)
 *   firebase_stream.*   SSE client for sub-500ms control updates
 *   onesignal_client.*  push notifications straight from the device
 *   lcd_display.*       HD44780 over PCF8574 I2C backpack
 *   ui_manager.*        LCD screens + 4-button state machine
 *   wifi_provision.*    captive setup portal (AP mode) -> NVS
 *   ota_update.*        browser-based firmware upload page (STA mode)
 *
 * Section order in this file
 * --------------------------
 *   shared state & deferred-push queue -> helpers (cloudReachable,
 *   appOwnsControl, applyStates, apply*Doc) -> UI callbacks -> fan cycle ->
 *   auto-control -> safety -> comfort alerts -> stream callback ->
 *   firebaseTask (Core 0) -> WiFi diagnostics -> setup() -> loop()
 *
 * Required board:  ESP32 Dev Module (esp32:esp32:esp32, core 3.x)
 * Required lib:    ArduinoJson 7.x by Benoit Blanchon (Library Manager)
 */

#include <WiFi.h>
#include <Wire.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include "config.h"
#include "sensors.h"
#include "command_handler.h"
#include "firebase_client.h"
#include "firebase_stream.h"
#include "onesignal_client.h"
#include "config_loader.h"
#include "ui_manager.h"
#include "wifi_provision.h"
#include "ota_update.h"

// ==================== Realtime mode ====================
// Set to 1 to use Firebase RTDB streaming for control/state + config/thresholds
// changes (sub-500ms latency from app→ESP). Set to 0 to fall back to legacy
// REST polling (up to 2s lag). Sensor push and heartbeat are unchanged.
#define USE_STREAMING 1

// Return type for applyControlStateDoc() below. Declared up here (before
// any other code) because Arduino auto-generates function prototypes and
// inserts them right after the last top-of-file include/comment block —
// if this struct were defined further down (where it's used), the
// auto-generated prototype for applyControlStateDoc() would reference an
// as-yet-undeclared type and fail to compile.
struct ControlApplyResult {
    bool modeChanged;
    bool stateChanged;
    bool appControlChanged;
};

// ==================== Shared State (protected by mutex) ====================

static SemaphoreHandle_t stateMutex;

AppConfig      appCfg;
SensorData     sensorData;
Thresholds     thresholds;

bool fanOn         = false;
bool coolerOn      = false;
bool heaterOn      = false;
bool humidifierOn  = false;
bool autoMode  = true;
// Control ownership: which side (app vs LCD) is currently allowed to
// command actuators/mode. True = app owns control (LCD is monitor-only);
// false = LCD owns control (app UI greys out). Defaults true so existing
// installs that never touch the new "App Control" toggle behave exactly
// as before this feature existed. Only ever written by the app (no LCD UI
// for it) — see applyControlStateDoc()'s comment for why that's safe.
bool appControlEnabled = true;
bool safetyActive = false;
bool sensorReady  = false;

// Fan cycle (scheduled airing): when enabled, a local Core-1 state machine
// (see evaluateFanCycle()) drives the fan ON/OFF on a fixed schedule,
// independent of gas/temp/humidity and independent of WiFi/Firebase being
// up. Config (enabled/durations) is app-set via Firebase; the phase timer
// itself is pure local runtime state, not persisted anywhere.
bool          fanCycleEnabled     = FAN_CYCLE_ENABLED_DEFAULT;
unsigned long fanCycleOnMs        = FAN_CYCLE_ON_SEC_DEFAULT  * 1000UL;
unsigned long fanCycleOffMs       = FAN_CYCLE_OFF_SEC_DEFAULT * 1000UL;
bool          fanCyclePhaseOn     = true;  // current phase: true=ON, false=OFF
unsigned long fanCyclePhaseStart  = 0;     // millis() the current phase began
bool          fanCycleRestart     = true;  // true = (re)start fresh next evaluation

// volatile: written by Core 1 (loop), read by Core 0 (firebaseTask)
volatile bool wifiOk = false;
bool apMode    = false;
// True once setup() has actually attempted the stored credentials. Tells
// "we are in the portal because the saved network did not come up in time"
// (recoverable, see checkApLateConnect()) apart from "we are in the portal
// because there is nothing to connect to yet" - a never-provisioned device,
// or a deliberate SELECT-hold AP reset - where retrying makes no sense.
bool staCredsTried = false;

// Write-cooldown tracking (set by UI core, read by Firebase core)
#define WRITE_COOLDOWN_MS 3000
volatile unsigned long lastLocalControlWrite   = 0;
volatile unsigned long lastLocalThresholdWrite = 0;
volatile bool thresholdsDirty = false;
volatile unsigned long lastLocalFanCycleWrite = 0;
volatile bool fanCycleDirty = false;

// Alert cooldown tracking (Firebase core only). Declared here, before any
// function with a body, because Arduino's auto-generated function
// prototypes are all inserted collectively at the position of the FIRST
// function definition in the file — AlertType must already be visible
// there for alertReady(AlertType)'s auto-prototype to compile (same reason
// ControlApplyResult is declared at the very top of this file).
#define THRESHOLD_POLL_INTERVAL 30000
// The "_WARN" entries below are for checkComfortAlerts() — separate
// cooldown slots from checkSafety()'s hard-limit alerts (A_TEMP_HI etc.)
// so a critical alert firing doesn't suppress the softer warning for the
// same dimension once the reading drops back under the ABS limit but is
// still outside the user's configured Range, and vice versa.
unsigned long lastAlert[10] = {0};
enum AlertType { A_TEMP_HI, A_TEMP_LO, A_HUM_HI, A_HUM_LO, A_GAS,
                  A_TEMP_HI_WARN, A_TEMP_LO_WARN, A_HUM_HI_WARN, A_HUM_LO_WARN, A_GAS_WARN };

// ---- Deferred Firebase push queue (Core 1 -> Core 0) ----
// pushControlToFirebase()/firebase_sendAlert() are blocking HTTPS calls.
// Core 1 (buttons/safety/loop) must NEVER block on network I/O — a button
// press or a safety check freezing for seconds while a request is in
// flight is exactly the "Select button needs 5 presses" / "safety check
// stalls" class of bug (HW team report, 2026-08-26). So Core 1 only ever
// records "a push is needed" here; Core 0's firebaseTask does the actual
// blocking call, mirroring the existing thresholdsDirty pattern above.
volatile bool pendingControlPush = false;
volatile bool pendingPushSafetyOverride = false;
char pendingPushReason[64] = {0};

void requestControlPush(const char *reason, bool safetyOverride) {
    strncpy(pendingPushReason, reason, sizeof(pendingPushReason) - 1);
    pendingPushReason[sizeof(pendingPushReason) - 1] = '\0';
    pendingPushSafetyOverride = safetyOverride;
    pendingControlPush = true;  // set last so reason/flag are consistent once observed true
}

volatile bool pendingAlert = false;
char pendingAlertType[24]      = {0};
char pendingAlertSeverity[12]  = {0};
char pendingAlertMsg[80]       = {0};
float pendingAlertValue        = 0;
float pendingAlertThreshold    = 0;

void requestAlert(const char *type, const char *severity, const char *msg,
                   float value, float threshold) {
    strncpy(pendingAlertType, type, sizeof(pendingAlertType) - 1);
    pendingAlertType[sizeof(pendingAlertType) - 1] = '\0';
    strncpy(pendingAlertSeverity, severity, sizeof(pendingAlertSeverity) - 1);
    pendingAlertSeverity[sizeof(pendingAlertSeverity) - 1] = '\0';
    strncpy(pendingAlertMsg, msg, sizeof(pendingAlertMsg) - 1);
    pendingAlertMsg[sizeof(pendingAlertMsg) - 1] = '\0';
    pendingAlertValue     = value;
    pendingAlertThreshold = threshold;
    pendingAlert = true;  // set last
}

// Push-notification title per alert type. Mirrors Alert.typeDisplayName in
// app/app/lib/core/models/alert_model.dart — keep both in sync if either
// side's alert type strings ever change. (The in-app alert list still gets
// its label from that Dart mapping; this is only for the OS notification
// title, which the firmware sends directly via onesignal_client.cpp.)
static const char *alertPushTitle(const char *type) {
    if (strcmp(type, "gas_critical")      == 0) return "Dangerous Gas Level";
    if (strcmp(type, "temp_critical_low") == 0) return "Critical Low Temperature";
    if (strcmp(type, "temp_critical_high") == 0) return "Critical High Temperature";
    if (strcmp(type, "hum_critical_low")  == 0) return "Critical Low Humidity";
    if (strcmp(type, "hum_critical_high") == 0) return "Critical High Humidity";
    // Comfort-range warnings (checkComfortAlerts()) — these type strings
    // already matched Alert.typeDisplayName in alert_model.dart before
    // today (a leftover naming convention the firmware never used until
    // now — see the audit note in that file), so no app-side change was
    // needed to display them correctly in-app; this is just their OS
    // push-notification title.
    if (strcmp(type, "temperature_high")  == 0) return "High Temperature";
    if (strcmp(type, "temperature_low")   == 0) return "Low Temperature";
    if (strcmp(type, "humidity_high")     == 0) return "High Humidity";
    if (strcmp(type, "humidity_low")      == 0) return "Low Humidity";
    if (strcmp(type, "gas_detected")      == 0) return "Elevated Gas Level";
    return "Farm Alert";
}

// 24 KB — TLS handshake + JSON parsing require headroom beyond 16 KB
#define FIREBASE_TASK_STACK_BYTES 24576

// ==================== Helpers ====================

#define LOCK()   xSemaphoreTake(stateMutex, portMAX_DELAY)
#define UNLOCK() xSemaphoreGive(stateMutex)

bool alertReady(AlertType idx) {
    if (millis() - lastAlert[idx] >= ALERT_COOLDOWN) {
        lastAlert[idx] = millis();
        return true;
    }
    return false;
}

// Is Firebase actually reachable right now?
//
// NOT the same question as "are we on WiFi". wifiOk only means the ESP32 is
// associated with the router (WiFi.status() == WL_CONNECTED); it says
// nothing about whether the router can still reach the internet. The
// router-up/WAN-down case (ISP outage, dead modem, cut line) is common on a
// farm install and used to leave the device in the worst possible state: the
// app could not command anything, but the firmware still believed it could,
// so the LCD stayed locked out with "APP CONTROL" and nobody could drive the
// relays from either side (user/HW team, 2026-09-02).
//
// Measured instead of inferred: the most recent proof that a round trip to
// Firebase actually completed, from either transport — a 2xx REST response
// (heartbeat every FIREBASE_INTERVAL) or any byte off the SSE stream
// (keep-alive every ~30s). Note firebase_stream_isConnected() is NOT usable
// for this; a TCP socket happily stays "connected" long after the far end
// became unreachable, which is the whole reason the stream has its own idle
// timeout.
//
// Both accessors are lock-free reads of a volatile 32-bit timestamp — this
// runs on Core 1 every loop tick and must never block behind Core 0's
// in-flight HTTPS request.
static bool cloudReachable() {
    unsigned long last = firebase_lastSuccessMs();
#if USE_STREAMING
    unsigned long streamLast = firebase_stream_lastByteMs();
    if (streamLast > last) last = streamLast;
#endif
    // 0 = never reached the cloud since boot. Must be checked explicitly:
    // millis() - 0 is simply millis(), which is < CLOUD_STALE_MS for the
    // first 90 seconds of every boot and would otherwise read as "reachable"
    // on a device that has never once talked to Firebase (e.g. AP mode).
    if (last == 0) return false;
    return (millis() - last) < CLOUD_STALE_MS;
}

// THE control-ownership authority. Every ownership decision funnels through
// here; ui_manager.cpp's uiAppOwnsControl is only a downstream mirror of this
// value, fed to it by applyStates() via ui_setControlStates().
//
// Going stale is delayed (CLOUD_STALE_MS, so one slow request cannot flap
// ownership); coming back is immediate, on the first successful contact —
// deliberately asymmetric, since the app regaining control is the common case
// and should not be made to wait out a second timer.
static bool appOwnsControl() {
    return appControlEnabled && wifiOk && cloudReachable();
}

// applyStates MUST be called OUTSIDE any mutex — it performs I2C LCD writes
// which can block, and blocking inside a mutex causes cross-core deadlock.
void applyStates() {
    // Safety interlock: heater and cooler must never run at once (HW team,
    // 2026-08-26). Auto-control (sensors_evaluate()) and the dedicated
    // SAFETY branches in checkSafety() already keep them mutually exclusive
    // by construction (temp can't be both critically low AND high), but
    // MANUAL commands — LCD button toggle, or the app/stream writing
    // control/state directly via applyControlStateDoc() — have no such
    // guarantee. Enforce it here, the one place every path funnels through
    // before actually driving the relays.
    if (heaterOn && coolerOn) {
        Serial.println("[SAFETY] Heater+Cooler both requested - forcing both off (conflicting command)");
        heaterOn = false;
        coolerOn = false;
    }

    // Evaporative cooling requires airflow to work at all — the pad only
    // cools if the fan is pulling air through it (HW team, 2026-08-26).
    // Only the ON direction is forced; turning the cooler off doesn't force
    // the fan off too, since the fan may still be needed for ventilation.
    if (coolerOn) fanOn = true;

    cmd_setFan(fanOn);
    cmd_setCooler(coolerOn);
    cmd_setHeater(heaterOn);
    cmd_setHumidifier(humidifierOn);
    // LCD is only actually locked out by App Control while WiFi is up — if
    // connectivity is down the app has no way to be commanding anything
    // anyway, so the LCD regains control rather than stranding whoever's
    // standing at the device (see ui_manager.h's comment on this param).
    bool lcdLockedByApp = appOwnsControl();
    ui_setControlStates(fanOn, coolerOn, heaterOn, humidifierOn, autoMode, safetyActive, lcdLockedByApp);

    LOCK();
    bool cycleEnabled  = fanCycleEnabled;
    unsigned long onS  = fanCycleOnMs  / 1000UL;
    unsigned long offS = fanCycleOffMs / 1000UL;
    UNLOCK();
    ui_setFanCycle(cycleEnabled, onS, offS);
}

// Apply a control/state JSON object (from streaming callback OR REST poll).
// Reads fanState/coolerState/heaterState/humidifierState/controlMode fields
// and updates local state under the mutex; returns true if anything changed
// so the caller can call applyStates() and push reasons. (ControlApplyResult
// is declared near the top of the file — see comment there for why.)
static ControlApplyResult applyControlStateDoc(JsonDocument &doc) {
    ControlApplyResult r{false, false, false};
    bool newAppControl = doc["appControlEnabled"] | true;
    bool newAuto = strcmp(doc["controlMode"] | "automatic", "automatic") == 0;
    bool nf = doc["fanState"]         | false;
    bool nc = doc["coolerState"]      | false;
    bool nh = doc["heaterState"]      | false;
    bool nu = doc["humidifierState"]  | false;

    LOCK();
    // Control ownership (user/HW team, 2026-08-29): always honor this
    // field regardless of who currently owns control — it's the one
    // "take control back" escape hatch, and only the app ever writes it
    // (no LCD UI for it, by design), so there's no ownership check to
    // apply to the field itself.
    r.appControlChanged = (newAppControl != appControlEnabled);
    if (r.appControlChanged) appControlEnabled = newAppControl;

    // Mode/actuator fields below can only ever have originated from the
    // app — LCD writes apply straight to these same local vars before any
    // echo is ever sent (see onUiToggle()/onUiModeChange()), so an
    // incoming doc that actually changes mode or actuators is, by
    // construction, an app command. Only honor it while the app currently
    // owns control (using the value just resolved above, so a doc that
    // hands control back AND sets state in the same write is handled
    // correctly); while the LCD owns control, ignore mode/actuator fields
    // here entirely — same treatment as "ignore actuators while Auto"
    // below, just for the ownership axis instead of the regime axis.
    if (appControlEnabled) {
        r.modeChanged  = (newAuto != autoMode);
        if (r.modeChanged) autoMode = newAuto;

        // Actuators are only ever settable while (the resulting) mode is
        // MANUAL (HW team, 2026-08-29 — Auto and Manual are now mutually
        // exclusive control regimes, not "auto with a temporary manual
        // override window"). While staying/becoming AUTO, ignore any actuator
        // fields in this doc entirely so auto-control remains the sole
        // authority over the relays. This is the actual enforcement — the
        // app/LCD graying out actuator controls while Auto is selected is the
        // UI-level half of the same rule, but this is what makes it impossible
        // to bypass (a stray direct Firebase write, a client bug, etc. still
        // can't move a relay while Auto is active). This directly closes the
        // "toggling from the app while Auto causes erratic behavior" issue —
        // there is no more silent mode-preserving override for auto-control to
        // fight over a few seconds later.
        if (!newAuto) {
            r.stateChanged = (nf != fanOn || nc != coolerOn ||
                              nh != heaterOn || nu != humidifierOn);
            if (r.stateChanged) {
                fanOn = nf; coolerOn = nc;
                heaterOn = nh; humidifierOn = nu;
            }
        }
    }
    UNLOCK();
    return r;
}

// Apply a config/thresholds JSON object. Returns true if anything changed.
static bool applyThresholdsDoc(JsonDocument &doc) {
    bool changed = false;
    LOCK();
    float newTH = doc["temperatureHigh"] | thresholds.tempHigh;
    float newTL = doc["temperatureLow"]  | thresholds.tempLow;
    float newHH = doc["humidityHigh"]    | thresholds.humHigh;
    float newHL = doc["humidityLow"]     | thresholds.humLow;
    float newGH = doc["gasHigh"]         | thresholds.gasHigh;
    // Was never read here at all — the app has always written this field on
    // every threshold save, but the firmware silently ignored it and
    // sensors_evaluate() used its own hardcoded 10%-of-threshold band
    // instead (e.g. ~6-7 points for a 60-74% humidity range), nothing like
    // the "Hysteresis: 1.5" the Settings screen has been displaying the
    // whole time. That mismatch is what made the Humidifier look stuck
    // on after the reading was already back inside the configured Range
    // (HW team/user, 2026-08-30) — it hadn't cleared the real, much wider,
    // silently-hardcoded band yet. Now actually applied below.
    float newHyst = doc["hysteresis"]    | thresholds.hysteresis;

    if (newTH != thresholds.tempHigh || newTL != thresholds.tempLow ||
        newHH != thresholds.humHigh  || newHL != thresholds.humLow  ||
        newGH != thresholds.gasHigh  || newHyst != thresholds.hysteresis) {
        thresholds.tempHigh = newTH; thresholds.tempLow  = newTL;
        thresholds.humHigh  = newHH; thresholds.humLow   = newHL;
        thresholds.gasHigh  = newGH; thresholds.hysteresis = newHyst;
        changed = true;
    }
    UNLOCK();
    if (changed) ui_setThresholds(&thresholds);
    return changed;
}

// Apply a config/fanCycle JSON object ({enabled, onSec, offSec}). Returns
// true if anything changed. A false->true transition on "enabled" always
// (re)starts the phase timer fresh from ON, so partial old-duration state
// never carries over confusingly into a newly-(re)started cycle.
static bool applyFanCycleDoc(JsonDocument &doc) {
    bool changed = false;
    LOCK();
    bool newEnabled      = doc["enabled"] | fanCycleEnabled;
    unsigned long newOn  = (doc["onSec"]  | (fanCycleOnMs  / 1000UL)) * 1000UL;
    unsigned long newOff = (doc["offSec"] | (fanCycleOffMs / 1000UL)) * 1000UL;
    bool justEnabled     = (newEnabled && !fanCycleEnabled);

    if (newEnabled != fanCycleEnabled || newOn != fanCycleOnMs || newOff != fanCycleOffMs) {
        fanCycleEnabled = newEnabled;
        fanCycleOnMs    = newOn;
        fanCycleOffMs   = newOff;
        changed = true;
    }
    if (justEnabled) fanCycleRestart = true;
    UNLOCK();
    return changed;
}

// One-line full-state snapshot — printed periodically from loop() so you
// can watch Serial Monitor and confirm the whole system end to end without
// having to correlate a dozen scattered log lines.
void printHeartbeat() {
    LOCK();
    float t = sensorData.temperature, h = sensorData.humidity, g = sensorData.gas;
    bool f = fanOn, c = coolerOn, ht = heaterOn, u = humidifierOn;
    bool am = autoMode, sa = safetyActive, ac = appControlEnabled;
    bool cycleOn = fanCycleEnabled;
    bool cyclePhase = fanCyclePhaseOn;
    unsigned long cycleOnS = fanCycleOnMs / 1000, cycleOffS = fanCycleOffMs / 1000;
    // Snapshotted here, inside the same lock as `ac`, so the two can never
    // disagree within one printed line and send someone hunting a phantom
    // race. appOwnsControl() takes no lock of its own, so calling it here is
    // safe (and it must NOT be re-derived from `ac` by hand — duplicating
    // the formula would let this log silently drift from the real rule).
    bool ownedByApp = appOwnsControl();
    bool cloudUp    = cloudReachable();
    UNLOCK();

    const char *netState = apMode ? "AP-MODE" : (wifiOk ? "connected" : "DISCONNECTED");

    // Print EFFECTIVE ownership, not the raw appControlEnabled flag — the two
    // diverge whenever the cloud is unreachable (see appOwnsControl()), which
    // is exactly the situation someone reads this log to understand. Both are
    // shown so "the app flag says APP but the LCD is live" reads as the
    // documented handback rather than as a bug.
    const char *cloudState = cloudUp ? "reachable" : "UNREACHABLE";

    Serial.printf("[STATUS] WiFi=%s Cloud=%s T=%.1fC H=%.1f%% Gas=%.1fppm | Fan=%s Cooler=%s Heater=%s Humidifier=%s | Mode=%s Owner=%s(flag=%s)%s\n",
                  netState, cloudState, t, h, g,
                  f ? "ON" : "off", c ? "ON" : "off", ht ? "ON" : "off", u ? "ON" : "off",
                  am ? "AUTO" : "MANUAL",
                  ownedByApp ? "APP" : "LCD",
                  ac ? "APP" : "LCD",
                  sa ? " !SAFETY-ACTIVE!" : "");

    if (cycleOn) {
        Serial.printf("[STATUS]   Fan cycle ON: %s phase (schedule %lus-on/%lus-off)\n",
                      cyclePhase ? "ON" : "OFF", cycleOnS, cycleOffS);
    }
}

// Push control state to Firebase. Always actually runs on Core 0
// (firebaseTask) — either called directly from there (stream echo,
// auto-control, REST fallback) or drained from Core 1's deferred queue
// (requestControlPush(); see pendingControlPush above) — so it's the one
// place that sees every reason this device writes its own control state.
//
// Marking lastLocalControlWrite here (not just in onUiToggle()/
// onUiModeChange() as before) is what actually closes the app-echo race:
// previously, only an LCD-originated write paused the stream-drain
// cooldown below, so the device would immediately re-process its OWN
// echo of an app command (or a closely-following second app command)
// with no cooldown at all — a real self-race that looked like the
// actuator fighting itself (HW team + user, 2026-08-29 video: works once,
// then flickers on/off every ~1.5-2s from the second command onward).
// Every push from here — echo, auto-control, safety — now buys the same
// WRITE_COOLDOWN_MS quiet window the LCD path already had.
// Returns true only if the write actually landed in Firebase, so the caller
// can re-arm and retry instead of silently dropping the change.
bool pushControlToFirebase(const char *reason, bool safetyOverride) {
    if (!wifiOk) return false;
    lastLocalControlWrite = millis();
    JsonDocument doc;
    LOCK();
    doc["fanState"]          = fanOn;
    doc["coolerState"]       = coolerOn;
    doc["heaterState"]       = heaterOn;
    doc["humidifierState"]   = humidifierOn;
    doc["controlMode"]       = autoMode ? "automatic" : "manual";
    // This is a full PUT (see firebase_writeControl()), which replaces the
    // ENTIRE control/state object — appControlEnabled must be included on
    // every single push (even ones that don't change it, e.g. auto-control
    // or a safety trip) or it would be silently deleted from Firebase.
    doc["appControlEnabled"] = appControlEnabled;
    doc["reason"]         = reason;
    doc["safetyOverride"] = safetyOverride;
    UNLOCK();
    doc["updated_at"][".sv"] = "timestamp";
    return firebase_writeControl(doc);
}

// ==================== UI Callbacks (run on Core 1) ====================

void onUiToggle(int index) {
    LOCK();
    if (safetyActive) {
        UNLOCK();
        Serial.println("[UI] Toggle blocked: safety override active");
        return;
    }
    // Defense in depth — the LCD's own isActuatorLocked() already hides
    // this from being reachable while the app owns control (mirrors
    // applyControlStateDoc()'s ownership guard for the app/stream path),
    // same reasoning as the autoMode check right below it.
    if (appOwnsControl()) {
        UNLOCK();
        Serial.println("[UI] Toggle blocked: app currently owns control");
        return;
    }
    // Defense in depth — the LCD's own isActuatorLocked() already hides
    // this from being reachable while Auto is selected, but this is the
    // actual enforcement point (mirrors applyControlStateDoc()'s guard for
    // the app/stream path).
    if (autoMode) {
        UNLOCK();
        Serial.println("[UI] Toggle blocked: switch to Manual mode first");
        return;
    }
    if (index == 0 && fanCycleEnabled) {
        UNLOCK();
        Serial.println("[UI] Fan toggle blocked: cycle mode active (disable it in the app first)");
        return;
    }
    // Fan can't be turned off manually while the Cooler is on: applyStates()
    // unconditionally re-forces fanOn=true right after this (evaporative
    // cooling needs airflow, HW team 2026-08-26), so silently accepting this
    // toggle would flip fanOn for one instant and immediately snap it back -
    // logging "Toggled Fan" while nothing observable ever changes on the
    // relay or the LCD (user/HW-team report 2026-09-03). Block it here with
    // an explicit reason instead of a misleading no-op "success" log.
    if (index == 0 && coolerOn && fanOn) {
        UNLOCK();
        Serial.println("[UI] Fan toggle blocked: Cooler needs airflow (turn Cooler off first)");
        return;
    }
    switch (index) {
        case 0: fanOn        = !fanOn;        break;
        case 1: coolerOn     = !coolerOn;     break;
        case 2: heaterOn     = !heaterOn;     break;
        case 3: humidifierOn = !humidifierOn; break;
    }
    lastLocalControlWrite = millis();
    UNLOCK();
    // applyStates AFTER unlock — I2C writes must not hold the mutex
    applyStates();

    requestControlPush("Manual toggle (buttons)", false);
    Serial.printf("[UI] Toggled %s\n",
                  index==0 ? "Fan" : index==1 ? "Cooler" :
                  index==2 ? "Heater" : "Humidifier");
}

void onUiThresholdChange(int index, float value) {
    LOCK();
    switch (index) {
        case 0: thresholds.tempHigh = value; break;
        case 1: thresholds.tempLow  = value; break;
        case 2: thresholds.humHigh  = value; break;
        case 3: thresholds.humLow   = value; break;
        case 4: thresholds.gasHigh  = value; break;
    }
    lastLocalThresholdWrite = millis();
    thresholdsDirty = true;
    UNLOCK();
    Serial.printf("[UI] Threshold %d changed to %.1f\n", index, value);
}

// Called from the LCD's new Fan Cycle screen (HW team requested this be
// editable on-device, 2026-08-26 — previously app-only). Mirrors
// applyFanCycleDoc()'s "enabling fresh always restarts the ON phase" rule.
void onUiFanCycleChange(bool enabled, unsigned long onSec, unsigned long offSec) {
    LOCK();
    bool justEnabled = (enabled && !fanCycleEnabled);
    fanCycleEnabled  = enabled;
    fanCycleOnMs     = onSec  * 1000UL;
    fanCycleOffMs    = offSec * 1000UL;
    if (justEnabled) fanCycleRestart = true;
    lastLocalFanCycleWrite = millis();
    fanCycleDirty = true;
    UNLOCK();
    Serial.printf("[UI] Fan cycle changed: enabled=%d on=%lus off=%lus\n",
                  enabled, onSec, offSec);
}

// Triggered by holding SELECT for AP_RESET_HOLD_MS from any LCD screen (see
// checkApResetHold() in ui_manager.cpp). Lets a non-technical user switch
// the device to a different WiFi network using only the LCD/buttons — no
// laptop, no knowledge of the setup portal, no need to touch the router to
// force a connection failure. Just a local NVS write + restart (not network
// I/O), so it's fine to run directly on Core 1 here — mirrors the existing
// pattern in wifi_provision.cpp's handleProvision(), which does the same
// save-then-restart after a normal form submit.
void onUiApReset() {
    Serial.println("[UI] SELECT held -> wiping WiFi creds, rebooting into AP setup mode");
    Preferences prefs;
    prefs.begin("wifi_creds", false);
    prefs.putBool("force_ap", true);
    prefs.end();
    delay(300);
    ESP.restart();
}

void onUiModeChange(bool newAutoMode) {
    LOCK();
    // Defense in depth — mirrors onUiToggle()'s guard; the LCD's own
    // handleModeButtons()/isActuatorLocked() already hide the mode screen
    // from being editable while the app owns control.
    if (appOwnsControl()) {
        UNLOCK();
        Serial.println("[UI] Mode change blocked: app currently owns control");
        return;
    }
    autoMode = newAutoMode;
    lastLocalControlWrite = millis();
    UNLOCK();
    // applyStates AFTER unlock
    applyStates();
    requestControlPush(autoMode ? "Mode: AUTO (LCD)" : "Mode: MANUAL (LCD)", false);
    Serial.printf("[UI] Mode changed to %s\n", autoMode ? "AUTO" : "MANUAL");
}

// ==================== Fan Cycle (Core 1 only, WiFi-independent) ====================
// Scheduled airing: when fanCycleEnabled, the fan is driven purely by this
// ON/OFF timer, bypassing the gas/temp/humidity auto-fan logic entirely.
// Runs locally every loop() tick regardless of WiFi/Firebase state — this
// is a user-scheduled behavior, not a reactive cloud-driven one, so it
// must keep working through a network outage. Safety (checkSafety()) is
// checked first in loop() and always wins; this function double-checks
// safetyActive itself too, for the same defense-in-depth reason onUiToggle()
// re-checks it.
void evaluateFanCycle() {
    if (safetyActive) return;

    LOCK();
    bool enabled          = fanCycleEnabled;
    unsigned long onMs    = fanCycleOnMs;
    unsigned long offMs   = fanCycleOffMs;
    bool restart          = fanCycleRestart;
    UNLOCK();

    if (!enabled) return;

    unsigned long now = millis();

    if (restart) {
        LOCK();
        fanCyclePhaseOn    = true;
        fanCyclePhaseStart = now;
        fanCycleRestart    = false;
        UNLOCK();
        Serial.println("[CYCLE] Enabled — starting fresh ON phase");
    }

    LOCK();
    bool phaseOn           = fanCyclePhaseOn;
    unsigned long phaseAge = now - fanCyclePhaseStart;
    unsigned long phaseLen = phaseOn ? onMs : offMs;
    UNLOCK();

    if (phaseAge >= phaseLen) {
        phaseOn = !phaseOn;
        LOCK();
        fanCyclePhaseOn    = phaseOn;
        fanCyclePhaseStart = now;
        UNLOCK();
        Serial.printf("[CYCLE] Phase flip -> %s (next flip in %lus)\n",
                      phaseOn ? "ON" : "OFF", (phaseOn ? onMs : offMs) / 1000);
    }

    // The Cooler needs airflow to function at all — applyStates() enforces
    // this unconditionally (`if (coolerOn) fanOn = true;`), which silently
    // overrides whatever this function sets fanOn to. Without accounting
    // for that here too, a cycle OFF phase while the Cooler is on created a
    // perpetual fight: this function sets fanOn=false and pushes "OFF
    // phase" to the cloud, applyStates() immediately flips it back to true
    // inside that same call because the Cooler is still on, then the very
    // next loop() tick (~10ms later) sees fanOn(true) != phaseOn(false)
    // again and repeats — a real on/off/on/off flicker on the relay plus a
    // Firebase PUT roughly every 50ms for as long as it ran (HW team,
    // 2026-08-29: "Fan keeps turning on and off by itself, and switching
    // to Automatic keeps snapping back to Manual" — that second symptom
    // was this same push flood racing/undoing the app's own mode-switch
    // write with a stale echo). Computing the SAME final value applyStates()
    // will actually produce keeps this function's own change-detection
    // truthful, so there's nothing left to fight on the next tick.
    LOCK();
    bool coolerNeedsFan = coolerOn;
    bool desiredFan     = coolerNeedsFan ? true : phaseOn;
    bool changed        = (fanOn != desiredFan);
    if (changed) fanOn = desiredFan;
    UNLOCK();

    if (changed) {
        applyStates();
        char reason[48];
        if (coolerNeedsFan) {
            snprintf(reason, sizeof(reason), "Fan: ON (Cooler needs airflow)");
        } else {
            snprintf(reason, sizeof(reason), "Fan cycle: %s phase", phaseOn ? "ON" : "OFF");
        }
        Serial.printf("[CYCLE] %s\n", reason);
        requestControlPush(reason, false);
    }
}

// ==================== Auto-control (Core 1 only, WiFi-independent) ====================
// Sensor-driven actuator control while Auto mode is selected.
//
// This used to live inside firebaseTask() on Core 0, *below* that task's
// `if (!wifiOk) { delay; continue; }` gate — so Auto silently stopped
// driving anything the moment WiFi dropped, and never ran at all on a
// device that booted straight into AP provisioning mode (firebaseTask is
// only launched on the wifiOk branch of setup()). Offline, that left the
// device fully inert: Auto locks out LCD/manual control by design, and
// nothing was driving the relays in its place — which is exactly the
// "control doesn't work when the firmware isn't on WiFi" report
// (user/HW team, 2026-09-02).
//
// Nothing here actually needs the network: sensors_evaluate() is pure
// computation, and the resulting cloud push goes through
// requestControlPush()'s Core1->Core0 queue, which simply drains once WiFi
// is back. So it belongs on Core 1 next to evaluateFanCycle(), for the
// same reason stated in that function's comment.
void evaluateAutoControl() {
    static unsigned long lastAutoCtrl = 0;
    unsigned long now = millis();
    if (now - lastAutoCtrl < CONTROL_INTERVAL) return;
    lastAutoCtrl = now;

    // Same guard checkSafety()/checkComfortAlerts() use — never act on an
    // all-zero SensorData before the first read has landed.
    if (!sensorReady) return;

    // No more manual-priority pause to check — actuators can't be manually
    // toggled while Auto is active at all now (enforced in
    // applyControlStateDoc()/onUiToggle()), so auto-control always runs
    // unconditionally whenever Auto+not-safety.
    if (!autoMode || safetyActive) return;

    ControlAction action;
    SensorData    sd;
    Thresholds    th;
    ActuatorState curr;
    LOCK();
    sd   = sensorData;
    th   = thresholds;
    curr.fan        = fanOn;
    curr.heater     = heaterOn;
    curr.cooler     = coolerOn;
    curr.humidifier = humidifierOn;
    bool cycleOwnsFan = fanCycleEnabled;
    UNLOCK();

    sensors_evaluate(&sd, &th, &curr, &action);

    // While a fan cycle is running, it owns the fan exclusively —
    // evaluateFanCycle() drives it; don't let gas/temp/humidity logic
    // fight over it here. Heater/Cooler/Humidifier are unaffected either way.
    if (cycleOwnsFan) action.fan = curr.fan;

    bool needed = (action.fan        != curr.fan)
               || (action.heater     != curr.heater)
               || (action.cooler     != curr.cooler)
               || (action.humidifier != curr.humidifier);
    if (!needed) return;

    LOCK();
    fanOn        = action.fan;
    heaterOn     = action.heater;
    coolerOn     = action.cooler;
    humidifierOn = action.humidifier;
    UNLOCK();
    applyStates();  // After unlock

    Serial.printf("[AUTO] %s -> Fan=%d Heater=%d Cooler=%d Humidifier=%d\n",
                  action.reason, action.fan, action.heater,
                  action.cooler, action.humidifier);
    // Deferred, not a direct pushControlToFirebase(): Core 1 must never
    // block on network I/O, and while offline this queues the result until
    // WiFi returns instead of being dropped by pushControlToFirebase()'s
    // own `if (!wifiOk) return`.
    requestControlPush(action.reason, false);
}

// ==================== Safety Overrides (Core 1 only) ====================

// Every branch below sets ALL FOUR actuators explicitly (never leaves one
// implicit/unchanged) — during a hard safety event we want fully
// deterministic, unambiguous state, not "whatever it happened to be before".
bool checkSafety() {
    if (!sensorReady) return false;

    LOCK();
    safetyActive = false;

    // 1. GAS — max ventilation only, everything else off (no heat source,
    // no reason to run cooler/humidifier while venting dangerous air).
    if (sensorData.gas > GAS_ABS_MAX) {
        safetyActive = true;
        fanOn = true; heaterOn = false; coolerOn = false; humidifierOn = false;
        UNLOCK();
        applyStates();  // I2C after unlock
        Serial.printf("[SAFETY] GAS %.1fppm > %.1f\n", sensorData.gas, GAS_ABS_MAX);
        requestControlPush("SAFETY: Dangerous gas level", true);
        if (alertReady(A_GAS)) {
            char msg[80];
            snprintf(msg, sizeof(msg), "Gas %.1fppm > %.1fppm", sensorData.gas, GAS_ABS_MAX);
            requestAlert("gas_critical", "critical", msg, sensorData.gas, GAS_ABS_MAX);
        }
        return true;
    }

    // 2. EXTREME COLD — heat only, no ventilation/cooling, no added humidity
    // (retaining warm air matters most; humidity can worsen chill).
    if (sensorData.temperature < TEMP_ABS_MIN) {
        safetyActive = true;
        fanOn = false; heaterOn = true; coolerOn = false; humidifierOn = false;
        UNLOCK();
        applyStates();
        Serial.printf("[SAFETY] COLD %.1fC < %.1f\n", sensorData.temperature, TEMP_ABS_MIN);
        requestControlPush("SAFETY: Critical cold", true);
        if (alertReady(A_TEMP_LO)) {
            char msg[80];
            snprintf(msg, sizeof(msg), "Temp %.1fC < %.1fC", sensorData.temperature, TEMP_ABS_MIN);
            requestAlert("temp_critical_low", "critical", msg, sensorData.temperature, TEMP_ABS_MIN);
        }
        return true;
    }

    // 3. EXTREME HEAT — cooler + fan for max cooling/airflow, heater off,
    // no added humidity (humidity worsens heat stress on birds).
    if (sensorData.temperature > TEMP_ABS_MAX) {
        safetyActive = true;
        fanOn = true; heaterOn = false; coolerOn = true; humidifierOn = false;
        UNLOCK();
        applyStates();
        Serial.printf("[SAFETY] HEAT %.1fC > %.1f\n", sensorData.temperature, TEMP_ABS_MAX);
        requestControlPush("SAFETY: Critical heat", true);
        if (alertReady(A_TEMP_HI)) {
            char msg[80];
            snprintf(msg, sizeof(msg), "Temp %.1fC > %.1fC", sensorData.temperature, TEMP_ABS_MAX);
            requestAlert("temp_critical_high", "critical", msg, sensorData.temperature, TEMP_ABS_MAX);
        }
        return true;
    }

    // 4. LOW HUMIDITY — humidifier directly addresses it now; fan/heater off
    // since both would dry the air further, working against recovery.
    if (sensorData.humidity < HUM_ABS_MIN) {
        safetyActive = true;
        fanOn = false; heaterOn = false; coolerOn = false; humidifierOn = true;
        UNLOCK();
        applyStates();
        if (alertReady(A_HUM_LO)) {
            char msg[80];
            snprintf(msg, sizeof(msg), "Critical low humidity: %.1f%%", sensorData.humidity);
            requestAlert("hum_critical_low", "critical", msg, sensorData.humidity, HUM_ABS_MIN);
        }
        requestControlPush("SAFETY: Critical low humidity", true);
        return true;
    }

    // 5. HIGH HUMIDITY — fan ventilates moist air out; heater stays off
    // (heating already-humid air worsens heat stress at >85% RH); no
    // active cooling or humidifying needed for this specific emergency.
    if (sensorData.humidity > HUM_ABS_MAX) {
        safetyActive = true;
        fanOn = true; heaterOn = false; coolerOn = false; humidifierOn = false;
        UNLOCK();
        applyStates();
        if (alertReady(A_HUM_HI)) {
            char msg[80];
            snprintf(msg, sizeof(msg), "Critical high humidity: %.1f%%", sensorData.humidity);
            requestAlert("hum_critical_high", "critical", msg, sensorData.humidity, HUM_ABS_MAX);
        }
        requestControlPush("SAFETY: Critical high humidity", true);
        return true;
    }

    UNLOCK();
    return false;
}

// ==================== Comfort Range Alerts (Core 1 only) ====================
// checkSafety() above only alerts on the hardcoded, deliberately wide ABS
// limits (death/heat-stroke/mold-type emergencies) — it never looks at the
// farm owner's own configured Range (config/thresholds — the same
// tempHigh/tempLow/humHigh/humLow/gasHigh values sensors_evaluate() uses
// for auto-control). A reading could sit outside that Range indefinitely
// and nothing would ever notify anyone unless it also blew through the
// much-further-out ABS ceiling (HW team/user, 2026-08-30: configurable
// out-of-range notifications were requested as a real, previously-missing
// feature). This fires a "warning"-severity alert — separate cooldown
// slots from checkSafety()'s "critical" ones — whenever a reading is
// outside the user's own Range. Only ever called from loop() after
// checkSafety() has already confirmed we're not in a hard safety state,
// so every reading here is implicitly still within the ABS limits.
// One alert per call, mirroring checkSafety()'s style: requestAlert()'s
// pending slot can only hold one alert at a time, and the very next tick
// re-checks whatever this call skipped, so nothing is lost, just staggered
// by a few milliseconds.
void checkComfortAlerts() {
    if (!sensorReady) return;

    LOCK();
    SensorData sd = sensorData;
    Thresholds th = thresholds;
    UNLOCK();

    char msg[80];

    if (sd.temperature > th.tempHigh) {
        if (alertReady(A_TEMP_HI_WARN)) {
            snprintf(msg, sizeof(msg), "Temp %.1fC above your %.1fC limit",
                     sd.temperature, th.tempHigh);
            requestAlert("temperature_high", "warning", msg, sd.temperature, th.tempHigh);
        }
        return;
    }
    if (sd.temperature < th.tempLow) {
        if (alertReady(A_TEMP_LO_WARN)) {
            snprintf(msg, sizeof(msg), "Temp %.1fC below your %.1fC limit",
                     sd.temperature, th.tempLow);
            requestAlert("temperature_low", "warning", msg, sd.temperature, th.tempLow);
        }
        return;
    }
    if (sd.humidity > th.humHigh) {
        if (alertReady(A_HUM_HI_WARN)) {
            snprintf(msg, sizeof(msg), "Humidity %.1f%% above your %.1f%% limit",
                     sd.humidity, th.humHigh);
            requestAlert("humidity_high", "warning", msg, sd.humidity, th.humHigh);
        }
        return;
    }
    if (sd.humidity < th.humLow) {
        if (alertReady(A_HUM_LO_WARN)) {
            snprintf(msg, sizeof(msg), "Humidity %.1f%% below your %.1f%% limit",
                     sd.humidity, th.humLow);
            requestAlert("humidity_low", "warning", msg, sd.humidity, th.humLow);
        }
        return;
    }
    if (sd.gas > th.gasHigh) {
        if (alertReady(A_GAS_WARN)) {
            snprintf(msg, sizeof(msg), "Gas %.1fppm above your %.1fppm limit",
                     sd.gas, th.gasHigh);
            requestAlert("gas_detected", "warning", msg, sd.gas, th.gasHigh);
        }
        return;
    }
}

// ==================== Streaming Callback ====================
// Called from firebase_stream_loop() (Core 0 context) when RTDB pushes a
// 'put' or 'patch' event. Path is relative to the streamed root, which is
// this device's /control node (NOT the whole /farm tree — see the comment
// in streamSubscribe() for why).
//
// Examples we handle:
//   path="/"                            put: initial snapshot, {"state":{...}}
//   path="/state"                       put: full state replaced
//   path="/state/fanState"              put: single field changed
//   path="/state"                       patch: partial update of fields
//                                        (e.g. the app's actuator toggle —
//                                        only the touched field is present;
//                                        merged onto current state, not
//                                        treated as the whole object)
//
// Thresholds and fan cycle are not delivered here — they're polled via
// REST in firebaseTask instead (they change rarely, so 30s latency is
// fine, and it keeps this stream subscribed to nothing but the small,
// non-growing /control node).

#if USE_STREAMING

static void onStreamEvent(const char *eventType, const char *path,
                          JsonDocument &data) {
    Serial.printf("[STREAM] %s %s\n", eventType, path);

    // Initial subscription event: path="/" with the whole /control subtree.
    if (strcmp(path, "/") == 0) {
        JsonVariantConst st = data["state"];
        if (!st.isNull()) {
            JsonDocument d;
            d.set(st);
            ControlApplyResult r = applyControlStateDoc(d);
            if (r.modeChanged || r.stateChanged) applyStates();
        }
        Serial.println("[STREAM] Initial control state hydrated from snapshot");
        return;
    }

    // ---- Control state changes ----
    if (strncmp(path, "/state", 6) == 0) {
        // ALWAYS seed from current local state, then merge whatever this
        // event actually contains on top — NEVER assume the payload is the
        // complete object. Firebase's "patch" events (delivered for the
        // app's per-actuator toggle, which does a partial `.update({...})`
        // with just the one changed field) only include the field(s) that
        // actually changed. A previous version of this branch treated any
        // payload landing exactly at "/state" as if it were the FULL state
        // object — so a patch containing only {"fanState":true} left every
        // other field (including controlMode) to fall back to
        // applyControlStateDoc()'s JSON-parse default, and controlMode
        // defaults to "automatic". That silently flipped the device out of
        // Manual mode on every single app toggle, and a few seconds later
        // auto-control (now wrongly active) would revert the actuator based
        // on sensor readings — looked like the actuator oscillating
        // on/off/on/off as the user kept re-pressing it. Merging onto the
        // current state instead is correct for BOTH a real "put" full
        // replace (overlaying a complete object onto itself is a no-op
        // beyond the overlay) and a "patch" partial merge (only the sent
        // fields change, everything else rightfully stays as it was).
        JsonDocument doc;
        LOCK();
        doc["fanState"]          = fanOn;
        doc["coolerState"]       = coolerOn;
        doc["heaterState"]       = heaterOn;
        doc["humidifierState"]   = humidifierOn;
        doc["controlMode"]       = autoMode ? "automatic" : "manual";
        // Seed this too, same reasoning as the fields above — a patch that
        // doesn't mention appControlEnabled must NOT fall back to
        // applyControlStateDoc()'s default (true), or a patch sent while
        // the LCD owns control (appControlEnabled==false) would silently
        // hand control back to the app on every unrelated field change.
        doc["appControlEnabled"] = appControlEnabled;
        UNLOCK();

        if (strcmp(path, "/state") == 0) {
            JsonObjectConst obj = data.as<JsonObjectConst>();
            for (JsonPairConst kv : obj) {
                doc[kv.key().c_str()] = kv.value();
            }
        } else {
            const char *field = path + 6; // skip "/state"
            if (*field == '/') field++;
            doc[field] = data.as<JsonVariantConst>();
        }

        ControlApplyResult r = applyControlStateDoc(doc);
        if (r.modeChanged) {
            applyStates();
            Serial.printf("[MODE] Stream: changed to %s\n",
                          autoMode ? "AUTO" : "MANUAL");
        }
        if (r.stateChanged) {
            // Can only happen when the resulting mode is MANUAL —
            // applyControlStateDoc() ignores actuator fields entirely
            // while Auto (see its own comment). No more "manual override
            // while auto" concept to branch on here.
            bool reqFan, reqCooler, reqHeater, reqHumidifier;
            LOCK();
            reqFan = fanOn; reqCooler = coolerOn;
            reqHeater = heaterOn; reqHumidifier = humidifierOn;
            UNLOCK();

            applyStates();
            Serial.printf("[MANUAL] Stream: F=%d H=%d C=%d U=%d\n",
                          fanOn, heaterOn, coolerOn, humidifierOn);

            // applyStates() can silently correct what was actually applied
            // beyond what the app asked for — e.g. turning the Cooler on
            // also forces the Fan on (needs airflow to work at all), and
            // Heater+Cooler both requested at once forces both off. Those
            // corrections only ever happened in local memory + on the
            // physical relay; nothing told the cloud, so the app kept
            // showing the OLD Fan state forever. Push the corrected state
            // back ONLY when applyStates() actually changed something
            // beyond what was requested — the app/LCD that sent this
            // command already wrote its own requested value to Firebase
            // itself, so re-pushing an uncorrected value is pure echo with
            // nothing new to say.
            //
            // Confirmed live (2026-08-30) this echo was the actual cause of
            // a self-sustaining on/off/on/off loop that never converged on
            // its own: pushing unconditionally, SYNCHRONOUSLY, from inside
            // this callback — itself called from firebase_stream_loop()'s
            // drain — means the push's own echo can arrive and get drained
            // within the same or a following call before this event's
            // dust has settled. A single command has nothing to race and
            // looked fine; a second command arriving before the first
            // command's now-provably-unnecessary echo had cleared the pipe
            // raced it — the echo (a FULL "put", carrying every field) then
            // re-asserted the pre-second-command snapshot as if it were a
            // new incoming command, flipped it back, pushed again, and so
            // on, forever, until the device was rebooted. Never pushing
            // when there's nothing to correct removes the echo at its
            // source rather than trying to out-time it. What IS pushed now
            // goes through requestControlPush() (deferred to the top of
            // the next firebaseTask iteration, after this drain call has
            // fully returned) rather than a synchronous call from inside
            // the drain, so even a genuine correction can't race whatever
            // else was still queued behind the event that triggered it.
            LOCK();
            bool corrected = (fanOn != reqFan) || (coolerOn != reqCooler) ||
                             (heaterOn != reqHeater) || (humidifierOn != reqHumidifier);
            UNLOCK();
            if (corrected) {
                requestControlPush("Manual command applied (app)", false);
            }
        }
        return;
    }
}

// (Re)open the streaming subscription. Called from setup() and on
// firebase_stream_loop() failure inside firebaseTask.
static unsigned long g_lastStreamReconnect = 0;
static void streamSubscribe() {
    // Throttle reconnect attempts to avoid hammering the server
    if (millis() - g_lastStreamReconnect < 5000) return;
    g_lastStreamReconnect = millis();

    // Subscribe to farm/control only — not the whole /farm tree (the old
    // behavior). Firebase always sends the entire subtree at
    // the subscribed path as one line on connect; /farm also contains
    // sensors/history (appended to by the app) and alerts, which grow
    // without bound, so a fixed SSE line buffer eventually overflows no
    // matter how large it's made (this one had already been bumped
    // 1024->8192->16384 bytes and was still overflowing every few seconds —
    // see firebase_stream.cpp). Each overflow tears down and rebuilds a
    // ~40KB TLS session, and that churn was the leading suspect for
    // heap-corruption reboots. /control is a small, fixed-shape object that
    // never grows, and it's the only part of the tree that genuinely needs
    // sub-500ms push latency — thresholds/fanCycle/timeout are now polled
    // via REST in firebaseTask instead (see below).
    //
    // Always flat (matches firebase_init() in firebase_client.cpp — see the
    // comment there for why deviceId must never be part of any Firebase
    // path here, only ever a label).
    String url(appCfg.firebaseUrl);
    url += "/";
    url += appCfg.firebasePath;
    url += "/control.json";

    Serial.printf("[STREAM] Subscribing to %s\n", url.c_str());
    if (!firebase_stream_begin(url.c_str(), appCfg.firebaseToken,
                                onStreamEvent)) {
        Serial.println("[STREAM] Subscribe failed; will retry");
    }
}

#endif // USE_STREAMING

// ==================== Firebase Task (Core 0) ====================
// All blocking HTTPS calls happen here. Core 1 (loop) is never blocked.

void firebaseTask(void *param) {
    unsigned long lastSync       = 0;
    unsigned long lastStatePoll  = 0;
    unsigned long lastThreshPoll = 0;
    unsigned long lastWatermark  = 0;

    Serial.println("[RTOS] Firebase task started on core 0");

    for (;;) {
        unsigned long now = millis();

        // OTA upload handling lives here (Core 0), not in loop() (Core 1) —
        // a firmware upload legitimately blocks for its whole transfer, and
        // Core 1 must stay responsive for safety/UI. Cheap no-op call when
        // no client is connected.
        ota_handle();

        // ---- Periodic stack watermark — catch impending stack overflow ----
        if (now - lastWatermark >= 60000) {
            lastWatermark = now;
            UBaseType_t hwm = uxTaskGetStackHighWaterMark(NULL);
            Serial.printf("[RTOS] Firebase task stack HWM: %u bytes free\n",
                          hwm * sizeof(StackType_t));
            if (hwm * sizeof(StackType_t) < 1024) {
                Serial.println("[RTOS] WARNING: Stack near overflow! Increase FIREBASE_TASK_STACK_BYTES");
            }
        }

        // Skip all Firebase ops while WiFi is down; retry in next cycle
        if (!wifiOk) {
            vTaskDelay(pdMS_TO_TICKS(5000));
            continue;
        }

        // ---- Flush deferred pushes queued by Core 1 (buttons/safety/cycle) ----
        // Core 1 never blocks on network I/O itself (see requestControlPush()/
        // requestAlert() near the top of this file) — this task does the
        // actual blocking HTTPS call on its behalf.
        // pushRetryPending distinguishes a FRESH push (always attempted at
        // once — a button press must reach the cloud in milliseconds) from a
        // RETRY of one that already failed, which is throttled to
        // CONTROL_PUSH_RETRY_MS. See that macro for why the brake is needed.
        static bool          pushRetryPending = false;
        static unsigned long lastFailedPushAt = 0;
        if (pendingControlPush &&
            (!pushRetryPending ||
             (millis() - lastFailedPushAt) >= CONTROL_PUSH_RETRY_MS)) {
            pendingControlPush = false;
            if (pushControlToFirebase(pendingPushReason, pendingPushSafetyOverride)) {
                pushRetryPending = false;
            } else {
                // The write did NOT land — WAN down, TLS timeout, 5xx. Clearing
                // the flag unconditionally (as this used to) silently threw the
                // change away, so the cloud kept holding the app's older state;
                // on recovery the stream then replayed that stale state back and
                // reverted whatever the user had just done at the LCD during the
                // outage. Re-arm so it retries — same dirty-flag idiom as
                // thresholdsDirty/fanCycleDirty below.
                //
                // Guarded: if Core 1 queued a NEWER push while this call was
                // blocked (up to ~5s), the flag is already set with a fresher
                // reason — do not clobber it. Either way the retry re-reads live
                // state, so what eventually lands is always current.
                if (!pendingControlPush) pendingControlPush = true;
                pushRetryPending = true;
                lastFailedPushAt = millis();  // AFTER the call, which may have blocked
            }
        }
        if (pendingAlert) {
            pendingAlert = false;
            firebase_sendAlert(pendingAlertType, pendingAlertSeverity, pendingAlertMsg,
                                pendingAlertValue, pendingAlertThreshold);
            // Push notification, straight to OneSignal — independent of the
            // Firebase write above (no Cloud Function in between). A no-op
            // if ONESIGNAL_APP_ID/ONESIGNAL_REST_API_KEY aren't configured.
            onesignal_sendAlert(alertPushTitle(pendingAlertType), pendingAlertMsg);
        }

        // ---- 0. Flush local threshold edits to cloud (Core 0 only) ----
        if (thresholdsDirty) {
            float th, tl, hh, hl, gh;
            LOCK();
            th = thresholds.tempHigh;
            tl = thresholds.tempLow;
            hh = thresholds.humHigh;
            hl = thresholds.humLow;
            gh = thresholds.gasHigh;
            UNLOCK();

            if (firebase_writeThresholds(th, tl, hh, hl, gh)) {
                thresholdsDirty = false;
                Serial.printf("[THRESH] Local->Cloud: T(%.0f-%.0f) H(%.0f-%.0f) G(%.0f)\n",
                              tl, th, hl, hh, gh);
            }
        }

        // ---- 0b. Flush local fan cycle edits to cloud (LCD screen, Core 0 only) ----
        if (fanCycleDirty) {
            bool en;
            unsigned long onS, offS;
            LOCK();
            en   = fanCycleEnabled;
            onS  = fanCycleOnMs  / 1000UL;
            offS = fanCycleOffMs / 1000UL;
            UNLOCK();

            if (firebase_writeFanCycle(en, onS, offS)) {
                fanCycleDirty = false;
                Serial.printf("[CYCLE] Local->Cloud: enabled=%d on=%lus off=%lus\n",
                              en, onS, offS);
            }
        }

        // ---- 1. Send sensor readings to Firebase ----
        if (now - lastSync >= FIREBASE_INTERVAL) {
            lastSync = now;
            LOCK();
            float t = sensorData.temperature;
            float h = sensorData.humidity;
            float g = sensorData.gas;
            UNLOCK();
            firebase_sendSensors(t, h, g);
            firebase_updateStatus(true);  // heartbeat: updates meta.lastSeen
        }

#if !USE_STREAMING
        // ---- 2. Poll control state from Firebase (REST fallback) ----
        if ((now - lastStatePoll >= STATE_INTERVAL)
            && (now - lastLocalControlWrite >= WRITE_COOLDOWN_MS)) {
            lastStatePoll = now;

            JsonDocument doc;
            if (firebase_read("control/state", doc)) {
                ControlApplyResult r = applyControlStateDoc(doc);
                if (r.modeChanged) {
                    applyStates();
                    Serial.printf("[MODE] Changed to %s\n", autoMode ? "AUTO" : "MANUAL");
                }
                if (r.stateChanged) {
                    // Can only happen when the resulting mode is MANUAL —
                    // applyControlStateDoc() ignores actuator fields
                    // entirely while Auto.
                    bool reqFan, reqCooler, reqHeater, reqHumidifier;
                    LOCK();
                    reqFan = fanOn; reqCooler = coolerOn;
                    reqHeater = heaterOn; reqHumidifier = humidifierOn;
                    UNLOCK();

                    applyStates();
                    Serial.printf("[MANUAL] Applied from app: F=%d H=%d C=%d U=%d\n",
                                  fanOn, heaterOn, coolerOn, humidifierOn);
                    // See the matching comment in onStreamEvent() — only push
                    // back when applyStates() actually corrected something
                    // beyond what was requested (Cooler forces Fan on,
                    // Heater+Cooler both on forces both off). An uncorrected
                    // push here is pure echo of what the app already wrote
                    // itself, and confirmed live (2026-08-30) to be able to
                    // sustain a self-reinforcing on/off loop when a second
                    // command lands before its echo clears.
                    LOCK();
                    bool corrected = (fanOn != reqFan) || (coolerOn != reqCooler) ||
                                     (heaterOn != reqHeater) || (humidifierOn != reqHumidifier);
                    UNLOCK();
                    if (corrected) {
                        requestControlPush("Manual command applied (app)", false);
                    }
                }
            }
        }
#else
        // ---- 2. Drain RTDB stream events for /control (sub-500ms latency) ----
        // Previously gated on "now - lastLocalControlWrite >= WRITE_COOLDOWN_MS"
        // to skip draining for 3s after any local push, on the theory that this
        // avoided re-processing our own echo. That gate only guarded the ENTRY
        // into firebase_stream_loop() — once inside, its own while(available())
        // loop drains everything currently buffered regardless, so a push
        // triggered from inside a drain (onStreamEvent -> pushControlToFirebase)
        // never actually got the cooldown's protection anyway. Meanwhile it DID
        // block every genuine incoming command for up to 3s after every local
        // write (including our own echo-confirmation push), which is what made
        // real app commands look laggy/queued. The actual echo protection is
        // (and always was) applyControlStateDoc()'s content-based diff — it
        // seeds from current local state and only reports stateChanged when a
        // field actually differs, so a true echo of our own write is already a
        // guaranteed no-op there. Drain unconditionally; nothing left to gate.
        if (!firebase_stream_loop()) {
            // Connection died — try to reconnect (called outside any mutex)
            streamSubscribe();
        }
#endif

        // ---- 3. Poll thresholds + fan cycle ----
        // Runs regardless of USE_STREAMING: the stream (when enabled) is now
        // narrowed to just /control (see streamSubscribe()), so these are
        // never pushed in realtime — only polled. They change rarely (user
        // editing settings), so this interval is fine.
        if ((now - lastThreshPoll >= THRESHOLD_POLL_INTERVAL)
            && (now - lastLocalThresholdWrite >= WRITE_COOLDOWN_MS)) {
            lastThreshPoll = now;

            JsonDocument tDoc;
            if (firebase_read("config/thresholds", tDoc)) {
                if (applyThresholdsDoc(tDoc)) {
                    // Cloud values applied; clear dirty flag so we don't echo
                    // them back on the next flush (app's write wins).
                    thresholdsDirty = false;
                    Serial.printf("[THRESH] Cloud: T(%.0f-%.0f) H(%.0f-%.0f) G(%.0f)\n",
                                  thresholds.tempLow, thresholds.tempHigh,
                                  thresholds.humLow, thresholds.humHigh,
                                  thresholds.gasHigh);
                }
            }

            if (now - lastLocalFanCycleWrite >= WRITE_COOLDOWN_MS) {
                JsonDocument fcDoc;
                if (firebase_read("config/fanCycle", fcDoc)) {
                    if (applyFanCycleDoc(fcDoc)) {
                        fanCycleDirty = false;
                        Serial.printf("[CYCLE] Cloud: enabled=%d on=%lus off=%lus\n",
                                      fanCycleEnabled, fanCycleOnMs / 1000UL,
                                      fanCycleOffMs / 1000UL);
                    }
                }
            }
        }

        vTaskDelay(pdMS_TO_TICKS(50));  // Yield to other tasks
    }
}

// ==================== WiFi diagnostics ====================

static const char *wifiStatusName(wl_status_t s) {
    switch (s) {
        case WL_IDLE_STATUS:     return "IDLE_STATUS";
        case WL_NO_SSID_AVAIL:   return "NO_SSID_AVAIL (target not seen in range)";
        case WL_SCAN_COMPLETED:  return "SCAN_COMPLETED";
        case WL_CONNECTED:       return "CONNECTED";
        case WL_CONNECT_FAILED:  return "CONNECT_FAILED (usually wrong password)";
        case WL_CONNECTION_LOST: return "CONNECTION_LOST";
        case WL_DISCONNECTED:    return "DISCONNECTED";
        default:                 return "UNKNOWN";
    }
}

static const char *wifiEncName(wifi_auth_mode_t enc) {
    switch (enc) {
        case WIFI_AUTH_OPEN:            return "OPEN";
        case WIFI_AUTH_WEP:             return "WEP";
        case WIFI_AUTH_WPA_PSK:         return "WPA-PSK";
        case WIFI_AUTH_WPA2_PSK:        return "WPA2-PSK";
        case WIFI_AUTH_WPA_WPA2_PSK:    return "WPA/WPA2-PSK";
        case WIFI_AUTH_WPA2_ENTERPRISE: return "WPA2-ENTERPRISE (not supported)";
        case WIFI_AUTH_WPA3_PSK:        return "WPA3-PSK";
        case WIFI_AUTH_WPA2_WPA3_PSK:   return "WPA2/WPA3-PSK";
        default:                        return "?";
    }
}

// Scan and print every visible network before attempting to connect — lets
// us tell "wrong password" apart from "SSID not in range/wrong band/typo"
// from Serial alone instead of guessing.
static bool wifiScanForTarget(const char *targetSsid) {
    Serial.println("[WIFI] Scanning for networks...");
    int n = WiFi.scanNetworks();
    bool found = false;
    if (n <= 0) {
        Serial.println("[WIFI] Scan found NOTHING — check antenna/radio.");
        return false;
    }
    for (int i = 0; i < n; i++) {
        bool isTarget = WiFi.SSID(i) == String(targetSsid);
        if (isTarget) found = true;
        Serial.printf("[WIFI]   %s\"%s\" RSSI=%ddBm Ch=%d Enc=%s\n",
                      isTarget ? "-> " : "   ",
                      WiFi.SSID(i).c_str(), WiFi.RSSI(i), WiFi.channel(i),
                      wifiEncName(WiFi.encryptionType(i)));
    }
    if (!found) {
        Serial.printf("[WIFI] WARNING: target SSID \"%s\" NOT in scan results — "
                      "check for a typo, 5GHz-only band (ESP32 is 2.4GHz-only), "
                      "or that the AP is in range.\n", targetSsid);
    }
    WiFi.scanDelete();
    return found;
}

// ---- Recovery out of AP provisioning mode ----
// setup() gives the stored network 20s (40 x 500ms) and then latches
// apMode, and until now that latch was permanent: loop()'s AP branch
// returns early, so nothing ever re-tested WiFi again. Only re-provisioning
// or another power cycle got the device out.
//
// That 20s window is routinely missed for reasons that have nothing to do
// with the stored credentials being wrong or unsaved. After a real power
// cut everything comes back at once and the ESP32 is up in ~2s, while the
// router / phone hotspot it is waiting for can take far longer to start
// accepting clients. The device then sat in the setup portal showing
// WiFi-X and demanding the network be entered again - while the hotspot's
// own client list showed it associated, because the WiFi driver keeps
// retrying in the background and softAP() over a live STA leaves the radio
// in AP_STA, so the station really does come up late (HW team, 2026-09-03:
// "it needs me to enter the network again and doesn't save it, and shows X
// even though my hotspot shows it connected"). The credentials were in NVS
// the whole time.
//
// Recovery is a restart rather than an in-place STA transition: the
// credentials are already stored and the network is now up, so the next
// boot simply takes the normal, already-tested wifiOk path in setup()
// (firebase_init / sendMeta / updateStatus / ota_start / streamSubscribe /
// firebaseTask) instead of duplicating all of that here against
// half-initialised state.
static void checkApLateConnect() {
    // Nothing to recover to: never provisioned, or the user deliberately
    // asked for the portal via the SELECT hold. Neither called WiFi.begin(),
    // so there is no pending association to wait on.
    if (!staCredsTried) return;

    // Never reboot out from under someone using the setup page - they may
    // be halfway through typing a password for a DIFFERENT network, which
    // is the whole point of the portal being up.
    unsigned long lastReq = provision_lastRequestMs();
    if (lastReq != 0 && (millis() - lastReq) < AP_PORTAL_IDLE_MS) return;

    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("[WIFI] Late connect to \"%s\" while in AP mode (IP %s) - "
                      "credentials were fine, the network just came up after "
                      "setup()'s 20s window. Restarting into STA mode.\n",
                      appCfg.wifiSsid, WiFi.localIP().toString().c_str());
        delay(300);
        ESP.restart();
    }

    // Re-arm the attempt periodically instead of trusting the driver's own
    // auto-reconnect, which stops for some disconnect reasons - notably
    // NO_SSID_AVAIL, i.e. precisely the "the AP was not there yet" case
    // this whole function exists for.
    static unsigned long lastRetry = 0;
    if (millis() - lastRetry >= AP_STA_RETRY_MS) {
        lastRetry = millis();
        Serial.printf("[WIFI] AP mode: retrying stored network \"%s\" (status=%s)\n",
                      appCfg.wifiSsid, wifiStatusName(WiFi.status()));
        WiFi.begin(appCfg.wifiSsid, appCfg.wifiPass);
    }
}

// ==================== Setup ====================

void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("\n================================");
    Serial.println("  Lotus Power - Poultry Farm");
    Serial.println("  FreeRTOS dual-core firmware");
    Serial.println("================================\n");

    stateMutex = xSemaphoreCreateMutex();

    // ---- Init hardware ----
    // I2C bus — LCD only now (temp/humidity sensor is single-wire, see
    // sensors_init()/DHT_PIN) — started once, here.
    Wire.begin(I2C_SDA, I2C_SCL, 100000);
    cmd_init();
    sensors_init();

    sensorData.temperature = 22.0f;
    sensorData.humidity    = 55.0f;
    sensorData.gas         = 0.0f;

    config_load(&appCfg);

    ui_init();
    ui_onToggle(onUiToggle);
    ui_onThresholdChange(onUiThresholdChange);
    ui_onModeChange(onUiModeChange);
    ui_onFanCycleChange(onUiFanCycleChange);
    ui_onApReset(onUiApReset);

    thresholds.tempHigh   = TEMP_HIGH;
    thresholds.tempLow    = TEMP_LOW;
    thresholds.humHigh    = HUM_HIGH;
    thresholds.humLow     = HUM_LOW;
    thresholds.gasHigh    = GAS_HIGH;
    thresholds.hysteresis = HYSTERESIS;
    ui_setThresholds(&thresholds);

    // ---- Connect WiFi ----
    // forceApMode (set by a long SELECT hold on the previous boot, see
    // onUiApReset() below) skips straight to the AP-provisioning branch
    // below without even attempting the old network — reuses that branch
    // completely unchanged, same as it already does for "no creds saved".
    bool hasCreds = (strlen(appCfg.wifiSsid) > 0 &&
                     strcmp(appCfg.wifiSsid, "YOUR_WIFI_SSID") != 0) &&
                    !appCfg.forceApMode;

    if (hasCreds) {
        staCredsTried = true;
        // We keep the credentials ourselves, in the "wifi_creds" NVS
        // namespace (config_loader.cpp / wifi_provision.cpp), and never read
        // back the copy the WiFi driver keeps. Turning its copy off means
        // checkApLateConnect()'s WiFi.begin() retry - which can repeat every
        // AP_STA_RETRY_MS for days on a device left with a wrong password -
        // is not rewriting flash each time for a value nothing reads.
        WiFi.persistent(false);
        WiFi.mode(WIFI_STA);
        wifiScanForTarget(appCfg.wifiSsid);

        Serial.printf("Connecting to %s", appCfg.wifiSsid);
        WiFi.begin(appCfg.wifiSsid, appCfg.wifiPass);
        int attempts = 0;
        while (WiFi.status() != WL_CONNECTED && attempts < 40) {
            delay(500);
            Serial.print(".");
            attempts++;
        }
        Serial.println();
        wifiOk = (WiFi.status() == WL_CONNECTED);
        if (!wifiOk) {
            Serial.printf("[WIFI] Connect FAILED after %d attempts - status=%s\n",
                          attempts, wifiStatusName(WiFi.status()));
        }
    }

    if (wifiOk) {
        Serial.printf("Connected! IP: %s\n", WiFi.localIP().toString().c_str());
        digitalWrite(LED_PIN, LOW);
        ui_setWifiInfo(WiFi.localIP().toString().c_str(), true);

        firebase_init(appCfg.firebaseUrl, appCfg.firebasePath,
                      appCfg.deviceId, appCfg.userId, appCfg.firebaseToken);
        firebase_sendMeta();
        firebase_updateStatus(true);

        ota_start(OTA_PORT, OTA_USER, OTA_PASS, OTA_MDNS_HOSTNAME);

        // Sync initial control state
        JsonDocument doc;
        if (firebase_read("control/state", doc)) {
            fanOn         = doc["fanState"]         | false;
            coolerOn      = doc["coolerState"]      | false;
            heaterOn      = doc["heaterState"]      | false;
            humidifierOn  = doc["humidifierState"]  | false;
            autoMode  = strcmp(doc["controlMode"] | "automatic", "automatic") == 0;
            applyStates();
            Serial.printf("Synced: Fan=%d Cooler=%d Heater=%d Humidifier=%d Mode=%s\n",
                          fanOn, coolerOn, heaterOn, humidifierOn,
                          autoMode ? "AUTO" : "MANUAL");
        }

        JsonDocument tDoc;
        if (firebase_read("config/thresholds", tDoc)) {
            thresholds.tempHigh   = tDoc["temperatureHigh"] | TEMP_HIGH;
            thresholds.tempLow    = tDoc["temperatureLow"]  | TEMP_LOW;
            thresholds.humHigh    = tDoc["humidityHigh"]    | HUM_HIGH;
            thresholds.humLow     = tDoc["humidityLow"]     | HUM_LOW;
            thresholds.gasHigh    = tDoc["gasHigh"]         | GAS_HIGH;
            ui_setThresholds(&thresholds);
            Serial.printf("Thresholds: T(%.0f-%.0f) H(%.0f-%.0f) G(%.0f)\n",
                          thresholds.tempLow, thresholds.tempHigh,
                          thresholds.humLow, thresholds.humHigh,
                          thresholds.gasHigh);
        }

        JsonDocument fcDoc;
        if (firebase_read("config/fanCycle", fcDoc)) {
            applyFanCycleDoc(fcDoc);
            Serial.printf("Fan cycle: enabled=%d on=%lus off=%lus\n",
                          fanCycleEnabled, fanCycleOnMs / 1000UL, fanCycleOffMs / 1000UL);
        }

#if USE_STREAMING
        // Open the SSE stream BEFORE launching the task so initial state
        // is already hydrated when the task starts.
        streamSubscribe();
#endif

        // ---- Launch Firebase task on Core 0 ----
        xTaskCreatePinnedToCore(
            firebaseTask,
            "FirebaseTask",
            FIREBASE_TASK_STACK_BYTES,
            NULL,
            2,
            NULL,
            0   // Core 0 (loop runs on Core 1)
        );
        Serial.println("[RTOS] Firebase task launched on Core 0");

    } else {
        apMode = true;
        Serial.println("No WiFi - Starting AP provisioning mode");
        Serial.printf("AP SSID: %s  Password: %s\n", appCfg.apSsid, appCfg.apPass);

        WiFi.softAP(appCfg.apSsid, appCfg.apPass);
        Serial.printf("AP IP: %s\n", WiFi.softAPIP().toString().c_str());
        ui_setWifiInfo(WiFi.softAPIP().toString().c_str(), false);

        provision_start(appCfg.httpPort);
        digitalWrite(LED_PIN, HIGH);
    }

    Serial.println("System ready.\n");
}

// ==================== Loop (Core 1) ====================
// ONLY fast local work: buttons, LCD, sensors, safety.
// NO blocking HTTPS calls. Runs every ~10ms = instant button response.

#define HEARTBEAT_INTERVAL 10000

void loop() {
    unsigned long now = millis();

    ui_update();

    static unsigned long lastHeartbeat = 0;
    if (now - lastHeartbeat >= HEARTBEAT_INTERVAL) {
        lastHeartbeat = now;
        printHeartbeat();
    }

    if (apMode) {
        provision_handle();
        checkApLateConnect();

        static unsigned long lastSensorAP = 0;
        if (now - lastSensorAP >= SENSOR_INTERVAL) {
            lastSensorAP = now;
            LOCK();
            sensors_read(&sensorData);
            sensorReady = true;
            ui_setSensorData(&sensorData);
            UNLOCK();
        }

        bool apInSafety = checkSafety();
        if (!apInSafety) {
            evaluateAutoControl();
            evaluateFanCycle();
            // Keep the LCD's mirror of mode/actuator state in sync while
            // provisioning. applyStates() is the ONLY caller of
            // ui_setControlStates(), and this branch never reached it, so
            // the LCD's uiAuto stayed at its zero-init false while the real
            // autoMode was true: the Control screen looked unlocked and
            // accepted presses, but onUiToggle() rejected every one of them
            // with "switch to Manual mode first" — to Serial only, so the
            // buttons just appeared dead. This is also what re-computes
            // lcdLockedByApp (= appOwnsControl()), i.e. the rule that hands
            // control back to whoever is standing at the device while the app
            // cannot reach it (user/HW team, 2026-09-02).
            applyStates();
        }
        digitalWrite(LED_PIN, (millis() / 500) % 2);
        delay(10);
        return;
    }

    // ---- STA mode: WiFi health + reconnect ----
    bool connected = (WiFi.status() == WL_CONNECTED);
    if (connected != (bool)wifiOk) {
        wifiOk = connected;
        if (!connected) {
            Serial.println("[WIFI] Connection lost");
            ui_setWifiInfo("---.---.---.---", false);
        } else {
            Serial.printf("[WIFI] Reconnected: %s\n", WiFi.localIP().toString().c_str());
            ui_setWifiInfo(WiFi.localIP().toString().c_str(), true);
        }
    }

    if (!connected) {
        // Attempt reconnect every 30 s
        static unsigned long lastReconnect = 0;
        if (now - lastReconnect >= 30000) {
            lastReconnect = now;
            Serial.println("[WIFI] Attempting reconnect...");
            WiFi.disconnect(false);
            WiFi.begin(appCfg.wifiSsid, appCfg.wifiPass);
        }
    }

    // ---- Sensors + safety ----
    static unsigned long lastSensorRead = 0;
    if (now - lastSensorRead >= SENSOR_INTERVAL) {
        lastSensorRead = now;
        LOCK();
        sensors_read(&sensorData);
        sensorReady = true;
        ui_setSensorData(&sensorData);
        UNLOCK();
        Serial.printf("[SENSOR] T=%.1fC  H=%.1f%%  Gas=%.1fppm\n",
                      sensorData.temperature, sensorData.humidity,
                      sensorData.gas);
    }

    bool inSafety = checkSafety();

    // Detect falling edge: safety just cleared. Push ONCE so the cloud and
    // app stop showing safetyOverride=true after sensors recover.
    static bool prevSafetyActive = false;
    if (prevSafetyActive && !inSafety) {
        Serial.println("[SAFETY] Cleared — pushing safetyOverride=false");
        requestControlPush("Safety cleared - sensors recovered", false);
    }
    prevSafetyActive = inSafety;

    if (inSafety) {
        delay(10);
        return;
    }

    checkComfortAlerts();

    // Both are WiFi-independent and run every tick — see their comments.
    // Auto-control goes first so a live fan cycle still gets the last word
    // on the fan.
    evaluateAutoControl();
    evaluateFanCycle();

    // Apply states while not in safety mode — outside the mutex
    if (!safetyActive) applyStates();

    delay(10);  // ~100Hz loop — buttons are never missed
}
