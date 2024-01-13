const std = @import("std");

const config = @import("../config.zig");
const Queue = @import("data_structs.zig").Queue;
const output = @import("output_hid.zig");

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

pub fn process() void {
    while (key_event_queue.pop()) |ev| {
        output.pushHidEvent(
            key_map[ev.key_idx],
            ev.down,
        ) catch unreachable;
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
