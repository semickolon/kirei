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
var umm_heap = std.mem.zeroes([16 * 1024]u8);

var drivers = [_]common.Driver(Gpio){
    .{ .matrix = .{
        .config = &.{
            .cols = &.{ Gpio.pin(.P7), Gpio.pin(.P8), Gpio.pin(.P9), Gpio.pin(.P6), Gpio.pin(.P10), Gpio.pin(.P21), Gpio.pin(.P28), Gpio.pin(.P22), Gpio.pin(.P26), Gpio.pin(.P27) },
            .rows = &.{ Gpio.pin(.P11), Gpio.pin(.P12), Gpio.pin(.P13), Gpio.pin(.P5), Gpio.pin(.P20), Gpio.pin(.P19), Gpio.pin(.P18), Gpio.pin(.P29) },
        },
    } },
};

var kscan = common.Kscan(Gpio){
    .drivers = &drivers,
    .key_mapping = &.{
        0,
        10,
        20,
        null,
        null,
        null,
        null,
        null,
        1,
        11,
        21,
        null,
        null,
        null,
        null,
        null,
        2,
        12,
        22,
        null,
        null,
        null,
        null,
        null,
        3,
        13,
        23,
        30,
        null,
        null,
        null,
        null,
        4,
        14,
        24,
        31,
        null,
        null,
        null,
        null,

        null,
        null,
        null,
        null,
        5,
        15,
        25,
        32,
        null,
        null,
        null,
        null,
        6,
        16,
        26,
        33,
        null,
        null,
        null,
        null,
        7,
        17,
        27,
        null,
        null,
        null,
        null,
        null,
        8,
        18,
        28,
        null,
        null,
        null,
        null,
        null,
        9,
        19,
        29,
        null,
    },
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

pub fn scan() void {
    kscan.process();
}

pub fn process() void {
    scheduler.process();
    engine.process();
}

fn onReportPush(report: *const [8]u8) bool {
    usb.sendReport(report) catch return false;
    return true;
}

pub fn callScheduled(token: kirei.ScheduleToken) void {
    engine.callScheduled(token);
}

fn getKireiTimeMillis() kirei.TimeMillis {
    const time_ms = time.get_time_since_boot().to_us() / 1000;
    return @intCast(time_ms % (std.math.maxInt(kirei.TimeMillis) + 1));
}
