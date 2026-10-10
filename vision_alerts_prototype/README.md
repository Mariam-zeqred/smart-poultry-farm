# Vision Alerts Prototype (browser)

A dependency-free HTML/JS test bed for the vision-AI alarm rules. It was the design reference for the Flutter app's **AI Monitor** tab: `vision-alert-engine.js` and `alerts-store.js` were ported line-for-line to `app/lib/core/services/vision_alert_engine.dart` and `app/lib/features/vision/providers/vision_repository.dart`.

Keep it around for two reasons: it is the quickest way to try a rule change against real data without a phone, and its **Simulate** buttons replay nine scenarios (normal, unhealthy rate warning/critical, low activity, bird-count drop, overcrowding, feeding stalled, combined mortality risk, stale feed).

## Files

| File | Role |
|---|---|
| `index.html`, `style.css` | Single-page UI: snapshot card, trend sparklines, alerts drawer, thresholds editor |
| `main.js` | Polling loop, rendering, simulate buttons, toasts |
| `firebase-client.js` | Tiny REST wrapper (`GET/PUT/PATCH/POST/DELETE` on `.json` endpoints) |
| `vision-alert-engine.js` | Pure rule engine: snapshot + history + thresholds → list of conditions |
| `alerts-store.js` | Reconciles conditions against `farm/alerts` (raise, resolve, de-duplicate) |

## Run

Open `index.html` in any modern browser. No build step, no server.

Before running, set `DB_URL` in `firebase-client.js` to your Realtime Database URL. The prototype currently points at the project's **original** database (`poultrysystem-1e315`); the firmware and app have since moved to `poultryfarm-v1-mm`. It talks to the database over plain REST with no auth, which only works while the database rules are open.

## Data it reads and writes

- Reads `PoultrySystem/vision/analysis` (the analyzer's latest snapshot) and `farm/config/visionThresholds`.
- Appends to `farm/vision/history/{unixMs}`.
- Raises/resolves alerts in `farm/alerts` with `deviceId: "vision-ai"`.
