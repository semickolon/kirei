const std = @import("std");

const engine = @import("core/engine.zig");
const config = @import("config.zig");
const tmos = @import("ble/tmos.zig");
const common = @import("hal/common.zig");
const Duration = @import("duration.zig").Duration;

const key_count = config.engine.key_map.len;
const matrix = config.kscan.matrix;

const PhysicalKeyState = packed struct {
    debounce_counter: u2 = 0,
};

const blueprint = tmos.TaskBlueprint{
    .Event = enum(u4) { scan },
    .events_callback = &.{scan},
};
var task: tmos.Task(blueprint.Event) = undefined;

const scan_interval = Duration.fromMicros(625 * 2);

var scanning = false;
var key_states: [key_count]PhysicalKeyState = .{.{}} ** key_count;

pub fn init() void {
    task = tmos.register(blueprint);

    inline for (matrix.cols) |col| {
        col.config(.output);
    }

    inline for (matrix.rows) |row| {
        row.config(.input_pull_down);
    }

    setScanning(false);
}

pub fn process() void {
    if (scanning) return;

    var will_scan = false;

    inline for (matrix.rows) |row| {
        if (row.isInterruptTriggered()) {
            will_scan = true;
        }
    }

    if (will_scan)
        setScanning(true);
}

fn setScanning(value: bool) void {
    scanning = value;
    // config.sys.led_1.write(!scanning);

    inline for (matrix.cols) |col| {
        col.write(!scanning);
    }

    inline for (matrix.rows) |row| {
        row.setInterrupt(if (scanning) null else .edge);
    }

    if (scanning) {
        scan();
    }
}

pub fn scheduleNextScan() void {
    task.startEvent(.scan, scan_interval);
}

pub fn scan() void {
    var will_scan_again = false;

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

            if (ks.debounce_counter != 0) {
                will_scan_again = true;
            }
        }

        col.write(false);
    }

    if (will_scan_again) {
        scheduleNextScan();
    } else {
        setScanning(false);
    }
}

inline fn colSwitchDelay() void {
    for (0..2) |_| {
        common.nop();
    }
}
