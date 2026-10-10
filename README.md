# Smart Poultry Farm

An end-to-end IoT climate controller for a poultry house: an **ESP32 controller** reads temperature, humidity and ammonia, drives a fan, an evaporative cooler, a heater and a humidifier, and enforces hard safety limits on its own. A **Flutter app** (English / Arabic) watches and controls it through **Firebase Realtime Database**, receives push alerts, and shows the output of an external **vision AI** bird-monitoring feed.

The controller keeps working with no internet at all: a 16x2 LCD and four buttons give full local control, automatic climate control runs on the device, and control ownership hands itself back to the LCD whenever the cloud is unreachable.

```
   ┌─────────────────────────────┐        HTTPS REST + SSE        ┌────────────────────┐
   │  ESP32 controller           │ ─────────────────────────────▶ │ Firebase Realtime  │
   │  AM2302 · MQ135 · 4 relays  │ ◀───────────────────────────── │ Database  (farm/)  │
   │  16x2 LCD · 4 buttons       │                                └─────────┬──────────┘
   └──────────────┬──────────────┘                                          │
                  │ OneSignal REST (push)                                   │ Firebase SDK
                  ▼                                                          ▼
   ┌─────────────────────────────┐                                ┌────────────────────┐
   │  Phone notification         │                                │  Flutter app       │
   │  (lock-screen visible)      │                                │  Android / iOS     │
   └─────────────────────────────┘                                └────────────────────┘
                                                                            ▲
                                        PoultrySystem/vision/analysis        │
                        ┌───────────────────────────────────────────────────┘
                        │
   ┌────────────────────┴────────┐
   │  GallineX vision analyzer   │   (external desktop tool, not in this repo)
   └─────────────────────────────┘
```

## Features

**Controller (ESP32, Arduino C++)**
- Dual-core FreeRTOS design: Core 1 runs sensors, safety, buttons and the LCD every 10 ms and never blocks; Core 0 does every HTTPS call.
- Automatic climate control with hysteresis: heater on low temperature, cooler + fan on high temperature, humidifier on low humidity, fan on high humidity or gas.
- Hard safety layer that overrides everything: dangerous gas, critical cold/heat, critical humidity. Alerts go to Firebase and, via OneSignal, straight to every phone.
- Comfort-range warnings whenever a reading leaves the farmer's own configured range.
- Scheduled "fan cycle" airing (e.g. 3 h on / 2 h off) that keeps running through a network outage.
- Sub-500 ms app-to-device latency using a Firebase Server-Sent-Events stream on the small `control` node; rarely changing settings are polled.
- Control ownership: the app owns control only while it can actually reach the device. After 90 s of cloud silence the LCD takes over automatically and the app regains control on the first successful contact.
- Full local UI: home pages, control, thresholds, fan cycle, mode, info. Long-press SELECT wipes WiFi and reopens the setup portal.
- WiFi provisioning through a captive portal hotspot, credentials in NVS, automatic recovery when the router comes up late after a power cut.
- Browser-based OTA firmware upload at `http://poultryfarm.local/` (basic-auth).

**App (Flutter, Riverpod)**
- Live dashboard, actuator toggles, Auto/Manual, App Control toggle, safety banners.
- Threshold and fan-cycle settings, dark mode, English/Arabic with correct RTL handling.
- Alerts list with badge, lock-screen push notifications on a dedicated high-importance channel.
- Vision AI tab: latest analysis snapshot, trends, and a rule engine that raises alarms (unhealthy rate, low activity, bird-count drop, overcrowding, feeding stalled, stale feed).
- Sensor history recorder: the app appends every new reading to `farm/sensors/history`.
- WiFi provisioning wizard that talks to the controller's setup portal.

## Repository layout

```
.
├── firmware/                            ESP32 Arduino sketch (see its README)
├── app/                                 Flutter mobile app (see its README)
├── vision_alerts_prototype/             Browser prototype the vision feature was ported from
├── docs/
│   ├── ARCHITECTURE.md                  How the pieces fit, control priority, ownership rules
│   ├── FIREBASE_SCHEMA.md               Every node under farm/ and who writes it
│   ├── HARDWARE.md                      Bill of materials, wiring, pin map
│   └── CHANGELOG.md                     Test rounds with the hardware team
├── releases/                            Latest Android APK for testers
├── LICENSE
└── README.md
```

## Quick start

### 1. Firebase
1. Create a Firebase project with a **Realtime Database**.
2. Enable **Authentication → Anonymous** (the app signs in anonymously).
3. Note the database URL (`https://<project>-default-rtdb.firebaseio.com`) and a database secret (Project settings → Service accounts → Database secrets). The secret is only used by the firmware.
4. Optional: create a **OneSignal** app for push notifications and note its App ID and REST API key.

### 2. Firmware
Requirements: Arduino IDE 2.x, the `esp32` board package 3.x, and the **ArduinoJson 7.x** library.

```bash
cd firmware
cp secrets.example.h secrets.h      # fill in WiFi, Firebase secret, OneSignal keys
```

Open the sketch in Arduino IDE, choose **ESP32 Dev Module**, and upload. Or from the command line:

```bash
arduino-cli compile --fqbn esp32:esp32:esp32 firmware
arduino-cli upload  --fqbn esp32:esp32:esp32 -p COM6 firmware
```

On first boot with no saved network the device opens the hotspot **PoultryFarm_Setup** (password `setup123`). Join it, open `http://192.168.4.1/`, enter the farm WiFi and save. The device restarts and connects. Full details and the LCD manual are in [firmware/README.md](firmware/README.md).

### 3. App
Requirements: Flutter 3.x stable, Android Studio or Xcode.

```bash
cd app
cp .env.example .env                 # fill in Firebase values
flutterfire configure                # regenerates lib/firebase_options.dart for YOUR project
flutter pub get
flutter run
```

To build an installable Android package:

```bash
flutter build apk --release --target-platform android-arm64
```

See [app/README.md](app/README.md) for the OneSignal setup and the notification-channel contract shared with the firmware.

## How control decisions are made

Every relay change funnels through one function on the device, in this priority order:

| Priority | Source | Rule |
|---|---|---|
| 1 | Safety | Gas > 450 ppm, temp < 10 °C or > 42 °C, humidity < 30 % or > 85 %. Sets all four relays explicitly, locks every UI, alerts. |
| 2 | Fan cycle | While enabled, the schedule alone owns the Fan. |
| 3 | Auto mode | Sensor rules with hysteresis drive Heater / Cooler / Humidifier (and Fan when no cycle). Manual toggles are rejected. |
| 4 | Manual | App (if it owns control) or LCD toggles each relay. |

Two interlocks always apply: Heater and Cooler never run together, and the Cooler forces the Fan on because an evaporative pad needs airflow.

## Security notes

- `firmware/secrets.h` and `app/.env` are gitignored. Never commit them. Templates are provided as `secrets.example.h` and `.env.example`.
- The firmware authenticates with a legacy database secret and skips TLS certificate verification (`setInsecure()`). Both are acceptable for a private prototype, not for production. The path forward is per-device auth tokens, CA pinning and locked-down database rules.
- Firebase web/Android API keys in `lib/firebase_options.dart` and `google-services.json` are client identifiers, not secrets. Access is governed by database rules, which for this prototype are open. Tighten them before exposing the project publicly.

## Status

The single-controller system is feature complete and has been through five hardware test rounds (see `docs/CHANGELOG.md`). Known open items:

- MQ135 analog output is 0–5 V while the ESP32 ADC pin tolerates 3.3 V. Verify a resistor divider is present on the board, then update `MQ135_VREF`.
- The vision prototype still points at the original Firebase project URL; update `firebase-client.js` if you want to run it against the current database.
- Flash usage is at about 94 %. Adding features will need `partition scheme: Minimal SPIFFS` or trimming.

## License

MIT. See [LICENSE](LICENSE).
