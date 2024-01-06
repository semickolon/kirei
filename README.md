# fak-kiwi

Codename Kiwi is a work-in-progress keyboard firmware for the CH58x series under the [FAK](https://github.com/semickolon/fak) family.

Current status: Bare minimum BLE keyboard is now working. No power management. Drawing a constant 5-6mA.

## Getting started

Requirements:
- `zig` 0.11.0
- `wchisp`

## Flashing

1. `zig build`
2. `wchisp flash zig-out/bin/fak-ch58`
