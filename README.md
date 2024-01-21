# Kirei 🌸

The prettiest keyboard software.

Kirei is a work-in-progress keyboard library written in Zig.

## Implementations

### CH58x

Current status:
- BLE keyboard is working, with deep sleep and GPIO interrupts. It draws 2.4uA (as per datasheet) in deep sleep and only scans the matrix if at least one key is pressed.
- My cheap tool says "0 mA" and, at this point, I need a better power profiling instrument to further optimize power consumption. Nonetheless, it should have pretty decent battery life.
- Keymap is read from EEPROM so it can be dynamically updated like VIA.
- Implemented behaviors: Key press, Hold-tap, Tap dance
