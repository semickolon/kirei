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

const keymap: kirei.KeyMap = &.{
    .{ .key_press = .{ .key_code = .{ .hid_code = 4 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 5 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 6 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 7 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 8 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 9 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 10 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 11 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 12 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 13 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 14 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 15 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 16 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 17 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 18 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 19 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 20 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 21 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 22 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 23 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 24 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 25 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 26 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 27 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 28 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 29 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 4 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 4 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 4 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 4 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 20 } } },
    // .{ .key_press = .{ .key_code = .{ .hid_code = 21 } } },
    .{ .hold_tap = .{
        .tap_key_def = &.{ .key_press = .{ .key_code = .{ .hid_code = 4 } } },
        .hold_key_def = &.{ .key_press = .{ .key_code = .{ .hid_code = 5 } } },
        .timeout_ms = 1000,
    } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 22 } } },
    .{ .key_press = .{ .key_code = .{ .hid_code = 23 } } },
};

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
        null, //17,
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
        keymap,
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
