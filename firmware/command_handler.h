/*
 * command_handler.h - GPIO actuator control (ON/OFF)
 */

#ifndef COMMAND_HANDLER_H
#define COMMAND_HANDLER_H

#include <Arduino.h>

// Initialize all actuator GPIO pins as outputs
void cmd_init();

// Set individual actuators
void cmd_setFan(bool on);
void cmd_setCooler(bool on);
void cmd_setHeater(bool on);
void cmd_setHumidifier(bool on);

#endif
