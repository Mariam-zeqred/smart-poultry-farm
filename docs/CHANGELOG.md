# Changelog

Test rounds with the hardware team, newest first. Firmware version string is `FIRMWARE_VERSION` in `config.h`.

## 2026-09-10 — Repository clean-up
- Credentials moved out of `config.h` into a gitignored `secrets.h` (template: `secrets.example.h`).
- READMEs for the repository, firmware, app and vision prototype; architecture, schema and hardware docs.
- File-level documentation added to the Flutter sources; stale pin numbers in `ui_manager` headers corrected.
- Boilerplate Flutter counter test removed (it never applied to this app).

## 2026-09-03 — Firmware 1.4.0-ota (post-test fixes)
- **AP-mode latch**: after a power cut the router often comes up later than the ESP32, which then sat in the setup portal forever with credentials intact. The device now keeps retrying the saved network from inside the portal and restarts into normal mode as soon as it connects (never while someone is using the setup page).
- **Home screen App-Control indicator**: page 2 now shows the lock icon for App Control as well as Safety, matching the Control and Mode screens.
- **Fan toggle while Cooler on**: previously logged "Toggled Fan" but nothing changed because the Cooler interlock immediately re-forced the Fan on. The LCD now shows `NEEDS CLR OFF` and rejects the toggle with an explicit reason.

## 2026-09-02 — Offline control + lock-screen notifications (firmware + app)
- Auto control and fan cycle moved to Core 1 and run with no network. Previously auto control lived behind the "skip if WiFi down" gate and never ran on a device that booted into AP mode.
- LCD state is refreshed in AP mode too, so the Control screen no longer looks unlocked while silently rejecting presses.
- **Cloud reachability is measured**, not inferred from WiFi association. After 90 s without a successful Firebase contact the LCD regains control; the app regains it on the first successful contact.
- Failed control pushes are retried instead of dropped, so an LCD change during an outage cannot be overwritten by stale cloud state on reconnect.
- App creates a public, high-importance `farm_alerts` notification channel; firmware posts to it, so alert text is readable on the lock screen.
- Device renamed to `Mr.Mahmoud_Device`.

## 2026-08-30 — Settings clean-up
- App Control toggle moved to Settings; fan cycle accepts any duration.
- Hysteresis from `config/thresholds` is now actually applied by the firmware (it previously used a hidden 10 % band).
- Stream drain limited to 200 ms per call so a burst of events cannot starve the sensor heartbeat.
- Device only echoes state back when `applyStates()` corrected the request, closing a self-sustaining on/off loop seen live.
- MQ135 driver logs raw ADC, voltage and Rs each read; datasheet mismatch (5 V output vs 3.3 V ADC) flagged for hardware verification.

## 2026-08-29 — Firmware 1.3.x + App Control (two builds)
- Auto and Manual made mutually exclusive; actuator fields are ignored while Auto so nothing can fight auto control.
- SSE stream narrowed from the whole `farm/` tree to `farm/control`; thresholds and fan cycle are polled instead. This ended the buffer-overflow/reconnect loop behind random reboots.
- Fan-cycle vs Cooler interlock fight fixed (relay flicker + write flood).
- Echo race between the device's own push and a second app command fixed.
- **New**: App Control ownership toggle; SELECT hold for 5 s wipes WiFi and reopens the setup portal; push notifications via OneSignal straight from the device.
- Button refractory window (150 ms) added so one press cannot register twice.

## 2026-08-26 — First end-to-end hardware round (9 issues)
- Core 1 no longer performs blocking network calls: deferred push queue for control state and alerts (fixed the "SELECT needs five presses" lag and safety stalls).
- SSE line buffer raised; heap-corruption reboots traced to TLS churn from constant stream resets.
- Heater/Cooler mutual exclusion and Cooler-forces-Fan interlocks added in `applyStates()`.
- Provisioning form could never clear a Device ID once set; the field was removed and paths are always flat under `farm/`.
- Fan cycle editable from the LCD.

## 2026-08-24 / 25 — Sensor drivers
- AM2302 read failures traced to a `pulseIn()` composability trap that shifted every frame by one bit; replaced with a bounded busy-wait reader.
- MQ135 uses factory-calibrated `analogReadMilliVolts()` with 11 dB attenuation.
- LCD redraws immediately on any button input instead of waiting for the 1 s refresh tick.
- Settings screen threshold cards no longer overflow.

## 2026-08-18 / 19 — Actuator set and pin map
- Light and Feeder relays replaced by Cooler and Humidifier; LDR removed. Firebase fields renamed (`coolerState`, `humidifierState`).
- Relays confirmed active-LOW; `RELAY_ACTIVE_LOW` flag added.
- Physical verification found Fan/Humidifier pins swapped and the button harness mirrored; `config.h` corrected.
- Firebase project migrated to `poultryfarm-v1-mm`; app registered and Anonymous Auth enabled.
- Fan cycle feature introduced; 2-page LCD home screen with WiFi icon.
