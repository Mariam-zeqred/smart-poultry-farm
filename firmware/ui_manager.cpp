/*
 * ui_manager.cpp - LCD screens + 4-button navigation
 *
 * Buttons (pins defined in config.h — BTN_UP/BTN_DOWN/BTN_MOVE/BTN_SELECT):
 *   UP     (GPIO 17) - Navigate up / increment value
 *   DOWN   (GPIO 5)  - Navigate down / decrement value
 *   MOVE   (GPIO 18) - Enter submenu / cycle step / back
 *                       LONG PRESS (1s) = return HOME from anywhere
 *   SELECT (GPIO 19) - Primary action: toggle, confirm, enter
 *                       LONG PRESS (5s, from ANY screen) = wipe WiFi creds
 *                       and reboot into the AP setup portal (switch
 *                       networks). LCD shows a "Reset WiFi?" countdown
 *                       starting at 2s so it's not accidentally triggered —
 *                       release before 5s to cancel.
 *
 * Screen flow:
 *   HOME ─[MOVE/SEL]─> MENU
 *   MENU ─[SEL]─> CONTROL | THRESHOLDS | FAN_CYCLE | MODE | INFO | <Back>
 *   CONTROL ─[SEL]─> toggle actuator  |  [MOVE]─> MENU
 *   THRESHOLDS ─[SEL]─> EDIT_THRESH   |  [MOVE]─> MENU
 *   EDIT_THRESH ─[SEL]─> save & back  |  [MOVE]─> cycle step
 *   FAN_CYCLE (list: Enabled/On/Off/Back) ─[SEL on Enabled]─> toggle in place
 *             ─[SEL on On/Off]─> edit value screen  |  [MOVE]─> MENU (saves)
 *             edit value screen ─[SEL or MOVE]─> back to FAN_CYCLE list
 *   MODE ─[SEL/UP/DN]─> toggle mode   |  [MOVE]─> MENU
 *   INFO ─[SEL/MOVE]─> MENU
 *
 * Permissions (mirrors Flutter app):
 *   AUTO mode:  ALL actuator controls locked — auto-control is the sole
 *               authority over the relays while Auto is selected. Switch
 *               to Manual (MODE screen) first to take control.
 *   SAFETY:     Everything locked, no toggle possible from LCD.
 *   Mode screen locked during safety override.
 */

#include "ui_manager.h"
#include "config.h"

// ---- LCD on the shared I2C bus (Wire, started once in setup()) ----
static LcdDisplay lcd;

// ---- Custom characters (8 slots, indices 0-7) ----
static const uint8_t CHAR_THERM[8]  = {0x04,0x0A,0x0A,0x0E,0x0E,0x1F,0x1F,0x0E};
static const uint8_t CHAR_DROP[8]   = {0x04,0x04,0x0A,0x0A,0x11,0x11,0x11,0x0E};
// WiFi connected: ascending signal bars, bottom-aligned (bar heights 1-5
// left to right). Simple filled shape — reads clearly even at 5x8.
static const uint8_t CHAR_WIFI_OK[8] = {0x00,0x00,0x00,0x01,0x03,0x07,0x0F,0x1F};
// WiFi disconnected: a bold standalone X (not an overlay on the bars —
// two thin overlapping shapes at 5x8 resolution just blur together and
// stop being legible; a completely different, unmistakable glyph reads
// far better at a glance than a busier "signal bars with a faint slash").
static const uint8_t CHAR_WIFI_X[8]  = {0x11,0x0A,0x04,0x04,0x04,0x0A,0x11,0x00};
static const uint8_t CHAR_DEGREE[8] = {0x06,0x09,0x09,0x06,0x00,0x00,0x00,0x00};
// Lock icon for auto/safety locked items
static const uint8_t CHAR_LOCK[8]   = {0x0E,0x11,0x11,0x1F,0x1B,0x1B,0x1F,0x00};
// Solid block: used as a compact "ON" marker on the actuator status page.
// (A dedicated custom char instead of relying on the ROM's 0xFF byte, since
// which glyph lives at 0xFF varies between HD44780 charset ROM revisions.)
static const uint8_t CHAR_ONDOT[8]  = {0x1F,0x1F,0x1F,0x1F,0x1F,0x1F,0x1F,0x1F};

#define CHAR_IDX_THERM    0
#define CHAR_IDX_DROP     1
#define CHAR_IDX_WIFI_OK  2
#define CHAR_IDX_WIFI_X   3
#define CHAR_IDX_LOCK     4
#define CHAR_IDX_DEGREE   5
#define CHAR_IDX_ONDOT    6

// ---- Button state (4 buttons) ----
static const uint8_t btnPins[] = {BTN_UP, BTN_DOWN, BTN_MOVE, BTN_SELECT};
#define NUM_BTNS 4
enum BtnId { B_UP = 0, B_DOWN, B_MOVE, B_SELECT };

static bool btnPressed[NUM_BTNS];   // true on valid short-press release
static bool btnHeld[NUM_BTNS];      // true once when hold threshold reached
static bool btnLast[NUM_BTNS];      // previous raw state
static unsigned long btnTime[NUM_BTNS];
static bool holdFired[NUM_BTNS];    // prevent re-firing hold
static unsigned long btnLastAccepted[NUM_BTNS]; // millis() of last accepted press, for refractory gating

// ---- Long-press SELECT -> WiFi/AP-mode reset ----
// Tracked separately from the short-press machinery above, which is
// release-triggered and single-shot: this needs to act WHILE still held
// (live LCD countdown) and must suppress the normal short-press SELECT
// action that would otherwise fire once the button is finally released.
static bool apResetWasArmed = false; // held past AP_RESET_WARN_MS this press (suppresses the trailing short-press on release)
static bool apResetFired    = false; // callback already invoked this press (one-shot guard)
static void (*apResetCallback)(void) = NULL;

// ---- UI state ----
static UiScreen currentScreen = SCREEN_HOME;
static int menuIndex    = 0;
static int controlIndex = 0;
static int threshIndex  = 0;
static int homePhase    = 0;
static int lastHomePhase = -1;      // track phase changes for clear

// ---- Edit threshold state ----
static float editValue  = 0;
static int   editIndex  = 0;
static int   stepIdx    = 2;
static const float stepSizes[] = {0.1f, 0.5f, 1.0f, 5.0f};
#define NUM_STEPS 4

// ---- Display data (fed from main sketch) ----
static SensorData uiSensors;
static bool uiFan, uiCooler, uiHeater, uiHumidifier, uiAuto;
static bool uiSafetyOverride = false;
static bool uiAppOwnsControl = false;
static bool uiFanCycle = false;
static unsigned long uiFanCycleOnSec  = 0;
static unsigned long uiFanCycleOffSec = 0;
static Thresholds uiThresh;
static char uiIp[20] = "No WiFi";
static bool uiWifiOk = false;

static unsigned long lastRefresh = 0;
static unsigned long homeRotate  = 0;

// ---- Fan Cycle edit state ----
// fcField is the list cursor (0=Enabled, 1=On, 2=Off, 3=Back) when
// fcEditingField is false, or which field is being adjusted when true.
static int fcField = 0;
static bool fcEditingField = false;
static bool fcEditEnabled = false;
static unsigned long fcEditOnMin  = 0;
static unsigned long fcEditOffMin = 0;
#define FC_STEP_MIN 5
#define FC_MIN_MIN  1
#define FC_MAX_MIN  600
#define FC_ITEMS    4
static const char *fcLabels[] = {"Enabled", "On Time", "Off Time", "Back"};

// ---- Menu / list definitions ----
#define MENU_ITEMS   6
static const char *menuLabels[]   = {"Control", "Thresholds", "Fan Cycle", "Mode", "Info", "Back"};

#define CTRL_ITEMS   5
static const char *ctrlLabels[]   = {"Fan", "Cooler", "Heater", "Humidifier", "Back"};

#define THRESH_ITEMS 6
static const char *threshLabels[] = {"Temp Hi", "Temp Lo", "Hum Hi", "Hum Lo",
                                     "Gas Hi", "Back"};

// ---- Callbacks (registered by main sketch) ----
static void (*toggleCallback)(int index) = NULL;
static void (*thresholdCallback)(int index, float value) = NULL;
static void (*modeCallback)(bool autoMode) = NULL;
static void (*fanCycleCallback)(bool enabled, unsigned long onSec, unsigned long offSec) = NULL;

void ui_onToggle(void (*cb)(int index))                   { toggleCallback    = cb; }
void ui_onThresholdChange(void (*cb)(int index, float v)) { thresholdCallback = cb; }
void ui_onModeChange(void (*cb)(bool autoMode))           { modeCallback      = cb; }
void ui_onFanCycleChange(void (*cb)(bool enabled, unsigned long onSec, unsigned long offSec))
{ fanCycleCallback = cb; }
void ui_onApReset(void (*cb)(void)) { apResetCallback = cb; }

// ======================================================================
//  Button reading with debounce + hold detection
// ======================================================================

static void readButtons() {
    unsigned long now = millis();

    for (int i = 0; i < NUM_BTNS; i++) {
        bool raw = (digitalRead(btnPins[i]) == LOW);  // active-low
        btnPressed[i] = false;
        btnHeld[i]    = false;

        if (raw && !btnLast[i]) {
            // Just pressed - record timestamp
            btnTime[i]   = now;
            holdFired[i] = false;
        }

        if (raw && btnLast[i]) {
            // Still held down - check for hold threshold
            if (!holdFired[i] && (now - btnTime[i] >= BTN_HOLD_TIME)) {
                btnHeld[i]   = true;
                holdFired[i] = true;  // fire only once per press
            }
        }

        if (!raw && btnLast[i]) {
            // Just released
            unsigned long pressDuration = now - btnTime[i];

            // 1. Minimum press duration filters out short glitches while held.
            // 2. Minimum gap since the last ACCEPTED press filters out release-edge
            //    contact bounce (raw flickering LOW/HIGH right after a real release,
            //    which would otherwise register as a second, separate press).
            if (pressDuration >= BTN_DEBOUNCE &&
                (now - btnLastAccepted[i]) >= BTN_REFRACTORY_MS) {

               // 3. If the button was held down, still fire a normal press event...
                // EXCEPT for the MOVE button, since its hold action has a dedicated function (return to HOME),
                // and EXCEPT for SELECT once its hold has crossed the AP-reset warning threshold — otherwise
                // releasing an aborted/completed AP-reset hold would ALSO fire a normal SELECT action
                // (e.g. toggling whatever actuator happens to be on screen).
                bool suppressApResetTrailingPress = (i == B_SELECT && apResetWasArmed);
                if (!suppressApResetTrailingPress && (!holdFired[i] || i != B_MOVE)) {
                    btnPressed[i] = true;  // valid press
                    btnLastAccepted[i] = now;
                }
            }
        }

        btnLast[i] = raw;
    }
}

// ---- Debug helpers (Serial trace of button presses + screen changes) ----
static const char *screenName(UiScreen s) {
    switch (s) {
        case SCREEN_HOME:        return "HOME";
        case SCREEN_MENU:        return "MENU";
        case SCREEN_CONTROL:     return "CONTROL";
        case SCREEN_THRESHOLDS:  return "THRESHOLDS";
        case SCREEN_EDIT_THRESH: return "EDIT_THRESH";
        case SCREEN_FAN_CYCLE:   return "FAN_CYCLE";
        case SCREEN_MODE:        return "MODE";
        case SCREEN_INFO:        return "INFO";
        default:                 return "?";
    }
}

static const char *btnName(int i) {
    switch (i) {
        case B_UP:     return "UP";
        case B_DOWN:   return "DOWN";
        case B_MOVE:   return "MOVE";
        case B_SELECT: return "SELECT";
        default:       return "?";
    }
}

// Check if MOVE was long-pressed (global, any screen → HOME)
static bool checkMoveHold() {
    if (btnHeld[B_MOVE]) {
        currentScreen = SCREEN_HOME;
        homePhase = 0;
        lastHomePhase = -1;
        lcd.clear();
        Serial.println("[UI] MOVE hold -> HOME");
        return true;
    }
    return false;
}

// Check for a long SELECT hold (global, any screen) -> WiFi/AP-mode reset.
// Uses btnLast[B_SELECT]/btnTime[B_SELECT] (set by readButtons() earlier
// this same tick) directly rather than the short-press btnPressed/btnHeld
// machinery, since this needs to act continuously WHILE held (live
// countdown) rather than once on release. Returns true while it's taken
// over the LCD (past the warning threshold), so the caller should skip
// normal screen handling/rendering for this tick.
static bool checkApResetHold() {
    if (!btnLast[B_SELECT]) {
        // Not currently held (or just released) — reset for the next press.
        apResetWasArmed = false;
        apResetFired    = false;
        return false;
    }

    unsigned long held = millis() - btnTime[B_SELECT];

    if (held >= AP_RESET_HOLD_MS) {
        apResetWasArmed = true;
        if (!apResetFired) {
            apResetFired = true;
            Serial.println("[UI] SELECT held 5s+ -> requesting WiFi/AP-mode reset");
            lcd.clear();
            lcd.printRow(0, "Resetting WiFi");
            lcd.printRow(1, "Restarting...");
            if (apResetCallback) apResetCallback();
        }
        return true;
    }

    if (held >= AP_RESET_WARN_MS) {
        apResetWasArmed = true;
        char line[17];
        snprintf(line, sizeof(line), "%lus,release=no",
                 ((AP_RESET_HOLD_MS - held) / 1000) + 1);
        lcd.printRow(0, "Reset WiFi?");
        lcd.printRow(1, line);
        return true;
    }

    return false;
}

// ======================================================================
//  Permission helpers (mirror Flutter app)
// ======================================================================

// Is the given actuator index locked?
// Returns true if user cannot toggle it right now.
static bool isActuatorLocked(int idx) {
    // Safety override: EVERYTHING locked
    if (uiSafetyOverride) return true;

    // App Control: the app currently owns control ownership — LCD is
    // monitor-only until it's handed back (user/HW team, 2026-08-29).
    if (uiAppOwnsControl) return true;

    // Auto mode: ALL actuators locked — auto-control is the sole authority
    // over the relays while Auto is selected (HW team, 2026-08-29). Switch
    // to Manual first. This replaces the old "toggle starts a temporary
    // manual-priority override" behavior, which was the root cause of the
    // actuators misbehaving when toggled from the app while in Auto.
    if (uiAuto) return true;

    // Fan specifically: locked while a scheduled cycle owns it.
    if (idx == 0 && uiFanCycle) return true;

    return false;
}

// ======================================================================
//  Threshold helpers
// ======================================================================

static float getThreshValue(int idx) {
    switch (idx) {
        case 0: return uiThresh.tempHigh;
        case 1: return uiThresh.tempLow;
        case 2: return uiThresh.humHigh;
        case 3: return uiThresh.humLow;
        case 4: return uiThresh.gasHigh;
        default: return 0;
    }
}

// Sane per-field ceiling so a mis-press can't leave a threshold at some
// absurd value (e.g. temp=9999) — matches realistic sensor ranges.
static float threshMax(int idx) {
    switch (idx) {
        case 0: case 1: return 50.0f;   // tempHigh / tempLow (°C)
        case 2: case 3: return 100.0f;  // humHigh / humLow (%)
        case 4: return 500.0f;          // gasHigh (ppm) — MQ135's own reading ceiling
        default: return 1000.0f;
    }
}

static void setThreshValue(int idx, float val) {
    switch (idx) {
        case 0: uiThresh.tempHigh = val; break;
        case 1: uiThresh.tempLow  = val; break;
        case 2: uiThresh.humHigh  = val; break;
        case 3: uiThresh.humLow   = val; break;
        case 4: uiThresh.gasHigh  = val; break;
    }
}

// ======================================================================
//  Screen renderers
// ======================================================================

// Page 1: Temp + Humidity + WiFi status icon, then Gas on its own row.
// Page 2: which actuators are on, plus mode/safety in the spare corner.
// UP/DOWN flips between them manually; they also auto-rotate every 5s
// (see homeRotate in ui_update()).
static void renderHome() {
    char line1[17], line2[17];

    // Clear LCD on phase change to prevent ghosting
    int phase = homePhase % 2;
    if (phase != lastHomePhase) {
        lcd.clear();
        lastHomePhase = phase;
    }

    switch (phase) {
    case 0: {
        // Row 0: Temp + Humidity (fixed-width fields so nothing ghosts
        // between refreshes), WiFi status icon fixed at the top-right
        // corner — same spot every time, connected vs crossed-out.
        lcd.setCursor(0, 0);
        lcd.writeChar(CHAR_IDX_THERM);
        snprintf(line1, sizeof(line1), "%4.1f", uiSensors.temperature);
        lcd.print(line1);
        lcd.writeChar(CHAR_IDX_DEGREE);
        lcd.print("C ");
        lcd.writeChar(CHAR_IDX_DROP);
        snprintf(line1, sizeof(line1), "%3.0f%%", uiSensors.humidity);
        lcd.print(line1);
        lcd.setCursor(15, 0);
        lcd.writeChar(uiWifiOk ? CHAR_IDX_WIFI_OK : CHAR_IDX_WIFI_X);

        // Row 1: Gas reading. MQ135 outputs ppm, not a percentage — shown
        // in its native unit rather than mislabeled as "%".
        snprintf(line2, sizeof(line2), "Gas: %.0f ppm", uiSensors.gas);
        lcd.printRow(1, line2);
        break;
    }

    case 1: {
        // Actuator ON/OFF states — solid block = ON, dash = OFF.
        // Row 1's trailing char is the control mode (A=auto, M=manual),
        // or the lock icon while a safety override is active.
        // Fan shows 'c' instead of a plain dash when it's OFF specifically
        // because a scheduled cycle put it there (vs. genuinely off).
        char fanChar = uiFan ? (char)CHAR_IDX_ONDOT : (uiFanCycle ? 'c' : '-');
        snprintf(line1, sizeof(line1), "FAN:%c HTR:%c",
                 fanChar,
                 uiHeater ? (char)CHAR_IDX_ONDOT : '-');
        lcd.printRow(0, line1);

        // Lock icon whenever the LCD can't toggle actuators right now for
        // ANY reason (safety, app control, or auto) - mirrors
        // isActuatorLocked()'s priority order, so the Home screen (the
        // default idle screen) never silently shows 'M' while the app
        // actually owns control (previously only Safety got the lock icon
        // here, even though Control/Mode screens already reflected App
        // Control - user report 2026-09-03: toggled App Control from the
        // phone, device was online, but the Home screen gave no feedback).
        char modeChar = (uiSafetyOverride || uiAppOwnsControl) ? (char)CHAR_IDX_LOCK
                                          : (uiAuto ? 'A' : 'M');
        snprintf(line2, sizeof(line2), "CLR:%c HUM:%c %c",
                 uiCooler     ? (char)CHAR_IDX_ONDOT : '-',
                 uiHumidifier ? (char)CHAR_IDX_ONDOT : '-',
                 modeChar);
        lcd.printRow(1, line2);
        break;
    }
    }
}

static void renderMenu() {
    lcd.printRow(0, "== MENU ==");
    char line[17];
    snprintf(line, sizeof(line), "> %s", menuLabels[menuIndex]);
    lcd.printRow(1, line);
}

static void renderControl() {
    if (controlIndex < CTRL_ITEMS - 1) {
        const char *name = ctrlLabels[controlIndex];
        bool state = false;
        switch (controlIndex) {
            case 0: state = uiFan;        break;
            case 1: state = uiCooler;     break;
            case 2: state = uiHeater;     break;
            case 3: state = uiHumidifier; break;
        }

        char line1[17], line2[17];
        if (uiSafetyOverride) {
            // Safety lock: show lock icon
            lcd.setCursor(0, 0);
            lcd.writeChar(CHAR_IDX_LOCK);  // lock character
            snprintf(line1, sizeof(line1), " %s", name);
            lcd.print(line1);
            int used = 1 + strlen(name) + 1;
            for (int i = used; i < LCD_COLS; i++) lcd.print(' ');
            lcd.printRow(1, "  !SAFETY LOCK!");
        } else if (uiAppOwnsControl) {
            // App Control lock: shows live state (same as the Auto lock
            // below) but the reason is ownership, not sensor logic.
            lcd.setCursor(0, 0);
            lcd.writeChar(CHAR_IDX_LOCK);
            snprintf(line1, sizeof(line1), " %s: %s", name, state ? "ON" : "OFF");
            lcd.print(line1);
            int used = 1 + strlen(name) + 2 + (state ? 2 : 3);
            for (int i = used; i < LCD_COLS; i++) lcd.print(' ');
            lcd.printRow(1, "  APP CONTROL");
        } else if (uiAuto) {
            // Auto mode: locked, auto-control owns every actuator. Shows
            // the live state (so the user can see what auto is doing) but
            // no toggle is possible — mirrors the safety-lock treatment
            // minus the alarm framing, plus a hint on how to unlock it.
            lcd.setCursor(0, 0);
            lcd.writeChar(CHAR_IDX_LOCK);
            snprintf(line1, sizeof(line1), " %s: %s", name, state ? "ON" : "OFF");
            lcd.print(line1);
            int used = 1 + strlen(name) + 2 + (state ? 2 : 3);
            for (int i = used; i < LCD_COLS; i++) lcd.print(' ');
            lcd.printRow(1, "  AUTO (see MODE)");
        } else if (controlIndex == 0 && uiCooler) {
            // Cooler forces Fan on (needs airflow) — this always wins over
            // a cycle's OFF phase too (see evaluateFanCycle()'s
            // desiredFan/coolerOn logic), so check it first. Mirrors the
            // cycle branch's "still show state, explain why" treatment
            // instead of letting a manual SELECT press look like a no-op.
            snprintf(line1, sizeof(line1), "> %s", name);
            lcd.printRow(0, line1);
            lcd.printRow(1, "  NEEDS CLR OFF");
        } else if (controlIndex == 0 && uiFanCycle) {
            // Fan is on a scheduled cycle (app-controlled) — not manually
            // toggleable from here until the cycle is disabled in the app.
            snprintf(line1, sizeof(line1), "> %s", name);
            snprintf(line2, sizeof(line2), "  CYCLE: %s", state ? "ON" : "OFF");
            lcd.printRow(0, line1);
            lcd.printRow(1, line2);
        } else {
            snprintf(line1, sizeof(line1), "> %s", name);
            snprintf(line2, sizeof(line2), "  State: %s", state ? "ON" : "OFF");
            lcd.printRow(0, line1);
            lcd.printRow(1, line2);
        }
    } else {
        lcd.printRow(0, "  Control");
        lcd.printRow(1, "> < Back");
    }
}

static void renderThresholds() {
    if (threshIndex < THRESH_ITEMS - 1) {
        char line1[17], line2[17];
        snprintf(line1, sizeof(line1), "> %s", threshLabels[threshIndex]);
        snprintf(line2, sizeof(line2), "  Val: %.1f", getThreshValue(threshIndex));
        lcd.printRow(0, line1);
        lcd.printRow(1, line2);
    } else {
        lcd.printRow(0, "  Thresholds");
        lcd.printRow(1, "> < Back");
    }
}

static void renderEditThresh() {
    char line1[17], line2[17];
    snprintf(line1, sizeof(line1), "Edit: %s", threshLabels[editIndex]);
    snprintf(line2, sizeof(line2), "%.1f   stp:%.1f", editValue, stepSizes[stepIdx]);
    lcd.printRow(0, line1);
    lcd.printRow(1, line2);
}

static void renderFanCycle() {
    char line1[17], line2[17];

    if (fcEditingField) {
        // Drilled into On/Off Time - UP/DOWN adjust, SELECT/MOVE go back
        // to the list (mirrors the "MOVE = one step back" rule everywhere
        // else: there's nothing further to select from here).
        unsigned long val = (fcField == 1) ? fcEditOnMin : fcEditOffMin;
        snprintf(line1, sizeof(line1), "Edit: %s", fcLabels[fcField]);
        snprintf(line2, sizeof(line2), "%lu min", val);
        lcd.printRow(0, line1);
        lcd.printRow(1, line2);
        return;
    }

    if (fcField < FC_ITEMS - 1) {
        snprintf(line1, sizeof(line1), "> %s", fcLabels[fcField]);
        if (fcField == 0) {
            snprintf(line2, sizeof(line2), "  %s", fcEditEnabled ? "ON" : "OFF");
        } else {
            unsigned long val = (fcField == 1) ? fcEditOnMin : fcEditOffMin;
            snprintf(line2, sizeof(line2), "  %lu min", val);
        }
        lcd.printRow(0, line1);
        lcd.printRow(1, line2);
    } else {
        lcd.printRow(0, "  Fan Cycle");
        lcd.printRow(1, "> < Back (save)");
    }
}

static void renderMode() {
    if (uiSafetyOverride) {
        lcd.printRow(0, "Mode: LOCKED");
        lcd.printRow(1, "!SAFETY ACTIVE!");
    } else if (uiAppOwnsControl) {
        lcd.printRow(0, "Mode: LOCKED");
        lcd.printRow(1, "APP CONTROL");
    } else {
        lcd.printRow(0, "Control Mode:");
        char line[17];
        snprintf(line, sizeof(line), "> %s", uiAuto ? "AUTOMATIC" : "MANUAL");
        lcd.printRow(1, line);
    }
}

static void renderInfo() {
    char line1[17], line2[17];
    snprintf(line1, sizeof(line1), "IP:%s", uiWifiOk ? uiIp : "N/A");
    lcd.printRow(0, line1);

    unsigned long s = millis() / 1000;
    unsigned long m = (s / 60) % 60;
    unsigned long h = s / 3600;
    snprintf(line2, sizeof(line2), "Up:%luh%lum v1.2", h, m);
    lcd.printRow(1, line2);
}

// ======================================================================
//  Button handlers per screen
// ======================================================================

static void handleHomeButtons() {
    if (btnPressed[B_MOVE] || btnPressed[B_SELECT]) {
        currentScreen = SCREEN_MENU;
        menuIndex = 0;
        lcd.clear();
    }
    if (btnPressed[B_UP] || btnPressed[B_DOWN]) {
        homePhase++;
        // lastHomePhase mismatch triggers clear in renderHome()
    }
}

static void handleMenuButtons() {
    if (btnPressed[B_UP])   { menuIndex = (menuIndex - 1 + MENU_ITEMS) % MENU_ITEMS; lcd.clear(); }
    if (btnPressed[B_DOWN]) { menuIndex = (menuIndex + 1) % MENU_ITEMS; lcd.clear(); }
    if (btnPressed[B_SELECT] || btnPressed[B_MOVE]) {
        switch (menuIndex) {
            case 0: currentScreen = SCREEN_CONTROL;    controlIndex = 0; break;
            case 1: currentScreen = SCREEN_THRESHOLDS; threshIndex  = 0; break;
            case 2:
                currentScreen  = SCREEN_FAN_CYCLE;
                fcField        = 0;
                fcEditingField = false;
                fcEditEnabled  = uiFanCycle;
                fcEditOnMin    = uiFanCycleOnSec  / 60;
                fcEditOffMin   = uiFanCycleOffSec / 60;
                break;
            case 3: currentScreen = SCREEN_MODE;   break;
            case 4: currentScreen = SCREEN_INFO;   break;
            case 5: currentScreen = SCREEN_HOME; homePhase = 0; lastHomePhase = -1; break;
        }
        lcd.clear();
    }
}

static void handleControlButtons() {
    if (btnPressed[B_UP])   { controlIndex = (controlIndex - 1 + CTRL_ITEMS) % CTRL_ITEMS; lcd.clear(); }
    if (btnPressed[B_DOWN]) { controlIndex = (controlIndex + 1) % CTRL_ITEMS; lcd.clear(); }

    if (btnPressed[B_SELECT]) {
        if (controlIndex < CTRL_ITEMS - 1) {
            if (isActuatorLocked(controlIndex)) {
                // The main sketch's own onUiToggle() guard would block
                // these too; checking here as well avoids a pointless
                // callback + confusing button blip on a locked entry.
                Serial.println("[UI] Control blocked: locked (safety/auto/cycle)");
            } else {
                if (toggleCallback) toggleCallback(controlIndex);
                lcd.clear();
            }
        } else {
            // < Back
            currentScreen = SCREEN_MENU;
            lcd.clear();
        }
    }

    if (btnPressed[B_MOVE]) {
        currentScreen = SCREEN_MENU;
        lcd.clear();
    }
}

static void handleThreshButtons() {
    if (btnPressed[B_UP])   { threshIndex = (threshIndex - 1 + THRESH_ITEMS) % THRESH_ITEMS; lcd.clear(); }
    if (btnPressed[B_DOWN]) { threshIndex = (threshIndex + 1) % THRESH_ITEMS; lcd.clear(); }
    if (btnPressed[B_SELECT]) {
        if (threshIndex < THRESH_ITEMS - 1) {
            editIndex = threshIndex;
            editValue = getThreshValue(threshIndex);
            stepIdx   = 2;
            currentScreen = SCREEN_EDIT_THRESH;
            lcd.clear();
        } else {
            currentScreen = SCREEN_MENU;
            lcd.clear();
        }
    }
    if (btnPressed[B_MOVE]) {
        currentScreen = SCREEN_MENU;
        lcd.clear();
    }
}

static void handleEditThreshButtons() {
    if (btnPressed[B_UP]) {
        editValue += stepSizes[stepIdx];
        if (editValue > threshMax(editIndex)) editValue = threshMax(editIndex);
        lcd.clear();
    }
    if (btnPressed[B_DOWN]) {
        editValue -= stepSizes[stepIdx];
        if (editValue < 0) editValue = 0;
        lcd.clear();
    }
    if (btnPressed[B_MOVE]) {
        stepIdx = (stepIdx + 1) % NUM_STEPS;
        lcd.clear();
    }
    if (btnPressed[B_SELECT]) {
        setThreshValue(editIndex, editValue);
        if (thresholdCallback) thresholdCallback(editIndex, editValue);
        currentScreen = SCREEN_THRESHOLDS;
        lcd.clear();
    }
}

// Two levels, so UP/DOWN, SELECT and MOVE each keep one consistent meaning
// throughout (matches how CONTROL/THRESHOLDS already behave):
//   List level:  UP/DOWN move the cursor between Enabled/On Time/Off Time/
//                Back. SELECT acts on the highlighted row — toggles
//                Enabled in place, or drills into an edit screen for On/Off
//                Time, or (on Back) commits the working copy and returns to
//                MENU. MOVE always steps back one level: from the list,
//                that's MENU (also committing, so a MOVE-out doesn't
//                silently discard edits).
//   Edit level:  UP/DOWN adjust the selected minute value by FC_STEP_MIN,
//                clamped to [FC_MIN_MIN, FC_MAX_MIN]. Both SELECT and MOVE
//                return to the list — there's nothing further to select
//                once you're editing a single value.
// A long-press MOVE (handled globally, before this ever runs) still
// escapes straight to HOME without saving, same as every other screen.
static void handleFanCycleButtons() {
    if (fcEditingField) {
        unsigned long *val = (fcField == 1) ? &fcEditOnMin : &fcEditOffMin;
        if (btnPressed[B_UP]) {
            *val = (*val + FC_STEP_MIN > FC_MAX_MIN) ? FC_MAX_MIN : *val + FC_STEP_MIN;
            lcd.clear();
        }
        if (btnPressed[B_DOWN]) {
            *val = (*val > FC_STEP_MIN) ? *val - FC_STEP_MIN : FC_MIN_MIN;
            lcd.clear();
        }
        if (btnPressed[B_SELECT] || btnPressed[B_MOVE]) {
            fcEditingField = false;
            lcd.clear();
        }
        return;
    }

    if (btnPressed[B_UP])   { fcField = (fcField - 1 + FC_ITEMS) % FC_ITEMS; lcd.clear(); }
    if (btnPressed[B_DOWN]) { fcField = (fcField + 1) % FC_ITEMS; lcd.clear(); }

    if (btnPressed[B_SELECT]) {
        if (fcField == 0) {
            fcEditEnabled = !fcEditEnabled;
            lcd.clear();
        } else if (fcField == 1 || fcField == 2) {
            fcEditingField = true;
            lcd.clear();
        } else {
            // Back: commit the working copy and return to MENU.
            if (fanCycleCallback) {
                fanCycleCallback(fcEditEnabled, fcEditOnMin * 60UL, fcEditOffMin * 60UL);
            }
            currentScreen = SCREEN_MENU;
            lcd.clear();
        }
    }

    if (btnPressed[B_MOVE]) {
        if (fanCycleCallback) {
            fanCycleCallback(fcEditEnabled, fcEditOnMin * 60UL, fcEditOffMin * 60UL);
        }
        currentScreen = SCREEN_MENU;
        lcd.clear();
    }
}

static void handleModeButtons() {
    if (uiSafetyOverride) {
        // Mode locked during safety - any button goes back
        if (btnPressed[B_SELECT] || btnPressed[B_MOVE]) {
            currentScreen = SCREEN_MENU;
            lcd.clear();
        }
        return;
    }
    if (uiAppOwnsControl) {
        // Mode locked while the app owns control - any button goes back,
        // same treatment as the safety lock above.
        if (btnPressed[B_SELECT] || btnPressed[B_UP] || btnPressed[B_DOWN] || btnPressed[B_MOVE]) {
            currentScreen = SCREEN_MENU;
            lcd.clear();
        }
        return;
    }
    if (btnPressed[B_SELECT] || btnPressed[B_UP] || btnPressed[B_DOWN]) {
        uiAuto = !uiAuto;
        if (modeCallback) modeCallback(uiAuto);
        lcd.clear();
    }
    if (btnPressed[B_MOVE]) {
        currentScreen = SCREEN_MENU;
        lcd.clear();
    }
}

static void handleInfoButtons() {
    if (btnPressed[B_SELECT] || btnPressed[B_MOVE]) {
        currentScreen = SCREEN_MENU;
        lcd.clear();
    }
}

// ======================================================================
//  Public API
// ======================================================================

void ui_init() {
    for (int i = 0; i < NUM_BTNS; i++) {
        pinMode(btnPins[i], INPUT_PULLUP);
        btnLast[i]    = false;
        btnPressed[i] = false;
        btnHeld[i]    = false;
        holdFired[i]  = false;
        btnTime[i]    = 0;
        btnLastAccepted[i] = 0;
    }

    lcd.begin(&Wire, LCD_ADDR, LCD_COLS, LCD_ROWS);
    lcd.backlight(true);

    lcd.createChar(CHAR_IDX_THERM,   CHAR_THERM);
    lcd.createChar(CHAR_IDX_DROP,    CHAR_DROP);
    lcd.createChar(CHAR_IDX_WIFI_OK, CHAR_WIFI_OK);
    lcd.createChar(CHAR_IDX_WIFI_X,  CHAR_WIFI_X);
    lcd.createChar(CHAR_IDX_LOCK,    CHAR_LOCK);
    lcd.createChar(CHAR_IDX_DEGREE,  CHAR_DEGREE);
    lcd.createChar(CHAR_IDX_ONDOT,   CHAR_ONDOT);

    lcd.clear();
    lcd.printRow(0, "Poultry Farm");
    lcd.printRow(1, "Starting...");

    Serial.println("[UI] LCD + 4 buttons initialized");
}

void ui_update() {
    readButtons();

    for (int i = 0; i < NUM_BTNS; i++) {
        if (btnPressed[i]) Serial.printf("[UI] %s pressed (screen=%s)\n", btnName(i), screenName(currentScreen));
        if (btnHeld[i])    Serial.printf("[UI] %s held (screen=%s)\n", btnName(i), screenName(currentScreen));
    }

    UiScreen prevScreen = currentScreen;

    // Global: long-press SELECT (5s) → WiFi/AP-mode reset. Checked before
    // everything else so it pre-empts every screen's own SELECT handling
    // while held past the warning threshold, and takes over the LCD
    // directly for the live countdown (bypassing the normal render switch
    // below entirely for this tick).
    if (checkApResetHold()) return;

    // Global: long-press MOVE → HOME from any screen
    if (checkMoveHold()) {
        if (currentScreen != prevScreen) {
            Serial.printf("[UI] Screen: %s -> %s\n", screenName(prevScreen), screenName(currentScreen));
        }
        return;
    }

    // Handle buttons for current screen
    switch (currentScreen) {
        case SCREEN_HOME:        handleHomeButtons();       break;
        case SCREEN_MENU:        handleMenuButtons();       break;
        case SCREEN_CONTROL:     handleControlButtons();    break;
        case SCREEN_THRESHOLDS:  handleThreshButtons();     break;
        case SCREEN_EDIT_THRESH: handleEditThreshButtons(); break;
        case SCREEN_FAN_CYCLE:   handleFanCycleButtons();   break;
        case SCREEN_MODE:        handleModeButtons();       break;
        case SCREEN_INFO:        handleInfoButtons();       break;
    }

    if (currentScreen != prevScreen) {
        Serial.printf("[UI] Screen: %s -> %s\n", screenName(prevScreen), screenName(currentScreen));
    }

    // Refresh LCD at the idle interval, EXCEPT skip the wait whenever a
    // button just did something — otherwise a press can sit invisible on
    // screen for up to LCD_REFRESH (1s), and the user re-presses before
    // seeing it land, which then acts on the already-updated state (looks
    // like a missed press / double toggle).
    bool inputActivity = (currentScreen != prevScreen);
    for (int i = 0; i < NUM_BTNS && !inputActivity; i++) {
        inputActivity = btnPressed[i] || btnHeld[i];
    }

    unsigned long now = millis();
    if (!inputActivity && (now - lastRefresh < LCD_REFRESH)) return;
    lastRefresh = now;

    // Auto-rotate home screen every 5 seconds
    if (currentScreen == SCREEN_HOME && (now - homeRotate >= 5000)) {
        homeRotate = now;
        homePhase++;
    }

    // Render current screen
    switch (currentScreen) {
        case SCREEN_HOME:        renderHome();        break;
        case SCREEN_MENU:        renderMenu();        break;
        case SCREEN_CONTROL:     renderControl();     break;
        case SCREEN_THRESHOLDS:  renderThresholds();  break;
        case SCREEN_EDIT_THRESH: renderEditThresh();  break;
        case SCREEN_FAN_CYCLE:   renderFanCycle();    break;
        case SCREEN_MODE:        renderMode();        break;
        case SCREEN_INFO:        renderInfo();        break;
    }
}

void ui_setSensorData(const SensorData *data) {
    memcpy(&uiSensors, data, sizeof(SensorData));
}

void ui_setControlStates(bool fan, bool cooler, bool heater, bool humidifier,
                         bool autoMode, bool safetyOverride, bool appOwnsControl) {
    uiFan = fan; uiCooler = cooler; uiHeater = heater; uiHumidifier = humidifier;
    uiAuto = autoMode;
    uiSafetyOverride = safetyOverride;
    uiAppOwnsControl = appOwnsControl;
}

void ui_setThresholds(const Thresholds *t) {
    memcpy(&uiThresh, t, sizeof(Thresholds));
}

void ui_setWifiInfo(const char *ip, bool connected) {
    strncpy(uiIp, ip, sizeof(uiIp) - 1);
    uiIp[sizeof(uiIp) - 1] = '\0';
    uiWifiOk = connected;
}

void ui_setFanCycle(bool enabled, unsigned long onSec, unsigned long offSec) {
    uiFanCycle = enabled;
    uiFanCycleOnSec  = onSec;
    uiFanCycleOffSec = offSec;
}
