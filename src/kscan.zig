const std = @import("std");

const gpio = @import("hal/gpio.zig");
const engine = @import("core/engine.zig");

const P = gpio.pins;
const matrix_cols = [_]type{ P.B15, P.B14 };
const matrix_rows = [_]type{ P.B7, P.B4 };

const PhysicalKeyState = packed struct {
    debounce_counter: u2 = 0,
};

var key_states: [4]PhysicalKeyState = .{.{}} ** 4;

pub fn init() void {
    inline for (matrix_cols) |col| {
        col.config(.output);
    }

    inline for (matrix_rows) |row| {
        row.config(.input_pull_down);
    }
}

pub fn scan() void {
    inline for (matrix_cols, 0..) |col, i| {
        col.write(true);
        colSwitchDelay();

        inline for (matrix_rows, 0..) |row, j| {
            const key_idx = (j * matrix_cols.len) + i;
            const ks = &key_states[key_idx];

            if (row.read()) {
                ks.debounce_counter +|= 1;
            } else {
                ks.debounce_counter -|= 1;
            }

            if (switch (ks.debounce_counter) {
                0 => false,
                std.math.maxInt(@TypeOf(ks.debounce_counter)) => true,
                else => null,
            }) |is_down| {
                engine.reportKeyDown(key_idx, is_down);
            }
        }

        col.write(false);
    }
}

fn colSwitchDelay() void {
    inline for (0..4) |_| {
        asm volatile ("nop");
    }
}
