const std = @import("std");
const kirei = @import("kirei");

const assert = std.debug.assert;
const KeyIndex = kirei.KeyIndex;

fn ScanIter(comptime Gpio: type) type {
    return struct {
        key_idx: KeyIndex = 0,
        kscan: *const Kscan(Gpio),

        const Self = @This();

        fn reportKeyState(self: *Self, down: ?bool) void {
            if (down) |d| {
                if (self.kscan.getMappedKeyIndex(self.key_idx)) |key_idx| {
                    self.kscan.engine.pushKeyEvent(key_idx, d);
                }
            }
            self.key_idx += 1;
        }

        fn skipKeys(self: *Self, count: KeyIndex) void {
            self.key_idx += count;
        }
    };
}

pub fn Kscan(comptime Gpio: type) type {
    return struct {
        drivers: []Driver(Gpio),
        key_mapping: ?[]const ?KeyIndex = null,
        engine: *kirei.Engine,

        const Self = @This();

        pub fn setup(self: Self) void {
            for (self.drivers) |*driver| {
                driver.setup();
            }
        }

        pub fn process(self: Self) void {
            var scan_iter = ScanIter(Gpio){ .kscan = &self };
            for (self.drivers) |*driver| {
                driver.process(&scan_iter);
            }
        }

        fn getMappedKeyIndex(self: Self, key_idx: KeyIndex) ?KeyIndex {
            return if (self.key_mapping) |km|
                if (key_idx < km.len) km[key_idx] else null
            else
                key_idx;
        }
    };
}

pub fn Driver(comptime Gpio: type) type {
    return union(enum) {
        matrix: Matrix(Gpio),

        const Self = @This();

        fn setup(self: *Self) void {
            switch (self.*) {
                inline else => |*s| s.setup(),
            }
        }

        fn process(self: *Self, scan_iter: *ScanIter(Gpio)) void {
            return switch (self.*) {
                inline else => |*s| s.process(scan_iter),
            };
        }
    };
}

pub fn Matrix(comptime Gpio: type) type {
    const Index = u7;

    return struct {
        config: *const Config,
        debouncer: CycleDebouncer(Index) = .{},
        scanning: bool = false,

        const Self = @This();

        pub const Config = struct {
            cols: []const Gpio.Pin,
            rows: []const Gpio.Pin,
            direction: enum { col_to_row, row_to_col } = .col_to_row,
        };

        fn setup(self: *Self) void {
            if (self.keyCount() > std.math.maxInt(Index) + 1) {
                @panic("Matrix is too big.");
            }

            for (self.outputs()) |out| {
                out.config(.output);
            }

            for (self.inputs()) |in| {
                in.config(.input);
            }

            self.setScanning(false);
        }

        fn setScanning(self: *Self, scanning: bool) void {
            self.scanning = scanning;

            for (self.outputs()) |out| {
                out.write(!scanning);
            }

            for (self.inputs()) |in| {
                in.setInterrupt(if (scanning) null else .rise);
            }
        }

        fn process(self: *Self, scan_iter: *ScanIter(Gpio)) void {
            if (!self.scanning) {
                var will_scan = false;

                for (self.inputs()) |in| {
                    will_scan = will_scan or in.takeInterruptTriggered();
                }

                if (will_scan) {
                    self.setScanning(true);
                }
            }

            if (self.scanning) {
                self.scan(scan_iter);
            } else {
                scan_iter.skipKeys(self.keyCount());
            }
        }

        fn scan(self: *Self, scan_iter: *ScanIter(Gpio)) void {
            const ins = self.inputs();
            const outs = self.outputs();

            var i: Index = 0;
            var all_keys_released = true;

            for (outs) |out| {
                out.write(true);

                for (0..128) |_| {
                    asm volatile ("nop");
                }

                for (ins) |in| {
                    const down = self.debouncer.debounce(i, in.read());
                    scan_iter.reportKeyState(down);
                    i += 1;

                    if (down != false) {
                        all_keys_released = false;
                    }
                }

                out.write(false);
            }

            if (all_keys_released) {
                self.setScanning(false);
            }
        }

        fn inputs(self: Self) []const Gpio.Pin {
            return switch (self.config.direction) {
                .col_to_row => self.config.rows,
                .row_to_col => self.config.cols,
            };
        }

        fn outputs(self: Self) []const Gpio.Pin {
            return switch (self.config.direction) {
                .col_to_row => self.config.cols,
                .row_to_col => self.config.rows,
            };
        }

        fn keyCount(self: Self) u8 {
            return @intCast(self.config.cols.len * self.config.rows.len);
        }
    };
}

pub fn CycleDebouncer(comptime Index: type) type {
    const key_count = std.math.maxInt(Index) + 1;

    const BackingCounter = u2;
    const Counters = std.PackedIntArray(BackingCounter, key_count);

    return struct {
        counters: Counters = Counters.initAllTo(0),

        const Self = @This();

        fn debounce(self: *Self, idx: Index, is_reading_down: bool) ?bool {
            const last_counter = self.counters.get(idx);

            const counter = if (is_reading_down)
                last_counter +| 1
            else
                last_counter -| 1;

            self.counters.set(idx, counter);

            return switch (counter) {
                0 => false,
                std.math.maxInt(BackingCounter) => true,
                else => null,
            };
        }
    };
}
