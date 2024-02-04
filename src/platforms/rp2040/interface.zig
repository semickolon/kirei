const std = @import("std");
const kirei = @import("kirei");
const common = @import("common");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;

const usb = @import("usb.zig");
const scheduler = @import("scheduler.zig");
const Gpio = @import("gpio.zig").Gpio;

const UmmAllocator = @import("umm").UmmAllocator(.{});

// TODO: I cannot figure out how to embed this directly from `build.zig` since MicroZig has its own API over std build
const keymap align(4) = @embedFile("keymap.kirei").*;

var engine: kirei.Engine = undefined;

var umm: UmmAllocator = undefined;
var umm_heap = std.mem.zeroes([32 * 1024]u8);

var d1 = common.CycleDebouncer(u7){};

const kscan = common.Kscan(Gpio){
    .drivers = &.{
        .{ .matrix = .{
            .cols = &.{ Gpio.pin(.P2), Gpio.pin(.P3) },
            .rows = &.{ Gpio.pin(.P4), Gpio.pin(.P5) },
            .debouncer = &d1,
        } },
    },
    .key_mapping = &.{ 1, null, 2, 0 },
    .engine = &engine,
};

pub fn init() void {
    umm = UmmAllocator.init(&umm_heap) catch {
        std.log.err("umm alloc init failed", .{});
        return;
    };

    kscan.setup();

    engine = kirei.Engine.init(
        .{
            .allocator = umm.allocator(),
            .onReportPush = onReportPush,
            .getTimeMillis = getKireiTimeMillis,
            .scheduleCall = scheduler.enqueue,
            .cancelCall = scheduler.cancel,
        },
        &keymap,
    ) catch |e| {
        std.log.err("engine init failed: {any}", .{e});
        return;
    };
}

pub fn process() void {
    scheduler.process();
    kscan.scan();
    engine.process();
}

fn onReportPush(report: *const [8]u8) bool {
    usb.sendReport(report) catch return false;
    return true;
}

pub fn callScheduled(token: kirei.ScheduleToken) void {
    engine.callScheduled(token);
}

pub fn pushKeyEvent(key_idx: kirei.KeyIndex, down: bool) void {
    engine.pushKeyEvent(key_idx, down);
}

fn getKireiTimeMillis() kirei.TimeMillis {
    const time_ms = time.get_time_since_boot().to_us() / 1000;
    return @intCast(time_ms % (std.math.maxInt(kirei.TimeMillis) + 1));
}
