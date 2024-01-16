# fak-kiwi

Codename Kiwi is a work-in-progress keyboard firmware for the CH58x series under the [FAK](https://github.com/semickolon/fak) family.

Current status:
- BLE keyboard is working, with deep sleep and GPIO interrupts. It draws 2.4uA (as per datasheet) in deep sleep and only scans the matrix if at least one key is pressed.
- My cheap tool says "0 mA" and, at this point, I need a better power profiling instrument to further optimize power consumption. Nonetheless, it should have pretty decent battery life.
- Manufacturer's BLE stack takes up 138 KB of flash. Entire thing, 141 KB. So far, that's 3 KB for the firmware itself. Zig is awesome.
- Implemented behaviors: Key press, Hold-tap

## Getting started

Requirements:
- `zig` 0.11.0
- `wchisp` nightly

Edit `src/config.zig` for matrix and keymap definition.

## Flashing

1. `zig build`
2. `wchisp flash zig-out/bin/fak-kiwi`
