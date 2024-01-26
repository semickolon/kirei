const std = @import("std");
const eng = @import("engine.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const ScheduleToken = eng.ScheduleToken;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;
const Implementation = eng.Implementation;

pub const MAGIC: u16 = 0xFA69;
pub const VERSION: u16 = 1;

pub const Keymap = struct {
    impl: Implementation,
    key_count: KeyIndex = 0,
    offset_key_defs: usize = 0,

    pub const Header = packed struct(u64) {
        magic: u16,
        version: u16,
        key_count: u16,
        id: u16,
    };

    pub fn init(impl: Implementation) Keymap {
        return .{ .impl = impl };
    }

    fn read(self: Keymap, comptime T: type, offset: usize) T {
        const bytes = self.readBytes(offset, @sizeOf(T));
        return std.mem.bytesToValue(T, bytes[0..@sizeOf(T)]);
    }

    fn readBytes(self: Keymap, offset: usize, len: usize) []const u8 {
        return self.impl.readKeymapBytes(offset, len);
    }

    pub fn setup(self: *Keymap) !void {
        const header = self.read(Header, 0);

        if (header.magic != MAGIC)
            return error.InvalidMagic;

        if (header.version != VERSION)
            return error.InvalidVersion;

        self.key_count = @truncate(header.key_count);
        self.offset_key_defs = @sizeOf(Header);

        std.log.debug("keymap: setup successful", .{});
    }

    pub fn parseKeyDef(self: Keymap, key_idx: KeyIndex) KeyDef {
        if (key_idx >= self.key_count)
            return KeyDef.empty();

        var offset: usize = self.offset_key_defs;
        var i = key_idx;

        while (i > 0) : (i -= 1) {
            offset += self.read(u8, offset) + 1;
        }

        var len: usize = self.read(u8, offset);
        return KeyDef.parse(key_idx, self.readBytes(offset + 1, len));
    }
};

pub const EmptyBehavior = @import("behaviors/empty.zig");
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
        empty: EmptyBehavior,
    };

    pub fn empty() KeyDef {
        return .{ .key_idx = 0, .behavior = .{ .empty = .{} } };
    }

    pub fn parse(key_idx: KeyIndex, bytes: []const u8) KeyDef {
        const fields = comptime switch (@typeInfo(Behavior)) {
            .Union => |u| u.fields,
            else => unreachable,
        };

        const behavior = inline for (fields, 0..) |field, i| {
            if (bytes[0] == i and field.type != EmptyBehavior) {
                const Config = field.type.Config;
                const config = std.mem.bytesToValue(Config, bytes[1 .. 1 + @sizeOf(Config)]);
                break @unionInit(Behavior, field.name, field.type.init(config));
            }
        } else {
            return KeyDef.empty();
        };

        return .{
            .key_idx = key_idx,
            .behavior = behavior,
        };
    }

    pub fn process(self: *KeyDef, engine: *Engine, ev: *Event) ProcessResult {
        return switch (self.behavior) {
            inline else => |*behavior| behavior.process(self.key_idx, engine, ev),
        };
    }
};
