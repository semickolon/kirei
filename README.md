# Kirei 🌸 綺麗

The prettiest keyboard software.

Kirei is a work-in-progress keyboard library written in Zig.

<a href="https://www.buymeacoffee.com/semickolon"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=☕&slug=semickolon&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" /></a>

## What is Kirei?

In the strictest sense, Kirei is a keyboard library that you feed inputs to (which keys are pressed) and get outputs from (HID reports). This design and Zig's fantastic compiler capabilities let the Kirei core engine run on almost anything. This allows for different hardware and protocol implementations with applications ranging from embedded (like QMK, ZMK) to emulated OS input (like KMonad, Kanata) to, well, both (hardware interacting with software, like Logitech software). Hence, Kirei is not just keyboard firmware. It's keyboard software.

Kirei uses a keymap file that is portable across all implementations. With embedded in mind, it is (de)serialized in a custom binary format called *Hana*, optimized for both size and speed. Following in the footsteps of [FAK](https://github.com/semickolon/fak), keymaps are declaratively configured using Nickel.

## Current status

- Implemented behaviors: Key press, Hold-tap, Tap dance.
- Nickel is now well-integrated into the build system.

## Requirements

- `zig` 0.11.0
- `nickel` 1.3.0+
- `wchisp` nightly - for flashing CH58x

## Implementations

### CH58x

- BLE keyboard is working, with deep sleep and GPIO interrupts. It draws 2.4uA (as per datasheet) in deep sleep and only scans the matrix if at least one key is pressed.
- My cheap tool says "0 mA" and, at this point, I need a better power profiling instrument to further optimize power consumption. Nonetheless, it should have pretty decent battery life.
- Keymap is read from EEPROM so it can be dynamically updated like VIA.

### RP2040

- USB HID is working.
- The next step is to implement the scheduler and make a unified keyboard configuration for embedded implementations. That is, CH58x and RP2040 (and others in the future) would share a common hardware config.

### Testing

- For testing key presses against keymaps.
- This runs on an OS, and the fact that it can is pretty slick. This means we can use this as a base for emulating a keyboard device, like what KMonad does.
