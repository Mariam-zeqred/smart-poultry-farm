/*
 * sensors.cpp - AM2302/DHT22 (single-wire), MQ135 (ADC) drivers
 */

#include "sensors.h"
#include "config.h"

// ---- AM2302/DHT22 single-wire driver ----
// Same sensor die as the AM2320 this replaces (Aosong), just the wired
// variant — one bit-banged data line instead of I2C. DHT_PIN needs a
// 4.7-10k pull-up to 3.3V if the module doesn't already have one onboard.

// Busy-wait for DHT_PIN to reach `level`, bailing out after `timeoutUs` so a
// glitched line can't hang the firmware forever. Returns elapsed us, or -1 on
// timeout. Bounded stand-in for a raw polling loop — deliberately NOT built
// on pulseIn(): pulseIn's "skip a pulse already in progress" phase makes
// consecutive same-direction calls measure the WRONG pulse (verified — it
// was silently shifting every read's bitstream by one position, which is why
// every single read was failing checksum, not just some).
static long waitForLevel(int level, unsigned long timeoutUs) {
    unsigned long start = micros();
    while (digitalRead(DHT_PIN) != level) {
        if (micros() - start > timeoutUs) return -1;
    }
    return micros() - start;
}

static bool dht22_read(float *temp, float *hum) {
    uint8_t data[5] = {0, 0, 0, 0, 0};

    // Host start signal: pull the line low so the sensor notices, then
    // release it and let the pull-up bring it back high. Datasheet minimum
    // is 1ms, but 2ms proved unreliable on the real board (HW team confirmed
    // reads failed) — bumped to 20ms, which is what they verified works,
    // likely needed for signal stability over the actual wire run length.
    pinMode(DHT_PIN, OUTPUT);
    digitalWrite(DHT_PIN, LOW);
    delay(20);
    digitalWrite(DHT_PIN, HIGH);
    delayMicroseconds(40);
    pinMode(DHT_PIN, INPUT_PULLUP);

    // Sensor ack: ~80us low, ~80us high, then it starts clocking out data.
    if (waitForLevel(LOW, 1000) < 0)  return false;
    if (waitForLevel(HIGH, 1000) < 0) return false;
    if (waitForLevel(LOW, 1000) < 0)  return false;

    // 40 data bits, each a 50us low pulse followed by a high pulse whose
    // LENGTH encodes the bit: ~26-28us = "0", ~70us = "1".
    for (int i = 0; i < 40; i++) {
        if (waitForLevel(HIGH, 1000) < 0) return false;
        long highUs = waitForLevel(LOW, 1000);
        if (highUs < 0) return false;
        data[i / 8] <<= 1;
        if (highUs > 40) data[i / 8] |= 1;
    }

    uint8_t checksum = data[0] + data[1] + data[2] + data[3];
    if (checksum != data[4]) return false;

    *hum = ((data[0] << 8) | data[1]) / 10.0f;

    uint16_t rawTemp = ((data[2] & 0x7F) << 8) | data[3];
    *temp = rawTemp / 10.0f;
    if (data[2] & 0x80) *temp = -*temp;  // top bit = sign

    return true;
}

// ---- MQ135 gas sensor ----

// MQ135 heater needs ~3 minutes to stabilize after power-on.
// Readings before warm-up are wildly inaccurate.
#define MQ135_WARMUP_MS  180000UL   // 3 minutes
#define MQ135_MAX_PPM    500.0f     // Clamp: real ammonia > 500 ppm is already lethal
static unsigned long mq135_powerOnTime = 0;

static float mq135_readPpm() {
    // Skip readings during warm-up period
    if (mq135_powerOnTime == 0) {
        mq135_powerOnTime = millis();
        Serial.println("[GAS] MQ135 warming up (3 min) - reporting 0 until then");
    }
    if (millis() - mq135_powerOnTime < MQ135_WARMUP_MS) {
        return 0.0f;  // Sensor still warming up - report safe
    }

    int raw = analogRead(MQ135_PIN);
    float voltage = analogReadMilliVolts(MQ135_PIN) / 1000.0f;

    // These two early-return cases were previously silent — a gas reading
    // stuck at 0 looked EXACTLY like "clean air, all is well" in the logs
    // whether that was true or the sensor was floating/disconnected the
    // whole time. Logged now so a "gas isn't being read" report has an
    // actual raw ADC value to diagnose from instead of a guess (HW team,
    // 2026-08-30).
    if (raw < 10) {
        Serial.printf("[GAS] raw=%d V=%.3f - pin reading near-ground, treating as floating/disconnected\n",
                      raw, voltage);
        return 0.0f;          // Pin floating / no sensor
    }
    if (raw > 4080) {
        Serial.printf("[GAS] raw=%d V=%.3f - ADC pinned at ceiling, reporting max\n", raw, voltage);
        return MQ135_MAX_PPM; // Saturated = very high gas
    }

    // analogReadMilliVolts() uses the chip's factory ADC calibration
    // (eFuse-stored, per-unit) instead of assuming a perfectly linear
    // 0-4095 -> 0-3.3V mapping. HW team confirmed the naive raw/4095*VREF
    // math (below) reads noticeably off on the real board; this matches
    // their verified-working readout.
    //
    // FLAGGED FOR HW VERIFICATION (2026-08-30, cross-checked against the
    // MQ135 datasheet): the datasheet specifies a 0-5V analog output on a
    // 5V supply (matching MQ135_VREF below) and a 20kOhm load resistor in
    // its reference test circuit — this board's MQ135_RL is 10kOhm, which
    // is fine IF that's genuinely the resistor populated on this specific
    // breakout, but worth a physical check if not already confirmed.
    // Bigger concern: the ESP32's ADC pin only tolerates ~3.3V, and
    // analogReadMilliVolts() can never report above that ceiling. If AOUT
    // is wired straight into this GPIO with no resistor divider stepping
    // 0-5V down into 3.3V-safe range, any true reading above ~3.3V is
    // being clipped at the pin — a very plausible cause of "gas isn't
    // being read" correctly, and worth confirming with a multimeter on
    // AOUT before trusting any ppm number this function produces. If a
    // divider IS present, MQ135_VREF needs to reflect the divided ceiling
    // voltage, not the sensor's raw 5V spec.
    float rs = MQ135_RL * (MQ135_VREF - voltage) / voltage;
    float ratio = rs / MQ135_RO_CLEAN;

    Serial.printf("[GAS] raw=%d  V=%.3f  Rs=%.2f  Rs/Ro=%.3f\n", raw, voltage, rs, ratio);

    // Approximate NH3 ppm from Rs/Ro curve
    if (ratio <= 0.0f) return 0.0f;
    float ppm = 116.602f * pow(ratio, -2.769f);

    // Clamp to sane range (anything > 500 ppm is lethal anyway)
    if (ppm < 0.0f) return 0.0f;
    if (ppm > MQ135_MAX_PPM) return MQ135_MAX_PPM;
    return ppm;
}

// ---- Public API ----

bool sensors_init() {
    // I2C bus (Wire) is started once in setup() — LCD only now, the
    // temp/humidity sensor moved to its own single-wire pin (DHT_PIN).
    pinMode(DHT_PIN, INPUT_PULLUP);
    analogReadResolution(12);
    analogSetAttenuation(ADC_11db);  // full 0-3.3V range, needed for analogReadMilliVolts() to calibrate correctly
    Serial.println("[SENSORS] Initialized (AM2302/DHT22 + MQ135)");
    return true;
}

// After several back-to-back failures, stop hammering the bus with another
// 20ms-low start pulse every SENSOR_INTERVAL and instead let it sit idle
// (INPUT_PULLUP, no pulses at all) for a few seconds. Seen on real hardware:
// 100% read failures from first boot until a manual restart, which points at
// the sensor's internal state machine getting wedged by a failed/interrupted
// transaction rather than marginal signal timing (that would be intermittent,
// not 100%) — a wedged DHT-family sensor needs a genuinely quiet idle-high
// period to resynchronize, which it never got since we kept restarting a new
// transaction on it every 2s.
#define DHT22_FAIL_THRESHOLD   3
#define DHT22_RECOVER_MS       3000UL
static uint8_t dht22FailStreak = 0;
static unsigned long dht22RecoverUntil = 0;

void sensors_read(SensorData *data) {
    unsigned long now = millis();
    if (now < dht22RecoverUntil) {
        pinMode(DHT_PIN, INPUT_PULLUP);
        Serial.println("[SENSORS] AM2302/DHT22 idling to recover, skipping read");
    } else if (dht22_read(&data->temperature, &data->humidity)) {
        dht22FailStreak = 0;
    } else {
        Serial.println("[SENSORS] AM2302/DHT22 read failed, using last values");
        if (++dht22FailStreak >= DHT22_FAIL_THRESHOLD) {
            dht22FailStreak = 0;
            dht22RecoverUntil = now + DHT22_RECOVER_MS;
            Serial.println("[SENSORS] AM2302/DHT22 repeated failures - forcing idle recovery");
        }
    }
    data->gas = mq135_readPpm();
}

// Each of the 4 actuators now has a direct, dedicated purpose:
//   Heater      - temperature too LOW
//   Cooler      - temperature too HIGH (dedicated cooling, e.g. evaporative pad)
//   Humidifier  - humidity too LOW
//   Fan         - ventilation/air exchange: runs for high temp (alongside
//                 Cooler), high humidity (to vent moist air out), and gas
//                 (highest priority — always wins over everything else)
void sensors_evaluate(const SensorData *data,
                      const Thresholds *t,
                      const ActuatorState *current,
                      ControlAction *action) {
    // Default desired = current state (so deadband = "keep current")
    bool desiredFan        = current->fan;
    bool desiredHeater     = current->heater;
    bool desiredCooler     = current->cooler;
    bool desiredHumidifier = current->humidifier;
    action->reason[0]      = '\0';

    // Hysteresis (prevents rapid oscillation): turn ON at the threshold,
    // turn OFF only once the reading has cleared it by t->hysteresis (the
    // same value the Settings screen has always displayed as "Hysteresis:
    // 1.5" — this used to be computed as 10% of each threshold instead,
    // completely ignoring that field, which for e.g. a 60-74% humidity
    // Range meant a real ~6-7 point dead zone instead of the promised 1.5.
    // Gas has no user-facing hysteresis control, so it keeps the old 10%
    // relative band.
    const float tempHighHyst = t->hysteresis;
    const float tempLowHyst  = t->hysteresis;
    const float humHighHyst  = t->hysteresis;
    const float humLowHyst   = t->hysteresis;
    const float gasHighHyst  = t->gasHigh  * 0.10f;

    // ---- Heater (temperature low side) ----
    if (data->temperature < t->tempLow) {
        desiredHeater = true;
        snprintf(action->reason, sizeof(action->reason),
                 "Temp %.1fC < %.1fC - heating", data->temperature, t->tempLow);
    } else if (data->temperature > t->tempLow + tempLowHyst) {
        desiredHeater = false;
    }

    // ---- Cooler + Fan (temperature high side) ----
    // Cooler does the actual cooling; Fan runs alongside it for airflow.
    if (data->temperature > t->tempHigh) {
        desiredCooler = true;
        desiredFan    = true;
        snprintf(action->reason, sizeof(action->reason),
                 "Temp %.1fC > %.1fC - cooling", data->temperature, t->tempHigh);
    } else if (data->temperature < t->tempHigh - tempHighHyst) {
        desiredCooler = false;
        desiredFan    = false;
    }

    // ---- Humidifier (humidity low side) ----
    if (data->humidity < t->humLow) {
        desiredHumidifier = true;
        snprintf(action->reason, sizeof(action->reason),
                 "Humidity %.1f%% < %.1f%% - humidifying",
                 data->humidity, t->humLow);
    } else if (data->humidity > t->humLow + humLowHyst) {
        desiredHumidifier = false;
    }

    // ---- Fan override: high humidity needs ventilation ----
    if (data->humidity > t->humHigh) {
        desiredFan = true;
        snprintf(action->reason, sizeof(action->reason),
                 "Humidity %.1f%% > %.1f%% - ventilating",
                 data->humidity, t->humHigh);
    } else if (data->humidity < t->humHigh - humHighHyst) {
        // Out of the "too humid" zone — release this specific override.
        // (Fan may still be on for a different reason, e.g. temperature.)
    }

    // ---- Fan + Heater override: gas (HIGHEST priority) ----
    if (data->gas > t->gasHigh) {
        desiredFan    = true;
        desiredHeater = false;
        snprintf(action->reason, sizeof(action->reason),
                 "Gas %.1fppm > %.1fppm - ventilating",
                 data->gas, t->gasHigh);
    } else if (data->gas < t->gasHigh - gasHighHyst) {
        // Gas dropped below safe band — release the override (other rules decide)
    }

    // ---- Decision: write action only if anything actually changed ----
    action->fan        = desiredFan;
    action->heater     = desiredHeater;
    action->cooler     = desiredCooler;
    action->humidifier = desiredHumidifier;
    action->needed = (desiredFan       != current->fan)
                  || (desiredHeater     != current->heater)
                  || (desiredCooler     != current->cooler)
                  || (desiredHumidifier != current->humidifier);

    if (action->needed && action->reason[0] == '\0') {
        snprintf(action->reason, sizeof(action->reason),
                 "Auto-adjust F=%d H=%d C=%d U=%d",
                 desiredFan, desiredHeater, desiredCooler, desiredHumidifier);
    }
}
