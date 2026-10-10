/*
 * command_handler.cpp - GPIO ON/OFF control for actuators
 */

#include "command_handler.h"
#include "config.h"

// RELAY_ACTIVE_LOW (config.h): most relay modules energize on a LOW input.
// relayLevel(true) returns the GPIO level that turns the relay ON given
// that polarity, so every cmd_set* below stays correct if it's ever flipped.
#if RELAY_ACTIVE_LOW
static inline int relayLevel(bool on) { return on ? LOW : HIGH; }
#else
static inline int relayLevel(bool on) { return on ? HIGH : LOW; }
#endif

void cmd_init() {
    pinMode(FAN_PIN,        OUTPUT);
    pinMode(COOLER_PIN,     OUTPUT);
    pinMode(HEATER_PIN,     OUTPUT);
    pinMode(HUMIDIFIER_PIN, OUTPUT);
    pinMode(LED_PIN,        OUTPUT);

    // Start with everything OFF (relayLevel(false), NOT a bare LOW —
    // active-low relays are OFF at HIGH).
    digitalWrite(FAN_PIN,        relayLevel(false));
    digitalWrite(COOLER_PIN,     relayLevel(false));
    digitalWrite(HEATER_PIN,     relayLevel(false));
    digitalWrite(HUMIDIFIER_PIN, relayLevel(false));
    digitalWrite(LED_PIN,        LOW);  // status LED is a plain LED, not a relay — unaffected by polarity

    Serial.println("[CMD] GPIO outputs initialized (all OFF)");
}

void cmd_setFan(bool on)        { digitalWrite(FAN_PIN,        relayLevel(on)); }
void cmd_setCooler(bool on)     { digitalWrite(COOLER_PIN,     relayLevel(on)); }
void cmd_setHeater(bool on)     { digitalWrite(HEATER_PIN,     relayLevel(on)); }
void cmd_setHumidifier(bool on) { digitalWrite(HUMIDIFIER_PIN, relayLevel(on)); }
