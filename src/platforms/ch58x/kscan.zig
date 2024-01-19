const std = @import("std");

const config = @import("config.zig");
const interface = @import("interface.zig");
const tmos = @import("ble/tmos.zig");
const common = @import("hal/common.zig");
const Duration = @import("duration.zig").Duration;

const key_count = 9; // TODO: Hardcoded
const matrix = config.kscan.matrix;

const blueprint = tmos.TaskBlueprint{
    .Event = enum(u4) { scan },
    .events_callback = &.{scan},
};
var task: tmos.Task(blueprint.Event) = undefined;

const scan_interval = Duration.fromMicros(tmos.SYSTEM_TIME_US * config.kscan.scan_interval);

var scanning = false;
var debounce_counters = std.PackedIntArray(u2, key_count).initAllTo(0);

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
            const last_counter = debounce_counters.get(key_idx);

            const counter = if (row.read())
                last_counter +| 1
            else
                last_counter -| 1;

            if (last_counter == counter)
                continue;

            debounce_counters.set(key_idx, counter);

            if (counter != 0) {
                all_keys_released = false;
            }

            if (switch (counter) {
                0 => false,
                std.math.maxInt(@TypeOf(debounce_counters).Child) => true,
                else => null,
            }) |is_down| {
                interface.pushKeyEvent(@truncate(key_idx), is_down);
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
