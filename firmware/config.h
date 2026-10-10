/*
 * config.h - Hardware pins, thresholds, timing and default settings
 *
 * This is the single source of truth for everything tunable in the
 * firmware. Nothing else in the sketch hardcodes a pin number, a
 * threshold, or a timing constant — change it here and re-upload.
 *
 * Credentials (WiFi password, Firebase database secret, OneSignal keys)
 * do NOT live in this file. They are pulled in from secrets.h, which is
 * gitignored. Copy secrets.example.h to secrets.h and fill it in before
 * the first build — see the README in this folder.
 *
 * Sections, in order:
 *   1. Firmware version           (what farm/meta.firmware reports)
 *   2. Credentials                (#include "secrets.h")
 *   3. Firebase / OneSignal       (non-secret settings: URL, root path, channel)
 *   4. GPIO pin map               (relays, sensors, LCD, buttons)
 *   5. AP provisioning + OTA      (setup portal + wireless update page)
 *   6. Default thresholds         (comfort range + hard safety limits)
 *   7. Fan cycle defaults
 *   8. Timing constants           (poll intervals, debounce, timeouts)
 *   9. MQ135 calibration constants
 */

#ifndef CONFIG_H
#define CONFIG_H

// ==================== Firmware Version ====================
// Bump this on every build you intend to OTA out — it's what shows up in
// farm/meta.firmware and on the OTA upload page, so you can confirm a
// flash actually took (the ESP32's Update library itself doesn't version
// anything; this is our own marker).
#define FIRMWARE_VERSION  "1.4.0-ota"

// ==================== Credentials (secrets.h) ====================
// Defines WIFI_SSID, WIFI_PASS, FIREBASE_TOKEN, ONESIGNAL_APP_ID and
// ONESIGNAL_REST_API_KEY. The file is gitignored so real credentials never
// end up in the repository; secrets.example.h documents every field.
//
// WiFi note: the SSID/password here are only the compiled-in fallback. In
// the field the device is normally provisioned through its own setup
// portal (wifi_provision.cpp), and whatever was saved there (NVS) always
// takes precedence — see config_loader.cpp for the priority order.
#include "secrets.h"

// ==================== Firebase Config ====================
// Realtime Database root URL and the top-level node this device reads and
// writes under. The schema is flat and single-farm by design: every path
// is farm/<something>, there is no per-device prefix (see firebase_init()
// in firebase_client.cpp for the history behind that decision).
#define FIREBASE_URL    "https://poultryfarm-v1-mm-default-rtdb.firebaseio.com"
#define FIREBASE_PATH   "farm"      // Flat single-farm node — no device-id prefix
#define DEVICE_ID       ""          // Unused in URL — kept for meta.deviceId field
#define USER_ID         "default_user"

// ==================== OneSignal Config (push notifications) ====================
// Sends a push directly to every phone with the app installed whenever an
// alert fires — see onesignal_client.cpp. The App ID and REST API key come
// from secrets.h. Leaving them blank = notifications silently disabled
// (onesignal_sendAlert() just returns false), everything else keeps working.
//
// Android notification channel the alert pushes are posted to. MUST stay
// byte-identical to ALERT_CHANNEL_ID in the app's MainActivity.kt, which is
// where the channel is actually created (IMPORTANT: with PUBLIC lockscreen
// visibility, so alert text is readable without unlocking — OneSignal's own
// default channel is PRIVATE and hides it). A mismatch is silent: OneSignal
// just falls back to its default channel and the lock screen goes back to
// showing the app name and nothing else.
#define ONESIGNAL_ANDROID_CHANNEL_ID "farm_alerts"

// ==================== GPIO Pins ====================
//
// >>> HOW TO CHANGE A PIN (for the HW team) <<<
// Every physical pin the firmware uses is defined ONCE, right here, as a
// #define. To move a signal to a different ESP32 pin:
//   1. Change the number below (do NOT hunt through .cpp files — nothing
//      else in the firmware hardcodes a pin number).
//   2. Re-upload the sketch. That's it.
//
// A few ESP32 rules to keep in mind when picking a new pin:
//   - GPIO 34-39 are INPUT ONLY (no internal pull-up either) — fine for the
//     gas sensor (ADC), but never usable for relays, buttons, or I2C.
//   - GPIO 6-11 are wired to the internal SPI flash — never use these.
//   - GPIO 0, 2, 15 affect boot mode (strapping pins) — avoid for buttons
//     that might be held down at power-on.
//   - I2C (SDA/SCL) needs two pins that both support open-drain output with
//     pull-ups (either external, or set INPUT_PULLUP in software); avoid
//     34-39 for I2C since they have no pull-up capability.
//   - GPIO 16/17 are used internally for PSRAM on WROVER modules — fine on
//     a plain WROOM dev board (no PSRAM), but avoid them if the board has
//     PSRAM.
//   - The component_tests/ sketch (see that folder's README) re-detects
//     whatever pins you set here — run it after any pin change to confirm
//     the new wiring works before flashing the main firmware.
//
// Current PCB revision pin map:

// Actuators (relay outputs - ON/OFF). Confirmed set (per HW team): Fan,
// Cooler, Heater, Humidifier — there is no Light or Feeder relay anymore.
// Physically verified 2026-08-19 via component_tests/ (option "6", relay
// walkthrough) on real hardware: Fan and Humidifier were swapped from the
// pin numbers carried over from the previous board revision — Cooler and
// Heater were already correct.
#define FAN_PIN          14
#define COOLER_PIN       26
#define HEATER_PIN       27
#define HUMIDIFIER_PIN   25

// Relay module polarity. Most low-side relay boards (incl. the common
// 4-channel modules used here) are ACTIVE-LOW: driving the input pin LOW
// energizes the relay coil (ON), HIGH de-energizes it (OFF). Flip this to
// false if a future relay module turns out to be active-HIGH instead —
// it's the only place polarity is decided; command_handler.cpp reads this.
#define RELAY_ACTIVE_LOW  true

// I2C bus — LCD (PCF8574 backpack) only. The temp/humidity sensor used to
// share this bus (AM2320, I2C) but was swapped for its single-wire sibling
// below, so this bus now has exactly one device on it.
#define I2C_SDA         33
#define I2C_SCL         32

// Temp/humidity sensor — AM2302/DHT22, single-wire (bit-banged), swapped
// from the AM2320 (I2C) that used to share the bus above. GPIO4 was picked
// over the old LDR pin (35) deliberately: 34-39 are INPUT-ONLY on the
// ESP32 (see the pin rules above) and this protocol needs the host to
// drive the line LOW to start a read, so an input-only pin can't work
// here. GPIO4 is free, fully bidirectional, and not a strapping/flash/
// PSRAM pin. The LCD's I2C bus above is untouched either way. Needs a
// 4.7-10k pull-up to 3.3V if the module doesn't already have one built in.
#define DHT_PIN         4

// ADC sensors
#define MQ135_PIN       34    // Gas sensor

// Status LED
#define LED_PIN         2

// LCD (on the shared I2C bus above)
#define LCD_ADDR        0x27    // PCF8574 address (try 0x3F if not working)
#define LCD_COLS        16
#define LCD_ROWS        2

// Push buttons (active-low, internal pull-ups). Physically verified
// 2026-08-19 via component_tests/'s LCD-feedback button test: the harness
// was wired mirrored (UP<->SELECT and DOWN<->MOVE swapped from the
// original assumption) — corrected below.
#define BTN_UP          17
#define BTN_DOWN        5
#define BTN_MOVE        18
#define BTN_SELECT      19

// ==================== AP / Provisioning Defaults ====================

#define AP_SSID         "PoultryFarm_Setup"
#define AP_PASS         "setup123"
#define AP_PORT         80

// ==================== OTA (wireless firmware update) ====================
// Reachable at http://<device-ip>/ once connected to WiFi (STA mode only —
// mutually exclusive with AP_PORT above, which is only bound in AP mode).
// Basic-auth gated so a stray device on the WiFi can't flash it by accident.
#define OTA_PORT        80
#define OTA_USER        "admin"
#define OTA_PASS        "poultry_ota"
// mDNS name — reach the OTA page at http://poultryfarm.local/ instead of
// tracking down whatever IP the router handed out this time.
#define OTA_MDNS_HOSTNAME  "poultryfarm"

// ==================== Default Thresholds ====================
// Adult broilers (5+ weeks) - based on poultry science standards

#define TEMP_HIGH       24.0f   // °C - fan on above this
#define TEMP_LOW        18.0f   // °C - heater on below this
#define HUM_HIGH        70.0f   // %
#define HUM_LOW         50.0f   // %
#define GAS_HIGH        400.0f  // ppm - soft ventilation trigger (must stay < MQ135_MAX_PPM in sensors.cpp or it can never fire)
#define HYSTERESIS      1.5f    // Prevents oscillation

// ==================== Fan Cycle (scheduled airing, app-set) ====================
// When enabled (farm/config/fanCycle in Firebase), the fan runs ON/OFF on a
// fixed schedule regardless of gas/temp/humidity — for deliberately airing
// the house. Disabled by default; these are just the starting values before
// the app ever writes real ones. Hard safety (checkSafety()) still overrides
// this unconditionally; only the soft gas/temp/humidity auto-fan logic is
// what gets bypassed while a cycle is running.
#define FAN_CYCLE_ENABLED_DEFAULT  false
#define FAN_CYCLE_ON_SEC_DEFAULT   (3UL * 3600UL)  // 3 hours
#define FAN_CYCLE_OFF_SEC_DEFAULT  (2UL * 3600UL)  // 2 hours

// Safety limits (HARD - cannot be overridden)
#define TEMP_ABS_MIN    10.0f   // °C - death risk
#define TEMP_ABS_MAX    42.0f   // °C - heat stroke
#define HUM_ABS_MIN     30.0f   // %  - respiratory issues
#define HUM_ABS_MAX     85.0f   // %  - mold growth
// Must stay below MQ135_MAX_PPM (500, in sensors.cpp) or this can never
// trigger — a GAS_ABS_MAX at/above the sensor's own reading ceiling is a
// no-op safety check. 450 leaves a 50ppm margin below the sensor's ceiling.
#define GAS_ABS_MAX     450.0f  // ppm

// ==================== Timing (milliseconds) ====================

#define SENSOR_INTERVAL     2000    // Read sensors every 2s
#define FIREBASE_INTERVAL   10000   // Sync to cloud every 10s
#define STATE_INTERVAL      2000    // Poll control state every 2s (was 1s)
#define CONTROL_INTERVAL    3000    // Auto-control check every 3s
// How long the cloud may go silent before the firmware stops believing the
// app can reach it, and hands control back to the LCD. Must comfortably
// exceed the normal contact cadence or ownership will flap: FIREBASE_INTERVAL
// (10s) gives a REST heartbeat, and the RTDB stream's keep-alive arrives
// every ~30s, so 90s is ~9 missed beats of headroom. See cloudReachable().
#define CLOUD_STALE_MS      90000UL // Cloud considered unreachable after 90s silence
// Minimum gap between RETRIES of a failed control push (a first attempt is
// always immediate). A failed push re-arms rather than being dropped, and on
// a WAN outage the failure can come back in milliseconds via a transport
// error, which makes firebaseRequestUrl() tear down and reallocate the ~40KB
// TLS session. Unthrottled, firebaseTask's 50ms loop would repeat that dozens
// of times a second for the whole outage — exactly the heap churn
// firebase_stream.cpp blames for the 2026-08-26 reboots.
#define CONTROL_PUSH_RETRY_MS 5000  // Backoff between failed control-push retries
#define ALERT_COOLDOWN      300000  // 5 min between same alert
#define LCD_REFRESH         1000    // LCD update rate
#define BTN_DEBOUNCE        15      // Min press duration to count as a real press (ms)
// Minimum gap between two ACCEPTED presses of the same button. BTN_DEBOUNCE
// alone only filters out short glitches during a single press — it does not
// stop mechanical contact bounce on the RELEASE edge (raw signal flickering
// LOW/HIGH/LOW for a few ms as the switch settles) from being read as a
// second, separate press right after the first. That's what was causing a
// single physical press to register as two — e.g. an actuator toggling ON
// then immediately OFF from one SELECT press. 150ms is well above realistic
// switch bounce (usually <30ms) and well under the gap a human leaves
// between two deliberate taps.
#define BTN_REFRACTORY_MS   150
#define BTN_HOLD_TIME       1000    // Long-press threshold ms (MOVE -> HOME)

// Hold SELECT this long from any screen to wipe stored WiFi credentials and
// reboot into the AP provisioning portal (switch to a different network
// without a laptop/OTA). AP_RESET_WARN_MS is when the LCD starts showing a
// "Release=cancel" countdown, well before it actually fires at
// AP_RESET_HOLD_MS — a deliberately long, hard-to-hit-by-accident hold with
// visible warning, since it's disruptive (drops the current connection).
#define AP_RESET_WARN_MS    2000
#define AP_RESET_HOLD_MS    5000

// ---- Recovery out of AP provisioning mode ----
// setup() gives the saved network 20s (40 x 500ms) and then latches AP mode.
// On a real power cut the ESP32 is up in ~2s while a router / phone hotspot
// can take a minute or more, so that window gets missed through no fault of
// the stored credentials. These two govern the way back out (see
// checkApLateConnect() in the main sketch).
//
// AP_STA_RETRY_MS: how often to re-issue WiFi.begin() with the saved
// credentials while sitting in the portal. Not left to the driver's own
// auto-reconnect, which gives up for some disconnect reasons - notably
// NO_SSID_AVAIL, i.e. exactly the "AP wasn't up yet" case this exists for.
//
// AP_PORTAL_IDLE_MS: how long the setup page must have gone untouched
// before that recovery is allowed to reboot the device - or even to retry,
// since a successful STA connect drags the softAP onto the station's
// channel and drops whoever is on the portal. Generous on purpose: loading
// the page and then typing a WiFi password on a phone produces no HTTP
// requests at all, so a short window would fire mid-typing and throw the
// entry away. It costs nothing in the case it is protecting against,
// because the unattended device nobody has touched (lastRequestMs == 0)
// skips this gate entirely and recovers as fast as ever.
#define AP_STA_RETRY_MS     30000
#define AP_PORTAL_IDLE_MS   120000

// ==================== MQ135 Constants ====================
// Cross-checked against the MQ135 datasheet (2026-08-30, "gas isn't being
// read" report) — two things below don't match the datasheet's reference
// circuit and should be physically verified against the actual board,
// not just trusted as correct because they compile:
//   1. Datasheet's own test circuit uses RL=20kOhm; this is 10kOhm. Fine
//      if that's genuinely the resistor on THIS breakout board, wrong if
//      it was copied from a different reference without checking.
//   2. Datasheet specifies the analog output swings the FULL 0-5V (hence
//      VREF=5.0 here) — but the ESP32 ADC pin only tolerates ~3.3V and
//      sensors.cpp's mq135_readPpm() (analogReadMilliVolts()) can never
//      measure above that ceiling regardless of what this constant says.
//      If AOUT is wired straight into the ADC pin with no resistor divider
//      stepping 0-5V down to a 3.3V-safe range, real readings above ~3.3V
//      are being clipped/misread at the pin itself — check with a
//      multimeter on AOUT before trusting readings. If a divider IS
//      present, this needs to reflect the DIVIDED ceiling, not 5.0.
// See sensors.cpp's mq135_readPpm() — now logs raw ADC + voltage + Rs on
// every read specifically so the next serial capture has real numbers to
// diagnose this from instead of just a silent "gas: 0".
#define MQ135_RL        10.0f       // Load resistance kΩ — verify vs. board
#define MQ135_RO_CLEAN  25.0f       // Adjusted for 5V board
#define MQ135_VREF      5.0f        // VERY IMPORTANT: Actual sensor VCC — verify divider (see above)
#define MQ135_ADC_MAX   4095.0f

#endif
