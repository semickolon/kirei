const std = @import("std");
const config = @import("../config.zig");

pub const Keymap = struct {
    const km = config.engine.key_map;

    pub fn parseKeydef(idx: u15) KeyDef {
        var offset: usize = 0;
        var i = idx;

        while (i > 0) : (i -= 1) {
            offset += km[offset] + 1;
        }

        var len: usize = km[offset];
        return KeyDef.parse(km[offset + 1 .. offset + 1 + len]);
    }
};

pub const KeyDef = union(enum) {
    key_press: KeyPressBehavior,

    const Self = @This();

    pub fn parse(bytes: []const u8) Self {
        return switch (bytes[0]) {
            0 => .{ .key_press = KeyPressBehavior.parse(bytes[1..]) },
            else => unreachable,
        };
    }

    pub fn process(self: *Self, eif: *const EngineInterface, ev: *const ReikiEvent) bool {
        return switch (self.*) {
            .key_press => |*b| b.process(eif, ev),
        };
    }
};

const EngineInterface = @import("engine.zig").EngineInterface;
const ReikiEvent = @import("engine.zig").ReikiEvent;

const KeyPressBehavior = struct {
    key_code: u16,

    const Self = @This();

    fn parse(bytes: []const u8) Self {
        return .{ .key_code = std.mem.readInt(u16, bytes[0..2], .Little) };
    }

    fn process(self: *Self, eif: *const EngineInterface, ev: *const ReikiEvent) bool {
        switch (ev.data) {
            .key => |*k| {
                eif.handleKeycode(self.key_code, k.down);
                return !k.down;
            },
        }
        return false;
    }
};
