const std = @import("std");
const kirei = @import("kirei");
const common = @import("common");

const ble_dev = @import("ble/ble_dev.zig");
const tmos = @import("ble/tmos.zig");
const rtc = @import("hal/rtc.zig");
const scheduler = @import("ble/scheduler.zig");
const debug = @import("debug.zig");
const eeprom = @import("hal/eeprom.zig");
const flash = @import("hal/flash.zig");
const config = @import("config.zig");

const UmmAllocator = @import("umm").UmmAllocator(.{});
const Gpio = @import("gpio.zig").Gpio;
const Duration = @import("duration.zig").Duration;

const keymap align(4) = @embedFile("keymap").*;

var engine: kirei.Engine = undefined;

var umm: UmmAllocator = undefined;
var umm_heap = std.mem.zeroes([config.engine.mem_heap_size]u8);

const tmos_blueprint = tmos.TaskBlueprint{
    .Event = enum(u4) { scan },
    .events_callback = &.{scan},
};
var tmos_task: tmos.Task(tmos_blueprint.Event) = undefined;

var drivers = [_]common.Driver(Gpio){
    .{ .matrix = .{
        .config = &.{
            .cols = &.{ Gpio.pin(.B11), Gpio.pin(.B10), Gpio.pin(.B7), Gpio.pin(.B4) },
            .rows = &.{ Gpio.pin(.A14), Gpio.pin(.A15), Gpio.pin(.A5), Gpio.pin(.A4) },
        },
    } },
};

const kscan = common.Kscan(Gpio){
    .drivers = &drivers,
    .engine = &engine,
};

pub fn init() void {
    tmos_task = tmos.register(tmos_blueprint);
    umm = UmmAllocator.init(&umm_heap) catch {
        std.log.err("umm alloc init failed", .{});
        return;
    };

    kscan.setup();

    // loadKeymapFromEeprom() catch {
    //     std.log.err("load keymap failed", .{});
    // };

    engine = kirei.Engine.init(
        .{
            .allocator = umm.allocator(),
            .onReportPush = ble_dev.onReportPush,
            .getTimeMillis = getKireiTimeMillis,
            .scheduleCall = scheduler.enqueue,
            .cancelCall = scheduler.cancel,
        },
        &keymap,
    ) catch |e| {
        std.log.err("engine init failed: {any}", .{e});
        return;
    };

    scheduleNextScan();
}

fn loadKeymapFromEeprom() !void {
    var block: [256]u8 align(4) = undefined;
    var byte_offset: usize = 0;

    while (byte_offset < keymap.len) : (byte_offset +|= block.len) {
        const block_len = @min(keymap.len - byte_offset, block.len);
        const block_slice = block[0..block_len];

        try eeprom.read(@truncate(byte_offset), block_slice);
        // @memcpy(keymap[byte_offset .. byte_offset + block_len], block_slice);
        // TODO: Fix. This is unreliable. Verification fails.
        try flash.write(&keymap[byte_offset], block_slice);
        try flash.verify(&keymap[byte_offset], block_slice);
    }
}

fn scan() void {
    kscan.process();
    scheduleNextScan();
}

// TODO: This is always periodicaly called.
// Kscan drivers should be the one doing the scheduling instead, to reduce wakeups and power draw.
fn scheduleNextScan() void {
    tmos_task.scheduleEvent(.scan, Duration.fromMicros(tmos.SYSTEM_TIME_US * config.kscan.scan_interval));
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

fn getKireiTimeMillis() kirei.TimeMillis {
    // TODO: Handle wrap over rtc.MAX_CYCLE_32K
    return @intCast(rtc.getTimeMillis() % (std.math.maxInt(u16) + 1));
}
