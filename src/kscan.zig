const std = @import("std");

const engine = @import("core/engine.zig");
const config = @import("config.zig");

const key_count = config.engine.key_map.len;
const matrix = config.kscan.matrix;

const PhysicalKeyState = packed struct {
    debounce_counter: u2 = 0,
};

var key_states: [key_count]PhysicalKeyState = .{.{}} ** key_count;

pub fn init() void {
    inline for (matrix.cols) |col| {
        col.config(.output);
    }

    inline for (matrix.rows) |row| {
        row.config(.input_pull_down);
    }
}

pub fn scan() void {
    inline for (matrix.cols, 0..) |col, i| {
        col.write(true);
        colSwitchDelay();

        inline for (matrix.rows, 0..) |row, j| {
            const key_idx = (j * matrix.cols.len) + i;
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
    for (0..2) |_| {
        asm volatile ("nop");
    }
}
