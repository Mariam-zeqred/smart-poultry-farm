/*
 * sensors.h - Environmental sensor interface
 */

#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>

struct SensorData {
    float temperature;  // °C
    float humidity;     // %
    float gas;          // ppm
};

struct Thresholds {
    float tempHigh, tempLow;
    float humHigh, humLow;
    float gasHigh;
    float hysteresis;
};

// All 4 actuators (Fan, Heater, Cooler, Humidifier) are auto-controlled —
// each has a direct sensor-driven purpose (see sensors_evaluate()).
struct ControlAction {
    bool fan;
    bool heater;
    bool cooler;
    bool humidifier;
    bool needed;        // true if desired state differs from current
    char reason[80];
};

// Snapshot of currently-applied actuator state, supplied to the evaluator
// so it can implement true hysteresis (turn ON at threshold, OFF at threshold ∓ hyst).
struct ActuatorState {
    bool fan;
    bool heater;
    bool cooler;
    bool humidifier;
};

// Initialize I2C + ADC
bool sensors_init();

// Read all sensors into data struct
void sensors_read(SensorData *data);

// Evaluate what controls should do based on thresholds and the CURRENT actuator
// state. Sets action->needed = true iff the desired state differs from current.
void sensors_evaluate(const SensorData *data,
                      const Thresholds *thresh,
                      const ActuatorState *current,
                      ControlAction *action);

#endif
