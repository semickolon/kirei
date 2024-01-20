const std = @import("std");
const config = @import("config.zig");

const eng = @import("engine.zig");
const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const ScheduleToken = eng.ScheduleToken;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;

pub const Keymap = struct {
    const km = config.key_map;

    pub fn parseKeydef(key_idx: KeyIndex) KeyDef {
        var offset: usize = 0;
        var i = key_idx;

        while (i > 0) : (i -= 1) {
            offset += km[offset] + 1;
        }

        var len: usize = km[offset];
        return KeyDef.parse(key_idx, km[offset + 1 .. offset + 1 + len]);
    }
};

pub const KeyPressBehavior = @import("behaviors/key_press.zig");
pub const HoldTapBehavior = @import("behaviors/hold_tap.zig");
pub const TapDanceBehavior = @import("behaviors/tap_dance.zig");

pub const KeyDef = struct {
    key_idx: KeyIndex,
    behavior: Behavior,

    pub const Behavior = union(enum) {
        key_press: KeyPressBehavior,
        hold_tap: HoldTapBehavior,
        tap_dance: TapDanceBehavior,
    };

    const Self = @This();

    pub fn parse(key_idx: KeyIndex, bytes: []const u8) Self {
        return Self{
            .key_idx = key_idx,
            .behavior = switch (bytes[0]) {
                0 => .{ .key_press = KeyPressBehavior.parse(bytes[1..]) },
                1 => .{ .hold_tap = HoldTapBehavior.parse() },
                2 => .{ .tap_dance = TapDanceBehavior.parse() },
                else => unreachable,
            },
        };
    }

    pub fn process(self: *Self, engine: *Engine, ev: *Event) ProcessResult {
        return switch (self.behavior) {
            inline else => |*behavior| behavior.process(self.key_idx, engine, ev),
        };
    }
};
