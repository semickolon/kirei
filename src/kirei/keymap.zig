const std = @import("std");
const eng = @import("engine.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const ScheduleToken = eng.ScheduleToken;
const Event = eng.Event;
// const ProcessResult = eng.ProcessResult;
const Implementation = eng.Implementation;

pub const KeyCode = packed struct(u32) {
    mods: packed struct(u8) {
        lctl: bool = false,
        lsft: bool = false,
        lgui: bool = false,
        lalt: bool = false,
        rctl: bool = false,
        rsft: bool = false,
        rgui: bool = false,
        ralt: bool = false,
    } = .{},
    hid_code: u8,
    __pad: u16 = 0,
};

pub const KeyMap = []const KeyDef;

pub const KeyDef = union(enum) {
    // Simple
    none: void,
    key_press: KeyPressBehavior,
    key_toggle: KeyToggleBehavior,
    // Sync
    hold_tap: HoldTapBehavior,

    pub const Type = enum { simple, sync };

    pub fn getType(self: KeyDef) Type {
        return switch (self) {
            .none, .key_press, .key_toggle => .simple,
            .hold_tap => .sync,
        };
    }

    pub fn processSimple(self: KeyDef, engine: *Engine, down: bool) bool {
        return switch (self) {
            .none => true,
            .key_press => |e| e.process(engine, down),
            .key_toggle => |e| e.process(engine, down),
            else => unreachable,
        };
    }

    pub fn processSync(self: KeyDef, engine: *Engine, key_idx: KeyIndex, ev: Event) SyncBehaviorResult {
        return switch (self) {
            .hold_tap => |e| e.process(engine, key_idx, ev),
            else => unreachable,
        };
    }
};

pub const KeyPressBehavior = struct {
    key_code: KeyCode,

    pub fn process(self: KeyPressBehavior, engine: *Engine, down: bool) bool {
        engine.handleKeycode(self.key_code, down);
        return !down;
    }
};

pub const KeyToggleBehavior = struct {
    key_code: KeyCode,

    pub fn process(self: KeyToggleBehavior, engine: *Engine, down: bool) bool {
        _ = down;
        _ = engine;
        _ = self;
        return true;
        // TODO: Method for checking if key is pressed
        // if (down)
        //     engine.handleKeycode(self.key_code.hid_code, down);
    }
};

pub const SyncBehaviorResult = struct {
    event_handled: bool,
    action: union(enum) {
        block: void,
        transform: ?*const KeyDef,
    },
};

var ht_token: ScheduleToken = 0;

pub const HoldTapBehavior = struct {
    hold_key_def: *const KeyDef,
    tap_key_def: *const KeyDef,
    timeout_ms: u16,

    const Self = @This();

    pub fn process(self: Self, engine: *Engine, key_idx: KeyIndex, ev: Event) SyncBehaviorResult {
        switch (ev.data) {
            .key => |k| {
                if (k.key_idx == key_idx) {
                    if (k.down) {
                        ht_token = engine.scheduleTimeEvent(ev.time + self.timeout_ms);
                        return .{ .event_handled = false, .action = .block };
                    } else {
                        engine.cancelTimeEvent(ht_token);
                        return .{ .event_handled = false, .action = .{ .transform = self.tap_key_def } };
                    }
                } else if (!k.down) { // hold on release
                    return .{ .event_handled = false, .action = .{ .transform = self.hold_key_def } };
                }
            },
            .time => |t| {
                if (t.token == ht_token) {
                    return .{ .event_handled = true, .action = .{ .transform = self.hold_key_def } };
                }
            },
        }

        return .{ .event_handled = false, .action = .block };
    }
};
