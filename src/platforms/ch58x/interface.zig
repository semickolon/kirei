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

const keymap align(4) = std.mem.zeroes([30 * 1024]u8);

var engine: kirei.Engine = undefined;

var umm: UmmAllocator = undefined;
var umm_heap = std.mem.zeroes([config.engine.mem_heap_size]u8);

pub fn init() void {
    umm = UmmAllocator.init(&umm_heap) catch {
        std.log.err("umm alloc init failed", .{});
        return;
    };

    engine = kirei.Engine.init(.{
        .allocator = umm.allocator(),
        .onReportPush = ble_dev.onReportPush,
        .getTimeMillis = getTimeMillis,
        .scheduleCall = scheduler.scheduleCall,
        .cancelCall = scheduler.cancelCall,
        .readKeymapBytes = readKeymapBytes,
    });

    loadKeymapFromEeprom() catch {
        std.log.err("load keymap failed", .{});
    };

    engine.setup() catch {
        std.log.err("engine setup failed", .{});
    };
}

fn loadKeymapFromEeprom() !void {
    var block: [256]u8 align(4) = undefined;
    var byte_offset: usize = 0;

    while (byte_offset < keymap.len) : (byte_offset +|= block.len) {
        const block_len = @min(keymap.len - byte_offset, block.len);
        const block_slice = block[0..block_len];

        try eeprom.read(@truncate(byte_offset), block_slice);
        try flash.write(&keymap[byte_offset], block_slice);
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

fn getTimeMillis() kirei.TimeMillis {
    // TODO: Handle wrap over rtc.MAX_CYCLE_32K
    return @intCast(rtc.getTimeMillis() % std.math.maxInt(u16));
}

fn readKeymapBytes(offset: usize, len: usize) []const u8 {
    return keymap[offset .. offset + len];
}
