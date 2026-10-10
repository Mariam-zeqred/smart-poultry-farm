# Hardware

## Bill of materials (single controller)

| Qty | Part | Notes |
|---|---|---|
| 1 | ESP32 Dev Module (WROOM-32, 4 MB) | 2.4 GHz WiFi only. Avoid WROVER unless GPIO 16/17 are freed. |
| 1 | AM2302 / DHT22 temperature-humidity sensor | Single-wire. 4.7–10 kΩ pull-up to 3.3 V on DATA. Works over a ~20 m lead with the driver's 20 ms start pulse. |
| 1 | MQ135 gas sensor module (ammonia/air quality) | 5 V heater, analog out 0–5 V. **Needs a divider to 3.3 V for the ESP32 ADC.** 3-minute warm-up. |
| 1 | 4-channel relay module, active-LOW, opto-isolated | Fan, Cooler, Heater, Humidifier. Size contactors for real loads; the module only switches the coil/contactor. |
| 1 | 16x2 character LCD with PCF8574 I2C backpack | Address 0x27 (some boards 0x3F). |
| 4 | Momentary push buttons | To GND, internal pull-ups used. |
| 1 | 5 V / 2 A power supply | ESP32 + relays + sensors. Separate supply for actuators. |
| — | Custom PCB / perfboard, screw terminals, enclosure | The current unit is a custom PCB with everything soldered on. |

## Pin map (current PCB revision, physically verified)

All pins are defined once in `firmware/config.h`.

| Signal | GPIO | Direction | Notes |
|---|---|---|---|
| Fan relay | 14 | out | Active-LOW |
| Cooler relay | 26 | out | Active-LOW |
| Heater relay | 27 | out | Active-LOW |
| Humidifier relay | 25 | out | Active-LOW |
| AM2302 data | 4 | in/out | Bit-banged single wire; pull-up required |
| MQ135 analog | 34 | in (ADC, input-only) | 11 dB attenuation, factory-calibrated millivolt read |
| LCD SDA | 33 | I2C | 100 kHz |
| LCD SCL | 32 | I2C | |
| Button UP | 17 | in, pull-up | |
| Button DOWN | 5 | in, pull-up | Strapping pin; fine as an input that is not held at boot |
| Button MOVE | 18 | in, pull-up | |
| Button SELECT | 19 | in, pull-up | |
| Status LED | 2 | out | On-board LED. Slow blink = AP/setup mode |

ESP32 rules that shaped this map: GPIO 34–39 are input-only with no pull-ups (fine for the ADC, useless for the DHT line); GPIO 6–11 are the flash bus; 0/2/15 are strapping pins.

## Wiring notes

- **Relays** drive contactors or SSRs for anything larger than a small fan. The relay board's JD-VCC should come from a separate 5 V rail with its own ground to keep coil noise off the ESP32.
- **MQ135**: power the heater from 5 V, take AOUT through a 2:1 divider (e.g. 10 kΩ / 20 kΩ) into GPIO 34, then set `MQ135_VREF` to the divided ceiling and confirm `MQ135_RL` against the resistor actually on the board.
- **AM2302**: keep the lead twisted or shielded on long runs; the firmware already tolerates the slower rise of a long cable.
- **LCD**: I2C at 100 kHz over short wires only. If the display stays blank, try address 0x3F.
- **Buttons**: the harness on the current PCB was wired mirrored from the original drawing; the pin numbers above are the tested truth.

## Bench testing

A `component_tests` sketch (kept by the hardware team) walks through I2C scan, sensor reads, a relay walkthrough (menu option 6) and an LCD-feedback button tester (option `l`). Run it after any wiring change before flashing the main firmware.
