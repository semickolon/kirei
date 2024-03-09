const std = @import("std");
const eng = @import("engine.zig");
const lang = @import("lang.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const ScheduleToken = eng.ScheduleToken;
const Event = eng.Event;
const Implementation = eng.Implementation;

const Expression = lang.Expression;

pub const KeyMap = []const Expression(KeyDef);

pub const KeyCode = u12;

const KeyCodeInfo = struct {
    kind: Kind,
    id: u8,

    const Kind = enum {
        hid_keyboard_code, // 0x04 - 0xDF
        hid_keyboard_modifier, // 0xE0 - 0xE7
        kirei_state_a, // 0xE8 - 0x107
        reserved,
    };
};

pub fn keyCodeInfo(key_code: KeyCode) KeyCodeInfo {
    const ranges = .{
        // .{ start inclusive, end inclusive, kind, offset }
        .{ 0x04, 0xDF, KeyCodeInfo.Kind.hid_keyboard_code, 4 },
        .{ 0xE0, 0xE7, KeyCodeInfo.Kind.hid_keyboard_modifier, 0 },
        .{ 0xE8, 0x107, KeyCodeInfo.Kind.kirei_state_a, 0 },
    };

    inline for (ranges) |range| {
        if (key_code >= range[0] and key_code <= range[1]) {
            comptime std.debug.assert((range[1] - range[0] + range[3]) < 256);
            return .{
                .kind = range[2],
                .id = @truncate(key_code - range[0] + range[3]),
            };
        }
    }

    return .{ .kind = .reserved, .id = 0 };
}

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

    pub const Retention = enum(u1) { normal, weak };

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

pub const Macro = struct {
    steps: Expression(Steps),

    pub const Steps = []const Step;
    pub const default: Macro = .{ .steps = .{ .literal = &.{} } };

    pub fn execute(self: Macro, engine: *Engine) void {
        for (self.steps.resolve(engine)) |step| {
            step.execute(engine);
        }
    }
};

pub const Step = union(enum) {
    press: KeyGroup,
    release: KeyGroup,
    tap: KeyGroup,

    pub fn execute(self: Step, engine: *Engine) void {
        switch (self) {
            .press => |key_group| {
                engine.output_hid.pushKeyGroup(key_group, true);
            },
            .release => |key_group| {
                engine.output_hid.pushKeyGroup(key_group, false);
            },
            .tap => |key_group| {
                engine.output_hid.pushKeyGroup(key_group, true);
                engine.output_hid.pushKeyGroup(key_group, false);
            },
        }
    }
};

pub const KeyPressBehavior = struct {
    key_group: KeyGroup,
    hooks: ?*const struct {
        on_press: Macro = Macro.default,
        on_release: Macro = Macro.default,
    } = null,

    pub fn process(self: KeyPressBehavior, engine: *Engine, down: bool) bool {
        if (self.hooks) |h| {
            if (down) h.on_press.execute(engine);
        }

        engine.output_hid.pushKeyGroup(self.key_group, down);

        if (self.hooks) |h| {
            if (!down) h.on_release.execute(engine);
        }

        return !down;
    }
};

pub const KeyToggleBehavior = struct {
    key_group: KeyGroup,
    hooks: ?*const struct {
        on_toggle_down: Macro = Macro.default,
        on_toggle_up: Macro = Macro.default,
    } = null,

    pub fn process(self: KeyToggleBehavior, engine: *Engine, down: bool) bool {
        if (down) {
            const toggle_down = !engine.output_hid.isKeyCodePressed(self.key_group.key_code);

            if (self.hooks) |h| {
                if (toggle_down) h.on_toggle_down.execute(engine);
            }

            engine.output_hid.pushKeyGroup(self.key_group, toggle_down);

            if (self.hooks) |h| {
                if (!toggle_down) h.on_toggle_up.execute(engine);
            }
        }

        return true;
    }
};

pub const SyncBehaviorResult = struct {
    event_handled: bool,
    action: union(enum) {
        block: void,
        transform: ?KeyDef,
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
                        return .{ .event_handled = false, .action = .{ .transform = self.tap_key_def.* } };
                    }
                } else if (!k.down) { // hold on release
                    return .{ .event_handled = false, .action = .{ .transform = self.hold_key_def.* } };
                }
            },
            .time => |t| {
                if (t.token == ht_token) {
                    return .{ .event_handled = true, .action = .{ .transform = self.hold_key_def.* } };
                }
            },
        }

        return .{ .event_handled = false, .action = .block };
    }
};
