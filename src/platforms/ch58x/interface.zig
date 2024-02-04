const std = @import("std");
const kirei = @import("kirei");

const ble_dev = @import("ble/ble_dev.zig");
const rtc = @import("hal/rtc.zig");
const scheduler = @import("ble/scheduler.zig");
const debug = @import("debug.zig");
const eeprom = @import("hal/eeprom.zig");
const flash = @import("hal/flash.zig");
const config = @import("config.zig");

const UmmAllocator = @import("umm").UmmAllocator(.{});

var keymap align(4) = std.mem.zeroes([2 * 1024]u8);

var engine: kirei.Engine = undefined;

var umm: UmmAllocator = undefined;
var umm_heap = std.mem.zeroes([config.engine.mem_heap_size]u8);

pub fn init() void {
    umm = UmmAllocator.init(&umm_heap) catch {
        std.log.err("umm alloc init failed", .{});
        return;
    };

    loadKeymapFromEeprom() catch {
        std.log.err("load keymap failed", .{});
    };

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
}

fn loadKeymapFromEeprom() !void {
    var block: [256]u8 align(4) = undefined;
    var byte_offset: usize = 0;

    while (byte_offset < keymap.len) : (byte_offset +|= block.len) {
        const block_len = @min(keymap.len - byte_offset, block.len);
        const block_slice = block[0..block_len];

        try eeprom.read(@truncate(byte_offset), block_slice);
        @memcpy(keymap[byte_offset .. byte_offset + block_len], block_slice);
        // TODO: Fix. This is unreliable.
        // try flash.write(&keymap[byte_offset], block_slice);
    }
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
