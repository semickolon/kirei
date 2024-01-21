const std = @import("std");
const eng = @import("../engine.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;
const ScheduleToken = eng.ScheduleToken;

const KeyDef = @import("../keymap.zig").KeyDef;

pub const Config = packed struct {
    hold_keycode: u16,
    tap_keycode: u16,
    timeout_ms: u16,
};

hold_keycode: u16,
tap_keycode: u16,
timeout_ms: u16,

timeout_token: ?ScheduleToken = null,

const Self = @This();

pub fn init(config: Config) Self {
    return .{
        .hold_keycode = config.hold_keycode,
        .tap_keycode = config.tap_keycode,
        .timeout_ms = config.timeout_ms,
    };
}

pub fn process(self: *Self, key_idx: KeyIndex, engine: *Engine, ev: *Event) ProcessResult {
    const hold_decision = .{ .transform = keyPressDef(key_idx, self.hold_keycode) };
    const tap_decision = .{ .transform = keyPressDef(key_idx, self.tap_keycode) };

    switch (ev.data) {
        .key => |key_ev| {
            if (key_idx == key_ev.key_idx) {
                if (key_ev.down) {
                    if (self.timeout_token) |token| engine.cancelTimeEvent(token);
                    self.timeout_token = engine.scheduleTimeEvent(ev.time + self.timeout_ms);
                } else {
                    return tap_decision;
                }
            } else {
                return hold_decision;
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
        .behavior = .{
            .key_press = .{ .key_code = keycode },
        },
    };
}
