const std = @import("std");
const kirei = @import("kirei");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;

const usb = @import("usb.zig");

const UmmAllocator = @import("umm").UmmAllocator(.{});

// TODO: I cannot figure out how to embed this directly from `build.zig` since MicroZig has its own API over std build
const keymap align(4) = @embedFile("keymap.kirei").*;

var engine: kirei.Engine = undefined;

var umm: UmmAllocator = undefined;
var umm_heap = std.mem.zeroes([32 * 1024]u8);

pub fn init() void {
    umm = UmmAllocator.init(&umm_heap) catch {
        std.log.err("umm alloc init failed", .{});
        return;
    };

    engine = kirei.Engine.init(
        .{
            .allocator = umm.allocator(),
            .onReportPush = onReportPush,
            .getTimeMillis = getTimeMillis,
            .scheduleCall = scheduleCall,
            .cancelCall = cancelCall,
        },
        &keymap,
    ) catch |e| {
        std.log.err("engine init failed: {any}", .{e});
        return;
    };
}

pub fn process() void {
    engine.process();
}

fn onReportPush(report: *const [8]u8) bool {
    usb.sendReport(report);
    return true;
}

pub fn callScheduled(token: kirei.ScheduleToken) void {
    engine.callScheduled(token);
}

pub fn pushKeyEvent(key_idx: kirei.KeyIndex, down: bool) void {
    engine.pushKeyEvent(key_idx, down);
}

fn getTimeMillis() kirei.TimeMillis {
    const time_ms = time.get_time_since_boot().to_us() / 1000;
    return @intCast(time_ms % (std.math.maxInt(kirei.TimeMillis) + 1));
}

pub fn scheduleCall(duration: kirei.TimeMillis, token: kirei.ScheduleToken) void {
    _ = token;
    _ = duration;
}

pub fn cancelCall(token: kirei.ScheduleToken) void {
    _ = token;
}
