const std = @import("std");
const eng = @import("engine.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const ScheduleToken = eng.ScheduleToken;
const Event = eng.Event;
const Implementation = eng.Implementation;

pub const KeyCode = u12;

pub const KeyGroup = packed struct(u32) {
    mods: packed struct(u16) {
        ctrl: Modifier = .{},
        shift: Modifier = .{},
        alt: Modifier = .{},
        gui: Modifier = .{},
    } = .{},
    key_code: KeyCode = 0,
    __padding: u4 = 0,

    pub const Modifier = packed struct(u4) {
        side: enum(u2) { none, left, right, both } = .none,
        props: Props = .{},
    };

    pub const Props = packed struct(u2) {
        retention: Retention = .normal,
        anti: bool = false,
    };

    const Retention = enum(u1) { normal, weak };

    pub fn modsAsByte(self: KeyGroup, retention: Retention, anti: bool) u8 {
        var byte: u8 = 0;

        inline for (.{ self.mods.ctrl, self.mods.shift, self.mods.alt, self.mods.gui }, 0..) |mod, i| {
            if (mod.props.retention == retention and mod.props.anti == anti) {
                byte |= switch (mod.side) {
                    .none => 0,
                    .left => (0x01 << i),
                    .right => (0x10 << i),
                    .both => (0x11 << i),
                };
            }
        }

        return byte;
    }
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
    key_group: KeyGroup,

    pub fn process(self: KeyPressBehavior, engine: *Engine, down: bool) bool {
        engine.output_hid.pushHidEvent(self.key_group, down);
        return !down;
    }
};

pub const KeyToggleBehavior = struct {
    key_group: KeyGroup,

    pub fn process(self: KeyToggleBehavior, engine: *Engine, down: bool) bool {
        _ = down;
        _ = engine;
        _ = self;
        return true;
        // TODO: Method for checking if key is pressed
        // if (down)
        //     engine.handleKeycode(self.key_code.key_code, down);
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
