const std = @import("std");
const config = @import("../config.zig");

const engine = @import("engine.zig");
const KeyIndex = engine.KeyIndex;

pub const Keymap = struct {
    const km = config.engine.key_map;

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

pub const KeyDef = struct {
    key_idx: KeyIndex,
    behavior: Behavior,

    pub const Behavior = union(enum) {
        key_press: KeyPressBehavior,
    };

    const Self = @This();

    pub fn parse(key_idx: KeyIndex, bytes: []const u8) Self {
        return Self{
            .key_idx = key_idx,
            .behavior = switch (bytes[0]) {
                0 => .{ .key_press = KeyPressBehavior.parse(bytes[1..]) },
                else => unreachable,
            },
        };
    }

    pub fn process(self: *Self, eif: *const engine.Interface, ev: *engine.Event) engine.ProcessResult {
        return switch (self.behavior) {
            inline else => |*behavior| behavior.process(self.key_idx, eif, ev),
        };
    }
};

const KeyPressBehavior = struct {
    key_code: u16,

    const Self = @This();

    fn parse(bytes: []const u8) Self {
        return .{ .key_code = std.mem.readInt(u16, bytes[0..2], .Little) };
    }

    fn process(self: *Self, key_idx: KeyIndex, eif: *const engine.Interface, ev: *engine.Event) engine.ProcessResult {
        switch (ev.data) {
            .key => |key_ev| {
                // E is remapped to BKSP
                if (self.key_code == 8) {
                    return .{ .transform = KeyDef{ .key_idx = key_idx, .behavior = .{ .key_press = .{ .key_code = 0x2A } } } };
                }
                if (key_idx == key_ev.key_idx) {
                    ev.markHandled();
                    eif.handleKeycode(self.key_code, key_ev.down);
                    return if (key_ev.down) .block else .complete;
                }
            },
        }
        return .pass;
    }
};
