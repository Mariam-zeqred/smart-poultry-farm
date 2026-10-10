/*
 * ui_manager.h - LCD screen UI + 4-button navigation
 *
 * Buttons: UP(17), DOWN(5), MOVE(18), SELECT(19) — see BTN_* in config.h
 * (those numbers are the physically verified mapping for the current PCB;
 * config.h is the source of truth if they ever change again).
 *
 * Screens:
 *   HOME        - Page 1: Temp/Humidity/WiFi status icon, Gas ppm.
 *                 Page 2: actuator ON/OFF states + mode/safety indicator.
 *                 Auto-rotates every 5s; UP/DOWN flips manually.
 *   MENU        - Control | Thresholds | Fan Cycle | Mode | Info | Back
 *   CONTROL     - Toggle fan/cooler/heater/humidifier
 *   THRESHOLDS  - Browse & select thresholds to edit
 *   EDIT_THRESH - Adjust a single threshold value
 *   FAN_CYCLE   - Edit enabled/on-minutes/off-minutes for scheduled airing
 *   MODE        - Toggle automatic / manual control
 *   INFO        - IP, uptime, firmware
 *
 * Permissions (mirrors Flutter app), checked in this priority order:
 *   SAFETY:      ALL controls fully locked, no user override possible.
 *   APP CONTROL: the app owns control and can actually reach the device —
 *                LCD is monitor-only until the app hands control back (or
 *                the cloud becomes unreachable, at which point the LCD
 *                automatically regains control).
 *   AUTO mode:   all actuators locked — sensor logic is the sole authority.
 *                Switch to Manual on the MODE screen first.
 *   FAN CYCLE:   the Fan alone is locked while a scheduled cycle owns it.
 *   MANUAL:      all controls free.
 *
 * Long-press MOVE from ANY screen → instant return to HOME.
 * Long-press SELECT (5s) from ANY screen → wipe WiFi creds, reboot into
 * the AP provisioning portal (to switch to a different network).
 */

#ifndef UI_MANAGER_H
#define UI_MANAGER_H

#include <Arduino.h>
#include "sensors.h"
#include "lcd_display.h"

enum UiScreen {
    SCREEN_HOME = 0,        // 2 pages: sensors+WiFi icon / actuator states (auto-rotate)
    SCREEN_MENU,            // Main menu list
    SCREEN_CONTROL,         // Toggle fan/cooler/heater/humidifier
    SCREEN_THRESHOLDS,      // Browse threshold values
    SCREEN_EDIT_THRESH,     // Edit a single threshold
    SCREEN_FAN_CYCLE,       // Edit fan cycle enabled/on-time/off-time
    SCREEN_MODE,            // Toggle auto/manual
    SCREEN_INFO             // IP, uptime, firmware
};

// Initialize LCD + buttons (call once in setup)
void ui_init();

// Call every loop iteration to handle button presses + LCD refresh
void ui_update();

// Feed new sensor data for display
void ui_setSensorData(const SensorData *data);

// Feed current control states for display
// safetyOverride: true when safety system has taken control (all locked)
// appOwnsControl: true when the app currently owns control ownership AND can
// actually reach us — the LCD is locked to monitor-only in that case
// (mirrors the Auto-mode lock, but for WHO may command rather than WHETHER
// sensors do). This is a MIRROR, not the decision: the authority is
// appOwnsControl() in the main .ino, fed here by applyStates(). Reachability
// is measured (time since the last successful Firebase contact), not
// inferred from WiFi association — a router that is up but off the internet
// leaves the app unable to command anything, and the LCD must regain control
// then rather than stranding whoever's standing at the device.
void ui_setControlStates(bool fan, bool cooler, bool heater, bool humidifier,
                         bool autoMode, bool safetyOverride, bool appOwnsControl);

// Feed current thresholds for display & editing
void ui_setThresholds(const Thresholds *t);

// Feed WiFi info
void ui_setWifiInfo(const char *ip, bool connected);

// Feed fan-cycle status (app- or LCD-controlled scheduled airing). While
// enabled, the Fan entry on the CONTROL screen is locked (mirrors the
// safety lock) since the cycle timer owns the fan, not the user — disable
// it first. HOME page 2 also shows a distinct marker for it.
void ui_setFanCycle(bool enabled, unsigned long onSec, unsigned long offSec);

// Register callback: actuator toggled from CONTROL screen
// index: 0=fan, 1=cooler, 2=heater, 3=humidifier
// The callback is responsible for switching auto→manual if needed.
void ui_onToggle(void (*cb)(int index));

// Register callback: threshold changed from EDIT_THRESH screen
// index: 0=tempHigh, 1=tempLow, 2=humHigh, 3=humLow, 4=gasHigh
void ui_onThresholdChange(void (*cb)(int index, float value));

// Register callback: control mode changed from MODE screen
void ui_onModeChange(void (*cb)(bool autoMode));

// Register callback: fan cycle settings changed from the FAN_CYCLE screen
void ui_onFanCycleChange(void (*cb)(bool enabled, unsigned long onSec, unsigned long offSec));

// Register callback: SELECT held for AP_RESET_HOLD_MS (config.h) from any
// screen. The callback should wipe stored WiFi credentials and restart —
// it's called directly on Core 1, but that's fine since it's just a local
// NVS write + restart, not network I/O (see the callback's own comment in
// the main sketch).
void ui_onApReset(void (*cb)(void));

#endif
