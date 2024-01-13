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

    for (matrix.cols) |col| {
        col.config(.output);
    }

    for (matrix.rows) |row| {
        row.config(.input_pull_down);
    }

    setScanning(false);
}

pub fn process() void {
    if (scanning)
        return;

    var start_scanning = false;

    for (matrix.rows) |row| {
        start_scanning = start_scanning or row.isInterruptTriggered();
        row.clearInterruptTriggered();
    }

    if (start_scanning) {
        setScanning(true);
    }
}

fn setScanning(value: bool) void {
    scanning = value;
    // config.sys.led_1.write(!scanning);

    for (matrix.cols) |col| {
        col.write(!scanning);
    }

    for (matrix.rows) |row| {
        row.setInterrupt(if (scanning) null else .edge);
    }

    if (scanning) {
        scan();
    }
}

pub fn scheduleNextScan() void {
    task.scheduleEvent(.scan, scan_interval);
}

pub fn scan() void {
    var all_keys_released = true;

    for (matrix.cols, 0..) |col, i| {
        col.write(true);
        colSwitchDelay();

        for (matrix.rows, 0..) |row, j| {
            const key_idx = (j * matrix.cols.len) + i;
            const ks = &key_states[key_idx];

            const new_counter = if (row.read())
                ks.debounce_counter +| 1
            else
                ks.debounce_counter -| 1;

            if (new_counter == ks.debounce_counter)
                continue;

            ks.debounce_counter = new_counter;

            if (ks.debounce_counter != 0) {
                all_keys_released = false;
            }

            if (switch (ks.debounce_counter) {
                0 => false,
                std.math.maxInt(@TypeOf(ks.debounce_counter)) => true,
                else => null,
            }) |is_down| {
                engine.pushKeyEvent(@truncate(key_idx), is_down);
            }
        }

        col.write(false);
    }

    if (all_keys_released) {
        setScanning(false);
    } else {
        scheduleNextScan();
    }
}

inline fn colSwitchDelay() void {
    for (0..2) |_| {
        common.nop();
    }
}
