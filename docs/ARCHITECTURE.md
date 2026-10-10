# Architecture

## Components

| Component | Runs on | Language | Talks to |
|---|---|---|---|
| Controller firmware | ESP32 (dual-core, 240 MHz, 4 MB flash) | Arduino C++ | Firebase RTDB (REST + SSE), OneSignal REST, local LCD/buttons, setup/OTA web pages |
| Mobile app | Android / iOS | Flutter (Dart, Riverpod) | Firebase RTDB (SDK), Firebase Auth (anonymous), OneSignal SDK, ESP32 setup portal over HTTP |
| Vision analyzer | Desktop PC with camera | External (not in repo) | Writes one snapshot node to Firebase |
| Vision prototype | Browser | Plain JS | Firebase RTDB (REST) |

Everything is glued together by **one Firebase Realtime Database tree** (`farm/`, plus `PoultrySystem/vision/analysis` from the analyzer). There is no backend server and no Cloud Function: the ESP32 pushes its own notifications, the app records its own history.

## Data flows

```
sensors ──2 s──▶ ESP32 ──10 s PUT──▶ farm/sensors/latest ──stream──▶ app ──append──▶ farm/sensors/history
                                     farm/meta.lastSeen (heartbeat)  ──▶ app "online" indicator

app toggle ──update──▶ farm/control/state ──SSE (<500 ms)──▶ ESP32 applyControlStateDoc() ──▶ relays
LCD toggle ──▶ relays immediately ──deferred PUT──▶ farm/control/state ──▶ app reflects it

app settings ──▶ farm/config/thresholds, farm/config/fanCycle ──poll 30 s──▶ ESP32
LCD edits   ──▶ ESP32 ──PUT──▶ same nodes ──▶ app

safety / comfort breach ──▶ ESP32 ──POST──▶ farm/alerts ──▶ app list + badge
                                  └──POST──▶ OneSignal ──▶ phone notification (lock-screen visible)

analyzer ──▶ PoultrySystem/vision/analysis ──▶ app rule engine ──▶ farm/vision/history, farm/alerts
```

## Firmware threading model

- **Core 1, `loop()`**: ~100 Hz. Buttons + LCD (`ui_update`), sensor read every 2 s, `checkSafety()`, `checkComfortAlerts()`, `evaluateAutoControl()` every 3 s, `evaluateFanCycle()`, `applyStates()`. Never performs network I/O.
- **Core 0, `firebaseTask`**: drains the deferred queue (`pendingControlPush`, `pendingAlert`, `thresholdsDirty`, `fanCycleDirty`), sends readings + heartbeat every 10 s, keeps the SSE stream alive with a 200 ms drain budget, polls thresholds/fan cycle every 30 s, services OTA uploads.
- Shared variables are guarded by `stateMutex`. `applyStates()` is always called outside the mutex because it does I2C writes.
- All Firebase HTTP calls share one persistent TLS session behind `firebaseMutex`. Transport errors reset the session; retries of a failed control push are throttled to 5 s to avoid TLS churn.

## Control priority

1. **Safety** (`checkSafety`): gas > `GAS_ABS_MAX`, temperature outside `TEMP_ABS_MIN..MAX`, humidity outside `HUM_ABS_MIN..MAX`. Each branch sets all four relays explicitly, sets `safetyOverride`, locks every UI, raises a critical alert (5-minute cooldown per type).
2. **Fan cycle** (`evaluateFanCycle`): while enabled, owns the Fan exclusively. Runs offline.
3. **Auto mode** (`evaluateAutoControl` → `sensors_evaluate`): hysteresis rules for Heater, Cooler+Fan, Humidifier, Fan-for-humidity, Fan-for-gas. Runs offline. Manual toggles rejected.
4. **Manual**: app (only while it owns control) or LCD.

`applyStates()` is the single choke point. It also enforces: Heater and Cooler never both on; Cooler on forces Fan on.

## Control ownership

`appOwnsControl() = appControlEnabled && wifiOk && cloudReachable()`

- `appControlEnabled` is written only by the app (`control/state.appControlEnabled`).
- `cloudReachable()` is measured: the newest of the last 2xx REST response and the last byte from the SSE stream, within `CLOUD_STALE_MS` (90 s). WiFi association alone is not enough.
- Going stale is delayed; recovery is immediate on the first successful contact.
- The LCD mirrors this as `APP CONTROL` locks; the app greys out controls when the device is offline.

## Echo and race handling

- Incoming stream events are merged onto current local state, never treated as a whole object (Firebase sends partial `patch` events for the app's per-field updates).
- The device only pushes its state back when `applyStates()` corrected something beyond what was requested, so its own echo cannot bounce a command.
- Every device-originated push starts a 3 s write cooldown on the threshold/fan-cycle polls so the app's write wins if both sides edited at once.

## Startup sequence

1. Serial, mutex, I2C, GPIO (all relays off), sensors.
2. `config_load`: defaults → SPIFFS `config.csv` → NVS (`wifi_creds`, `device_cfg`).
3. If credentials exist and no forced-AP flag: scan, connect (20 s). On success: Firebase init, meta + heartbeat, OTA server, sync control state/thresholds/fan cycle, open SSE stream, launch `firebaseTask` on Core 0.
4. Otherwise: hotspot `PoultryFarm_Setup`, provisioning portal, and a late-connect recovery loop that keeps retrying the saved network every 30 s and reboots into normal mode as soon as it associates.

## App layering

- `core/models` are dumb, defensively parsed mirrors of the Firebase nodes.
- `features/*/providers` hold repositories; the dashboard watches one combined `DeviceSnapshot` stream.
- Screens contain no Firebase calls. All writes go through `DeviceRepository`, which applies the same safety/auto/cycle guards the firmware enforces.
- Localisation is key-based end to end; providers emit message keys, never English strings.
