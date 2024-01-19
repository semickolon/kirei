const std = @import("std");
const kirei = @import("kirei");

const ble_dev = @import("ble/ble_dev.zig");
const rtc = @import("hal/rtc.zig");
const scheduler = @import("ble/scheduler.zig");

var engine = kirei.Engine(.{
    .onReportPush = ble_dev.onReportPush,
    .getTimeMillis = getTimeMillis,
    .scheduleCall = scheduler.scheduleCall,
}){};

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
    return @intCast((rtc.getTime() / 32000) % std.math.maxInt(u16));
}
