const std = @import("std");
const kirei = @import("kirei");

const HidReport = [8]u8;

var engine = kirei.Engine(.{
    .onReportPush = onReportPush,
    .getTimeMillis = getTimeMillis,
    .scheduleCall = scheduleCall,
    .toggleLed = toggleLed,
}){};

fn onReportPush(report: *const HidReport) bool {
    std.debug.print("{any}\n", .{report.*});
    return true;
}

fn getTimeMillis() kirei.TimeMillis {
    return 0;
}

var k: u8 = 0;

fn scheduleCall(duration: kirei.TimeMillis) kirei.ScheduleToken {
    k +%= 1;
    std.debug.print("{any}ms scheduled as token {any}\n", .{ duration, k });
    return k;
}

fn toggleLed() void {
    return;
}

pub fn main() !void {
    engine.process();
    engine.pushKeyEvent(0, true);
    engine.pushKeyEvent(0, false);
    engine.pushKeyEvent(0, true);
    engine.callScheduled(1);
    engine.pushKeyEvent(0, false);
    engine.callScheduled(2);
    engine.process();
}
