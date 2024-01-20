const std = @import("std");
const eng = @import("../engine.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;
const ScheduleToken = eng.ScheduleToken;

const KeyDef = @import("../keymap.zig").KeyDef;

hold_keycode: u16 = 0xE0,
tap_keycode: u16 = 0x08,
timeout_ms: u16 = 2000,
timeout_token: ?ScheduleToken = null,

const Self = @This();

pub fn parse() Self {
    return .{};
}

pub fn process(self: *Self, key_idx: KeyIndex, engine: *Engine, ev: *Event) ProcessResult {
    const hold_decision = .{ .transform = keyPressDef(key_idx, 'z' - 'a' + 4) };
    const tap_decision = .{ .transform = keyPressDef(key_idx, self.tap_keycode) };

    // TODO: Nested hold-taps are not yet time-aware
    switch (ev.data) {
        .key => |key_ev| {
            if (key_idx == key_ev.key_idx) {
                if (key_ev.down) {
                    self.timeout_token = engine.scheduleTimeEvent(ev.time + self.timeout_ms);
                } else {
                    return tap_decision;
                }
            } else {
                // return hold_decision;
            }
        },
        .time => |time_ev| {
            if (time_ev.token == self.timeout_token) {
                ev.markHandled();
                return hold_decision;
            }
        },
    }
    return .block;
}

fn keyPressDef(key_idx: KeyIndex, keycode: u16) KeyDef {
    return .{
        .key_idx = key_idx,
        .behavior = .{ .key_press = .{ .key_code = keycode } },
    };
}
