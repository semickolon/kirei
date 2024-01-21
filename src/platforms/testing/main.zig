const std = @import("std");
const kirei = @import("kirei");

const HidReport = [8]u8;

var engine = kirei.Engine.init(.{
    .onReportPush = onReportPush,
    .getTimeMillis = getTimeMillis,
    .scheduleCall = scheduleCall,
    .cancelCall = cancelCall,
    .toggleLed = toggleLed,
    .readKeymapBytes = readKeymapBytes,
    .print = print,
});

pub const key_map = [_]u8{
    0x69, 0xFA, 1,    0,
    9,    0,    0,    0,
    3,    0,    9,    0,
    3,    0,    0x1A, 0,
    3,    0,    10,   0,
    3,    0,    0x15, 0,
    3,    0,    0x17, 0,
    3,    0,    0x1C, 0,
    3,    0,    0x18, 0,
    3,    0,    0x0C, 0,
    3,    0,    0xE1, 0,
};

fn onReportPush(report: *const HidReport) bool {
    std.debug.print("{any}\n", .{report.*});
    return true;
}

fn getTimeMillis() kirei.TimeMillis {
    const m: kirei.TimeMillis = @truncate(@as(u64, @intCast(std.time.milliTimestamp())) % std.math.maxInt(kirei.TimeMillis));
    // std.debug.print("getTimeMillis: {any}\n", .{m});
    return m;
}

fn scheduleCall(duration: kirei.TimeMillis, token: kirei.ScheduleToken) void {
    std.debug.print("{any}ms scheduled as token {any}\n", .{ duration, token });
}

fn cancelCall(token: kirei.ScheduleToken) void {
    _ = token;
}

fn toggleLed() void {
    std.debug.print("LED toggle\n", .{});
}

fn readKeymapBytes(offset: usize, len: usize) []const u8 {
    return key_map[offset .. offset + len];
}

fn print(str: []const u8) void {
    _ = std.io.getStdOut().write(str) catch unreachable;
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

    engine.setup() catch unreachable;

    engine.process();
    engine.pushKeyEvent(1, true);
    engine.pushKeyEvent(2, true);
    engine.pushKeyEvent(8, true);
    engine.process();
}
