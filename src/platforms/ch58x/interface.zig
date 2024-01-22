const std = @import("std");
const kirei = @import("kirei");

const ble_dev = @import("ble/ble_dev.zig");
const rtc = @import("hal/rtc.zig");
const scheduler = @import("ble/scheduler.zig");
const debug = @import("debug.zig");
const eeprom = @import("hal/eeprom.zig");
const config = @import("config.zig");

const UmmAllocator = @import("umm").UmmAllocator(.{});

var keymapBytes: [256]u8 = undefined;

var engine: kirei.Engine = undefined;

var umm: UmmAllocator = undefined;
var umm_heap = std.mem.zeroes([config.engine.mem_heap_size]u8);

pub fn init() void {
    umm = UmmAllocator.init(&umm_heap) catch {
        debug.print("umm alloc init failed");
        return;
    };

    engine = kirei.Engine.init(.{
        .allocator = umm.allocator(),
        .onReportPush = ble_dev.onReportPush,
        .getTimeMillis = getTimeMillis,
        .scheduleCall = scheduler.scheduleCall,
        .cancelCall = scheduler.cancelCall,
        .readKeymapBytes = readKeymapBytes,
        .print = debug.print,
    });

    eeprom.read(0, &keymapBytes) catch {
        debug.print("luh siya!!\r\n");
    };

    engine.setup() catch {
        debug.print("engine setup failed\r\n");
    };
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
    return keymapBytes[offset .. offset + len];
}
