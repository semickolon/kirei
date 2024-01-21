const std = @import("std");
const kirei = @import("kirei");

const ble_dev = @import("ble/ble_dev.zig");
const rtc = @import("hal/rtc.zig");
const scheduler = @import("ble/scheduler.zig");
const debug = @import("debug.zig");
const eeprom = @import("hal/eeprom.zig");

var keymapBytes: [256]u8 = undefined;

var engine = kirei.Engine.init(.{
    .onReportPush = ble_dev.onReportPush,
    .getTimeMillis = getTimeMillis,
    .scheduleCall = scheduler.scheduleCall,
    .cancelCall = scheduler.cancelCall,
    .readKeymapBytes = readKeymapBytes,
    .print = debug.print,
});

pub fn init() void {
    eeprom.read(0, &keymapBytes) catch {
        debug.print("luh siya!!\r\n");
    };
    engine.setup() catch {
        debug.print("engine setup failed\r\n");
    };
}

pub fn process() void {
    engine.process();
}

pub fn callScheduled(token: kirei.ScheduleToken) void {
    engine.callScheduled(token);
}

pub fn pushKeyEvent(key_idx: kirei.KeyIndex, down: bool) void {
    engine.pushKeyEvent(key_idx, down);
}

fn getTimeMillis() kirei.TimeMillis {
    return @intCast((rtc.getTime() / 32) % std.math.maxInt(u16));
}

fn readKeymapBytes(offset: usize, len: usize) []const u8 {
    return keymapBytes[offset .. offset + len];
}
