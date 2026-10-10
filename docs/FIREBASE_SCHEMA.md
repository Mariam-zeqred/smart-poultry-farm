# Firebase Realtime Database schema

One flat tree under `farm/` for the single controller, plus one external node written by the vision analyzer. Timestamps are epoch milliseconds; the firmware writes them with the server sentinel `{".sv": "timestamp"}`.

Field names are string contracts shared by the firmware (`firebase_client.cpp`, the `.ino`) and the app (`core/models/*.dart`). Rename in both places at once.

```
farm/
├── meta/
│   ├── deviceName        string   user-editable label (app); firmware seeds it once, never overwrites
│   ├── firmware          string   FIRMWARE_VERSION, written at boot
│   ├── localIp           string   current LAN IP (for the OTA page)
│   ├── status            "online"
│   ├── owner             string   USER_ID
│   ├── lastSeen          ms       heartbeat, PATCHed every 10 s     ← app's "online" test
│   ├── startupTime       ms       last boot
│   └── registered        ms       written by the app seeder only
│
├── sensors/
│   ├── latest/                                   PUT by firmware every 10 s
│   │   ├── temperature   °C
│   │   ├── humidity      %
│   │   ├── gas           ppm (0 during MQ135 warm-up)
│   │   └── ts            ms
│   └── history/{YYYY-MM-DD-HH}/{pushId}/         appended by the APP, never by the device
│       └── (same four fields)
│
├── control/
│   └── state/                                    streamed to the device (SSE); PUT by firmware, update() by app
│       ├── fanState, coolerState, heaterState, humidifierState   bool
│       ├── controlMode        "automatic" | "manual"
│       ├── appControlEnabled  bool   written only by the app; true = app owns control
│       ├── reason             string  why the device last changed state
│       ├── safetyOverride     bool    true while a hard safety limit is active
│       └── updated_at         ms
│
├── config/
│   ├── thresholds/                               polled by the device every 30 s
│   │   ├── temperatureHigh, temperatureLow   °C
│   │   ├── humidityHigh, humidityLow         %
│   │   ├── gasHigh                            ppm
│   │   └── hysteresis                         °C / % band applied by the device
│   ├── fanCycle/                                 polled every 30 s
│   │   ├── enabled       bool
│   │   ├── onSec         seconds
│   │   └── offSec        seconds
│   └── visionThresholds/                         app + prototype only
│       ├── unhealthyWarnPct, unhealthyCriticalPct
│       ├── activityLowSustainedCount
│       ├── birdCountDropPct, birdCountSustainedCount
│       ├── hotspotSpikeRatio
│       ├── feedingStalledPct, feedingSustainedCount
│       └── staleMinutes
│
├── alerts/{pushId}/                              POST by firmware; vision alerts by app/prototype
│   ├── type          see table below
│   ├── severity      "warning" | "critical" | "info"
│   ├── message       human text (English, from the device)
│   ├── value         number that tripped it
│   ├── threshold     limit it was compared to
│   ├── createdAt     ms
│   ├── deviceId      "" = controller,  "vision-ai" = vision engine
│   ├── acknowledgedAt, resolvedAt   ms, set by the app
│   └── params        {name: number}  vision alerts only, for localised rendering
│
└── vision/
    └── history/{unixMs}/                         compact log appended by the app from each analyzer snapshot

PoultrySystem/
└── vision/
    └── analysis/                                 single overwritten snapshot from the external analyzer
```

## Alert types

| `type` | Origin | Severity | Trigger |
|---|---|---|---|
| `gas_critical` | device | critical | gas > `GAS_ABS_MAX` (450 ppm) |
| `temp_critical_low` / `temp_critical_high` | device | critical | temp < 10 °C / > 42 °C |
| `hum_critical_low` / `hum_critical_high` | device | critical | humidity < 30 % / > 85 % |
| `temperature_high` / `temperature_low` | device | warning | outside `config/thresholds` range |
| `humidity_high` / `humidity_low` | device | warning | outside range |
| `gas_detected` | device | warning | gas > `gasHigh` |
| `vision_stale`, `vision_unhealthy_rate`, `vision_activity_low`, `vision_bird_count_drop`, `vision_overcrowding`, `vision_feeding_stalled`, `vision_combined_health_activity_risk`, `vision_combined_mortality_risk` | app / prototype | warning or critical | rules in `vision_alert_engine` |

Device alerts of the same type are rate-limited to one per 5 minutes (`ALERT_COOLDOWN`). Critical and warning alerts of the same dimension have separate cooldown slots.

## Who writes what

| Node | Device | App | Vision |
|---|---|---|---|
| `meta` | heartbeat, identity | `deviceName` | — |
| `sensors/latest` | PUT | read | — |
| `sensors/history` | — | append | — |
| `control/state` | full PUT after each local change | partial `update` | — |
| `config/thresholds`, `config/fanCycle` | PUT after LCD edits | PUT | — |
| `config/visionThresholds` | — | PUT | read |
| `alerts` | POST | ack / resolve / delete | POST / resolve |
| `vision/history` | — | append | append (prototype) |
| `PoultrySystem/vision/analysis` | — | read | written by external analyzer |

## Security rules

The prototype runs with open rules (`.read: true, .write: true`) and the device authenticates with a legacy database secret. Anything beyond a private prototype needs per-device custom tokens, rules that let a device write only its own subtree, and app users scoped to their farm.
