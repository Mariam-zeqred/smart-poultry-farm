/*
 * lcd_display.h - HD44780 LCD via PCF8574 I2C backpack driver
 */

#ifndef LCD_DISPLAY_H
#define LCD_DISPLAY_H

#include <Arduino.h>
#include <Wire.h>

class LcdDisplay {
public:
    bool begin(TwoWire *wire, uint8_t addr, uint8_t cols, uint8_t rows);
    void clear();
    void setCursor(uint8_t col, uint8_t row);
    void print(const char *text);
    void print(char c);
    void backlight(bool on);

    // Convenience: write to a full row (padded/truncated to fit)
    void printRow(uint8_t row, const char *text);

    // Custom characters (up to 8, index 0-7)
    void createChar(uint8_t index, const uint8_t charmap[8]);
    void writeChar(uint8_t index);

private:
    TwoWire *_wire;
    uint8_t _addr;
    uint8_t _cols, _rows;
    uint8_t _backlight;

    void sendNibble(uint8_t nibble, uint8_t mode);
    void sendByte(uint8_t value, uint8_t mode);
    void expanderWrite(uint8_t data);
    void pulseEnable(uint8_t data);
    void command(uint8_t cmd);
    void write(uint8_t data);
};

#endif
