const std = @import("std");
const kirei = @import("kirei");

const HidReport = [8]u8;

var engine = kirei.Engine.init(.{
    .onReportPush = onReportPush,
    .getTimeMillis = getTimeMillis,
    .scheduleCall = scheduleCall,
    .toggleLed = toggleLed,
});

fn onReportPush(report: *const HidReport) bool {
    std.debug.print("{any}\n", .{report.*});
    return true;
}

fn getTimeMillis() kirei.TimeMillis {
    const m: kirei.TimeMillis = @truncate(@as(u64, @intCast(std.time.milliTimestamp())) % std.math.maxInt(kirei.TimeMillis));
    // std.debug.print("getTimeMillis: {any}\n", .{m});
    return m;
}

var k: u8 = 0;

fn scheduleCall(duration: kirei.TimeMillis) kirei.ScheduleToken {
    k +%= 1;
    std.debug.print("{any}ms scheduled as token {any}\n", .{ duration, k });
    return k;
}

fn toggleLed() void {
    std.debug.print("LED toggle\n", .{});
}

fn msToNs(ms: u16) u64 {
    return @as(u64, ms) * 1000 * 1000;
}

pub fn main() !void {
    // Check `.pass` operation
    // engine.process();
    // engine.pushKeyEvent(0, true);
    // engine.pushKeyEvent(0, false);
    // engine.pushKeyEvent(0, true);
    // engine.callScheduled(1);
    // engine.pushKeyEvent(0, false);
    // engine.callScheduled(2);
    // engine.process();

    // Check past event introspection
    engine.process();
    engine.pushKeyEvent(2, true);
    engine.process();
    std.time.sleep(msToNs(100));

    engine.pushKeyEvent(0, true);
    engine.pushKeyEvent(0, false);
    engine.pushKeyEvent(0, true);
    engine.pushKeyEvent(0, false);
    engine.process();
    std.time.sleep(msToNs(1000));

    engine.pushKeyEvent(0, true);
    engine.pushKeyEvent(0, false);
    engine.callScheduled(1);
    engine.process();
}
