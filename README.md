# fak-kiwi

Codename Kiwi is a work-in-progress keyboard firmware for the CH58x series under the [FAK](https://github.com/semickolon/fak) family.

Current status: Bare minimum BLE keyboard is now working with deep sleep, drawing 2.4uA (as per datasheet) every BLE connection interval (tries for 10ms).

My cheap tool says "0 mA" and, at this point, I need a better power profiling instrument.

## Getting started

Requirements:
- `zig` 0.11.0
- `wchisp`

## Flashing

1. `zig build`
2. `wchisp flash zig-out/bin/fak-ch58`
