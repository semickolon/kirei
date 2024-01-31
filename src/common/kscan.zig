const std = @import("std");
const kirei = @import("kirei");

const assert = std.debug.assert;
const KeyIndex = kirei.KeyIndex;

pub fn ScanIter(comptime Gpio: type) type {
    return struct {
        key_idx: KeyIndex = 0,
        kscan: *const Kscan(Gpio),

        const Self = @This();

        fn reportKeyState(self: *Self, down: ?bool) void {
            if (down) |d| {
                if (self.kscan.getMappedKeyIndex(self.key_idx)) |key_idx| {
                    std.log.debug("{}: {}", .{ key_idx, d });
                    self.kscan.engine.pushKeyEvent(key_idx, d);
                }
            }
            self.key_idx += 1;
        }
    };
}

pub fn Kscan(comptime Gpio: type) type {
    return struct {
        drivers: []const KscanDriver(Gpio),
        key_mapping: ?[]const ?KeyIndex = null,
        engine: *kirei.Engine,

        const Self = @This();

        pub fn setup(self: Self) void {
            for (self.drivers) |driver| {
                driver.setup();
            }
        }

        pub fn scan(self: Self) void {
            var scan_iter = ScanIter(Gpio){ .kscan = &self };
            for (self.drivers) |driver| {
                driver.scan(&scan_iter);
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

pub fn KscanDriver(comptime Gpio: type) type {
    return union(enum) {
        matrix: Matrix(Gpio),

        const Self = @This();

        pub fn setup(self: Self) void {
            switch (self) {
                inline else => |s| s.setup(),
            }
        }

        pub fn scan(self: Self, scan_iter: *ScanIter(Gpio)) void {
            return switch (self) {
                inline else => |s| s.scan(scan_iter),
            };
        }
    };
}

fn Matrix(comptime Gpio: type) type {
    const Index = u7;

    return struct {
        cols: []const Gpio.Pin,
        rows: []const Gpio.Pin,
        direction: enum { col_to_row, row_to_col } = .col_to_row,
        debouncer: *CycleDebouncer(Index),

        const Self = @This();

        pub fn setup(self: Self) void {
            if (self.cols.len * self.rows.len > std.math.maxInt(Index) + 1) {
                @panic("Matrix is too big.");
            }

            for (self.outputs()) |out| {
                out.config(.output);
                out.write(false);
            }
        }

        pub fn scan(self: Self, scan_iter: *ScanIter(Gpio)) void {
            const ins = self.inputs();
            const outs = self.outputs();
            var i: Index = 0;

            for (outs) |out| {
                out.write(true);
                defer out.write(false);

                for (ins) |in| {
                    const down = self.debouncer.debounce(i, in.read());
                    scan_iter.reportKeyState(down);
                    i += 1;
                }
            }
        }

        fn inputs(self: Self) []const Gpio.Pin {
            return switch (self.direction) {
                .col_to_row => self.rows,
                .row_to_col => self.cols,
            };
        }

        fn outputs(self: Self) []const Gpio.Pin {
            return switch (self.direction) {
                .col_to_row => self.cols,
                .row_to_col => self.rows,
            };
        }
    };
}

pub fn CycleDebouncer(comptime Index: type) type {
    const key_count = std.math.maxInt(Index) + 1;

    return struct {
        keys_pressed: std.StaticBitSet(key_count) = std.StaticBitSet(key_count).initEmpty(),
        counters: std.PackedIntArray(u2, key_count) = std.PackedIntArray(u2, key_count).initAllTo(0),

        const Self = @This();

        fn debounce(self: *Self, idx: Index, is_reading_down: bool) ?bool {
            const last_counter = self.counters.get(idx);

            const counter = if (is_reading_down)
                last_counter +| 1
            else
                last_counter -| 1;

            if (last_counter == counter)
                return null;

            self.counters.set(idx, counter);

            if (switch (counter) {
                0 => false,
                std.math.maxInt(u2) => true,
                else => null,
            }) |is_down| {
                if (self.keys_pressed.isSet(idx) != is_down) {
                    self.keys_pressed.toggle(idx);
                    return is_down;
                }
            }

            return null;
        }
    };
}
