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
    bindings: Keymap.indices.behaviors.Slice,
    tapping_term_ms: u16,
};

bindings: Keymap.indices.behaviors.Slice,
tapping_term_ms: u16,

tap_counter: u8 = 0,
resolved_tap_count: u8 = 0,
tapping_term_token: ?ScheduleToken = null,
unwind: bool = false,

const Self = @This();

pub fn init(config: Config) Self {
    return .{
        .bindings = config.bindings,
        .tapping_term_ms = config.tapping_term_ms,
    };
}

pub fn process(self: *Self, key_idx: KeyIndex, engine: *Engine, ev: *Event) ProcessResult {
    if (self.unwind) {
        switch (ev.data) {
            .key => |key_ev| if (key_idx == key_ev.key_idx) {
                ev.markHandled();
                if (!key_ev.down) {
                    self.tap_counter -= 1;
                }
            },
            else => {},
        }

        if (self.tap_counter == 1) {
            return .{ .transform = keyPressDef(key_idx, self.bindings.at(&engine.keymap.h, self.resolved_tap_count - 1)) };
        }
    } else {
        self.unwind = self.tally(key_idx, engine, ev);

        if (self.unwind) {
            self.resolved_tap_count = self.tap_counter;

            return if (self.resolved_tap_count == 1)
                .{ .transform = keyPressDef(key_idx, self.bindings.at(&engine.keymap.h, 0)) }
            else if (self.resolved_tap_count > 1)
                .{ .transform = KeyDef{ .key_idx = key_idx, .behavior = .{ .tap_dance = self.* } } }
            else
                .complete;
        }
    }
    return .block;
}

fn tally(self: *Self, key_idx: KeyIndex, engine: *Engine, ev: *Event) bool {
    switch (ev.data) {
        .key => |key_ev| {
            if (key_idx == key_ev.key_idx) {
                if (key_ev.down) {
                    self.tap_counter += 1;

                    if (self.tap_counter < self.bindings.len) {
                        if (self.tapping_term_token) |token| engine.cancelTimeEvent(token);
                        self.tapping_term_token = engine.scheduleTimeEvent(ev.time + self.tapping_term_ms);
                    } else {
                        return true;
                    }
                }
            } else {
                return true;
            }
        },
        .time => |time_ev| if (time_ev.token == self.tapping_term_token) {
            ev.markHandled();
            return true;
        },
    }
    return false;
}

fn keyPressDef(key_idx: KeyIndex, behavior_cfg: keymap.BehaviorConfig) KeyDef {
    return .{
        .key_idx = key_idx,
        .behavior = behavior_cfg.asBehavior(),
    };
}
