/*
 * lcd_display.cpp - HD44780 LCD via PCF8574 I2C backpack
 *
 * 4-bit mode over I2C. PCF8574 pin mapping:
 *   P0 = RS, P1 = RW, P2 = EN, P3 = Backlight
 *   P4-P7 = D4-D7
 */

#include "lcd_display.h"

// HD44780 commands
#define LCD_CLEARDISPLAY   0x01
#define LCD_RETURNHOME     0x02
#define LCD_ENTRYMODESET   0x04
#define LCD_DISPLAYCONTROL 0x08
#define LCD_FUNCTIONSET    0x20
#define LCD_SETCGRAMADDR   0x40
#define LCD_SETDDRAMADDR   0x80

// Flags
#define LCD_DISPLAYON      0x04
#define LCD_4BITMODE       0x00
#define LCD_2LINE          0x08
#define LCD_5x8DOTS        0x00
#define LCD_ENTRYLEFT      0x02

// PCF8574 bits
#define RS_BIT  0x01
#define EN_BIT  0x04
#define BL_BIT  0x08

bool LcdDisplay::begin(TwoWire *wire, uint8_t addr, uint8_t cols, uint8_t rows) {
    _wire = wire;
    _addr = addr;
    _cols = cols;
    _rows = rows;
    _backlight = BL_BIT;

    delay(50);

    // Init sequence: set to 4-bit mode
    expanderWrite(0);
    delay(5);

    // Three magic writes to guarantee 4-bit mode
    sendNibble(0x03, 0); delay(5);
    sendNibble(0x03, 0); delay(5);
    sendNibble(0x03, 0); delay(2);
    sendNibble(0x02, 0); delay(2);

    // Configure: 4-bit, 2 lines, 5x8 font
    command(LCD_FUNCTIONSET | LCD_4BITMODE | LCD_2LINE | LCD_5x8DOTS);
    command(LCD_DISPLAYCONTROL | LCD_DISPLAYON);
    clear();
    command(LCD_ENTRYMODESET | LCD_ENTRYLEFT);
    delay(2);

    Serial.printf("[LCD] Init OK at 0x%02X (%dx%d)\n", addr, cols, rows);
    return true;
}

void LcdDisplay::clear() {
    // Clear Display is a special-case HD44780 command that needs far longer
    // to actually execute than ordinary commands (~37-43us) - datasheet
    // says up to ~1.52ms on a genuine chip, but clone controllers on cheap
    // I2C backpacks commonly need more. This project already hit the same
    // class of bug on the DHT22 (datasheet's 1ms start-pulse wasn't enough
    // on the real board, needed 20ms) - clear() is called on nearly every
    // button press right before redrawing, so if this delay is too short,
    // the very next position/text commands land while the LCD is still
    // busy and get silently dropped, making a press look like it needs to
    // be repeated before the screen catches up. Bumped from 2ms to 10ms for
    // real-hardware margin; not yet verified against actual button-press
    // behavior on the board.
    command(LCD_CLEARDISPLAY);
    delay(10);
}

void LcdDisplay::setCursor(uint8_t col, uint8_t row) {
    const uint8_t offsets[] = {0x00, 0x40, 0x14, 0x54};
    if (row >= _rows) row = _rows - 1;
    command(LCD_SETDDRAMADDR | (col + offsets[row]));
}

void LcdDisplay::print(const char *text) {
    while (*text) write(*text++);
}

void LcdDisplay::print(char c) {
    write(c);
}

void LcdDisplay::printRow(uint8_t row, const char *text) {
    setCursor(0, row);
    for (uint8_t i = 0; i < _cols; i++) {
        if (text[i] == '\0') {
            // Pad rest with spaces
            for (; i < _cols; i++) write(' ');
            break;
        }
        write(text[i]);
    }
}

void LcdDisplay::backlight(bool on) {
    _backlight = on ? BL_BIT : 0;
    expanderWrite(0);
}

void LcdDisplay::createChar(uint8_t index, const uint8_t charmap[8]) {
    command(LCD_SETCGRAMADDR | ((index & 0x07) << 3));
    for (int i = 0; i < 8; i++) write(charmap[i]);
}

void LcdDisplay::writeChar(uint8_t index) {
    write(index);
}

// ---- Private ----

void LcdDisplay::command(uint8_t cmd) {
    sendByte(cmd, 0);
}

void LcdDisplay::write(uint8_t data) {
    sendByte(data, RS_BIT);
}

void LcdDisplay::sendByte(uint8_t value, uint8_t mode) {
    sendNibble((value >> 4) & 0x0F, mode);
    sendNibble(value & 0x0F, mode);
}

void LcdDisplay::sendNibble(uint8_t nibble, uint8_t mode) {
    uint8_t data = (nibble << 4) | mode | _backlight;
    pulseEnable(data);
}

void LcdDisplay::pulseEnable(uint8_t data) {
    expanderWrite(data | EN_BIT);
    delayMicroseconds(1);
    expanderWrite(data & ~EN_BIT);
    delayMicroseconds(50);
}

void LcdDisplay::expanderWrite(uint8_t data) {
    _wire->beginTransmission(_addr);
    _wire->write(data);
    _wire->endTransmission();
}
