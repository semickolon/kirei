const std = @import("std");

const config = @import("../config.zig");
const Queue = @import("data_structs.zig").Queue;

const KeyState = packed struct {
    down: bool = false,
};

pub const KeyIndex = u15;
pub const TimeMillis = u16;

pub const KeyEvent = packed struct(u32) {
    key_idx: KeyIndex,
    down: bool,
    time: u16,
};

var key_event_queue: Queue(KeyEvent, 64) = undefined;

const KEY_COUNT = config.engine.key_map.len;

const key_map = config.engine.key_map;
const callbacks = config.engine.callbacks;

var key_states: [KEY_COUNT]KeyState = .{.{}} ** KEY_COUNT;

const KeyboardHidOutput = struct {
    bytes: [32]u8 = std.mem.zeroes([32]u8),

    const Self = @This();

    pub fn read(self: Self, code: u8) bool {
        const byte = self.bytes[code / 8];
        const bit = byte & (1 << (code % 8));
        return bit != 0;
    }

    pub fn write(self: *Self, code: u8, down: bool) void {
        const byte = &self.bytes[code / 8];
        const bit = @as(u8, 1) << @as(u3, @intCast(code % 8));

        if (down) {
            byte.* |= bit;
        } else {
            byte.* &= ~bit;
        }

        callbacks.onHidWrite(code, down);
    }
};

var hid_out = KeyboardHidOutput{};

pub fn process() void {
    while (key_event_queue.pop()) |ev| {
        hid_out.write(key_map[ev.key_idx], ev.down);
    }
}

pub fn pushKeyEvent(key_idx: KeyIndex, down: bool) void {
    var ks = &key_states[key_idx];
    if (ks.down == down) return;

    ks.down = down;
    key_event_queue.push(.{
        .key_idx = key_idx,
        .down = down,
        .time = 0,
    }) catch unreachable;
}
