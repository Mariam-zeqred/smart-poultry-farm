# ESP32 Controller Firmware

Arduino sketch for the Smart Poultry Farm controller. One ESP32 reads an AM2302 temperature/humidity sensor and an MQ135 gas sensor, drives four relays, runs a 16x2 LCD menu on four buttons, and syncs with Firebase Realtime Database.

## Build

| Item | Value |
|---|---|
| Board | ESP32 Dev Module (`esp32:esp32:esp32`), esp32 core 3.x |
| Library | ArduinoJson 7.x (Library Manager). Everything else ships with the ESP32 core. |
| Sketch | `firmware/firmware.ino` (Arduino requires the folder and sketch names to match, so keep both as `firmware`) |
| Flash usage | ~94 % of the default 1.3 MB app partition. Watch this before adding features. |

1. Copy `secrets.example.h` to `secrets.h` and fill in the WiFi fallback, the Firebase database secret and (optionally) the OneSignal keys. `secrets.h` is gitignored.
2. Check `config.h` for pins, thresholds and timings. It is the only file that defines any of those.
3. Upload from Arduino IDE, or:

```bash
arduino-cli compile --fqbn esp32:esp32:esp32 firmware
arduino-cli upload  --fqbn esp32:esp32:esp32 -p COM6 firmware
```

Serial Monitor at 115200 baud prints a `[STATUS]` line every 10 s with WiFi state, cloud reachability, readings, relay states, mode and who owns control. That one line is the fastest way to see the whole system.

## Source map

| File | Role |
|---|---|
| `firmware.ino` | Orchestration: shared state, safety, auto-control, fan cycle, stream callback, `firebaseTask` (Core 0), `setup()`/`loop()` (Core 1). The header comment explains the two-core design and control priority. |
| `config.h` | Every pin, threshold, timing constant. Includes `secrets.h`. |
| `secrets.example.h` | Template for the gitignored `secrets.h`. |
| `config_loader.*` | Resolves runtime config: compiled defaults → `data/config.csv` on SPIFFS → NVS values saved by the setup portal. |
| `sensors.*` | AM2302/DHT22 bit-banged driver with bounded timeouts, MQ135 ppm conversion with warm-up gate, and `sensors_evaluate()` (the auto-control rules). |
| `command_handler.*` | Relay GPIO writes. Honors `RELAY_ACTIVE_LOW`. |
| `firebase_client.*` | REST client over a persistent TLS session, mutex-guarded. Sensors, control state, thresholds, fan cycle, meta heartbeat, alerts. |
| `firebase_stream.*` | Server-Sent-Events client subscribed to `farm/control` for instant commands. |
| `onesignal_client.*` | Push notification POST to OneSignal, called after each alert. |
| `lcd_display.*` | Minimal HD44780 driver over a PCF8574 I2C backpack (no external library). |
| `ui_manager.*` | LCD screens, 4-button state machine, debounce, long-press actions. |
| `wifi_provision.*` | Captive setup portal served while in AP mode. Saves to NVS and reboots. |
| `ota_update.*` | Basic-auth firmware upload page at `http://poultryfarm.local/` while on WiFi. |
| `data/config.csv` | Optional SPIFFS overrides (database URL, AP name). Upload with the ESP32 Sketch Data Upload tool. |

## Runtime behaviour in one page

**Two cores.** `loop()` on Core 1 runs every ~10 ms: buttons, LCD, sensor reads every 2 s, `checkSafety()`, comfort-range alerts, `evaluateAutoControl()` every 3 s, `evaluateFanCycle()`. It never calls the network. `firebaseTask` on Core 0 drains the deferred push queue, sends readings every 10 s, keeps the SSE stream alive, polls thresholds and fan cycle every 30 s, handles OTA uploads.

**Control priority.** Safety → fan cycle → auto mode → manual. `applyStates()` is the only function that touches relays; it also enforces Heater/Cooler exclusion and Cooler-forces-Fan.

**Who may command.** `appOwnsControl()` is true only when the app has enabled App Control *and* the device has heard from Firebase within the last 90 s. Otherwise the LCD owns control. This is why a router that is up while the internet is down never locks the farmer out.

**Offline.** Auto control and fan cycle run with no network. Local changes made during an outage are retried until they land, so the cloud cannot overwrite them with stale state on reconnect.

## LCD manual

Buttons: **UP**, **DOWN**, **MOVE** (back / enter menu; hold 1 s = home), **SELECT** (act / confirm; hold 5 s from any screen = wipe WiFi and reopen setup portal, with an on-screen countdown you can cancel by releasing).

| Screen | What it shows / does |
|---|---|
| HOME page 1 | Temperature, humidity, WiFi icon (bars = connected, X = not), gas ppm |
| HOME page 2 | FAN / HTR / CLR / HUM on-off, then `A` (auto), `M` (manual) or a lock icon (safety or app control) |
| MENU | Control · Thresholds · Fan Cycle · Mode · Info · Back |
| CONTROL | Toggle each relay. Locked rows explain why: `!SAFETY LOCK!`, `APP CONTROL`, `AUTO (see MODE)`, `CYCLE`, `NEEDS CLR OFF` |
| THRESHOLDS | Browse Temp Hi/Lo, Hum Hi/Lo, Gas Hi; SELECT to edit with UP/DOWN, MOVE changes step size |
| FAN CYCLE | Enabled on/off, On time, Off time (minutes, 5-minute steps). Leaving the list saves. |
| MODE | Automatic ↔ Manual |
| INFO | IP address, uptime, firmware version |

## WiFi setup and recovery

- No saved network, or SELECT held 5 s → hotspot `PoultryFarm_Setup` / `setup123`, portal at `http://192.168.4.1/`.
- The device gives a saved network 20 s at boot. If the router comes up later (typical after a power cut) it keeps retrying every 30 s from inside the portal and restarts into normal mode as soon as it connects, unless someone is actively using the setup page.
- ESP32 is 2.4 GHz only. WPA2-PSK/AES networks are the most reliable; some ISP routers with WPA/WPA2-mixed TKIP fail the handshake.

## Firebase contract

All paths are flat under `farm/`. The full node list, field names and who writes each node are in [`../../docs/FIREBASE_SCHEMA.md`](../../docs/FIREBASE_SCHEMA.md). Field names are shared string contracts with the Flutter app; rename them in both places or nothing talks.

The Android notification channel id `farm_alerts` (`ONESIGNAL_ANDROID_CHANNEL_ID`) must match `ALERT_CHANNEL_ID` in the app's `MainActivity.kt`.

## Known hardware caveats

- MQ135 outputs 0–5 V; the ESP32 ADC pin is 3.3 V max. Confirm a divider is present and set `MQ135_VREF` to the divided ceiling. The driver logs raw ADC, voltage and Rs on every read to help calibrate.
- MQ135 needs a 3-minute warm-up after power on; gas reads 0 until then.
- AM2302 needs a 4.7–10 kΩ pull-up on the data line. The driver idles the line for 3 s after three consecutive failed reads to let a wedged sensor recover.
- Relays are active-LOW (`RELAY_ACTIVE_LOW true`). Flip once in `config.h` if a different module is used.
