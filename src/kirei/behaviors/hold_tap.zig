const std = @import("std");
const eng = @import("../engine.zig");

const keymap = @import("../keymap.zig");
const KeyDef = keymap.KeyDef;
const Keymap = keymap.Keymap;

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;
const ScheduleToken = eng.ScheduleToken;

pub const Config = struct {
    hold_behavior: Keymap.indices.behaviors.Single,
    tap_behavior: Keymap.indices.behaviors.Single,
    props: Keymap.indices.hold_tap_props.Single,
};

pub const Props = packed struct {
    timeout_ms: u13 = 200,
    timeout_decision: enum(u1) { hold, tap } = .hold,
    eager_decision: enum(u2) { none, hold, tap } = .none,
    quick_tap_ms: u12 = 0,
    quick_tap_interrupt_ms: u12 = 0,
};

hold_behavior: Keymap.indices.behaviors.Single,
tap_behavior: Keymap.indices.behaviors.Single,
timeout_ms: u16,

timeout_token: ?ScheduleToken = null,

const Self = @This();

pub fn init(config: Config) Self {
    return .{
        .hold_behavior = config.hold_behavior,
        .tap_behavior = config.tap_behavior,
        .timeout_ms = 200, // TODO
    };
}

pub fn process(self: *Self, key_idx: KeyIndex, engine: *Engine, ev: *Event) ProcessResult {
    const hold_decision = .{ .transform = keyPressDef(key_idx, self.hold_behavior.get(&engine.keymap.h)) };
    const tap_decision = .{ .transform = keyPressDef(key_idx, self.tap_behavior.get(&engine.keymap.h)) };

    switch (ev.data) {
        .key => |key_ev| {
            if (key_idx == key_ev.key_idx) {
                if (key_ev.down) {
                    if (self.timeout_token) |token| engine.cancelTimeEvent(token);
                    self.timeout_token = engine.scheduleTimeEvent(ev.time +% self.timeout_ms);
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

fn keyPressDef(key_idx: KeyIndex, behavior_cfg: keymap.BehaviorConfig) KeyDef {
    return .{
        .key_idx = key_idx,
        .behavior = behavior_cfg.asBehavior(),
    };
}
