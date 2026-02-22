
// IDE: ATtiny25/45/85, internal 1MHz
// 1MHz is the default speed, no need to switch fuses to 8MHz
// compile to HEX (Sketch->Export compiled binary) and burn using TL866-II
//
// ROM bank switcher: detects long presses on system /RESET line,
// cycles through 4 banks (00 -> 01 -> 10 -> 11 -> 00 ...) on two output pins.
// Normal/short resets are ignored. State resets to 00 on every power-on.

// pinout
//   /RESET 1  U  8 VCC
//   A3/PB3 2     7 PB2 <-- input: system /RESET (active low)
//   A2/PB4 3     6 PB1 --> output: bank address A1 (MSB)
//      GND 4     5 PB0 --> output: bank address A0 (LSB)

#define LONG_PRESS_MS  1000
#define DEBOUNCE_MS      50

const uint8_t pin_A0    = 0; // PB0, pin 5 -- bank address bit 0
const uint8_t pin_A1    = 1; // PB1, pin 6 -- bank address bit 1
const uint8_t pin_reset = 2; // PB2, pin 7 -- system /RESET sense

uint8_t bank = 0;

static void applyBank() {
  digitalWrite(pin_A0, bank & 1);
  digitalWrite(pin_A1, (bank >> 1) & 1);
}

void setup() {
  pinMode(pin_A0, OUTPUT);
  pinMode(pin_A1, OUTPUT);
  applyBank();

  pinMode(pin_reset, INPUT_PULLUP);

  // Wait for the system to release /RESET after power-on.
  // This avoids treating the power-on reset as a long press.
  while (digitalRead(pin_reset) == LOW)
    ;
  delay(DEBOUNCE_MS);
}

void loop() {
  // Wait for /RESET to be asserted (pulled LOW)
  if (digitalRead(pin_reset) != LOW)
    return;

  delay(DEBOUNCE_MS);
  if (digitalRead(pin_reset) != LOW)
    return;

  // /RESET is confirmed LOW -- start timing
  unsigned long pressed_at = millis();

  while (digitalRead(pin_reset) == LOW) {
    if (millis() - pressed_at >= LONG_PRESS_MS) {
      // Long press detected -- advance bank while system is held in reset
      bank = (bank + 1) & 3;
      applyBank();

      // Wait for button release
      while (digitalRead(pin_reset) == LOW)
        ;
      delay(DEBOUNCE_MS);
      return;
    }
  }
  // /RESET released before threshold -- short press, ignore
  delay(DEBOUNCE_MS);
}
