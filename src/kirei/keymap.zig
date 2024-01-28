const std = @import("std");
const hana = @import("hana");
const eng = @import("engine.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const ScheduleToken = eng.ScheduleToken;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;
const Implementation = eng.Implementation;

pub const Keycode = u16;

pub const Keymap = struct {
    impl: Implementation,
    h: Hana = undefined,

    pub const Hana = hana.Hana(File, &[_]hana.CollectionIndex{
        .{ .T = Keycode, .Index = u16 },
        .{ .T = BehaviorConfig, .Index = u16 },
        .{ .T = HoldTapBehavior.Props, .Index = u8 },
        .{ .T = HoldTapBehavior.Props.KeyInterrupt, .Index = u16 },
    });

    pub const indices = struct {
        pub const keycodes = Hana.Indices[0];
        pub const behaviors = Hana.Indices[1];
        pub const hold_tap_props = Hana.Indices[2];
        pub const hold_tap_key_interrupts = Hana.Indices[3];
    };

    pub const File = packed struct {
        header: Header,
        behaviors: Hana.Indices[1].Slice,
    };

    pub const Header = packed struct(u32) {
        magic: u16 = MAGIC,
        version: u16 = VERSION,

        pub const MAGIC: u16 = 0xFA69;
        pub const VERSION: u16 = 1;
    };

    pub fn init(impl: Implementation, bytes: []align(4) const u8) !Keymap {
        const keymap = Keymap{
            .impl = impl,
            .h = Hana.deserialize(bytes),
        };

        const header = keymap.h.value.*.header;

        if (header.magic != Header.MAGIC)
            return error.InvalidMagic;

        if (header.version != Header.VERSION)
            return error.InvalidVersion;

        return keymap;
    }

    pub fn parseKeyDef(self: *Keymap, key_idx: KeyIndex) KeyDef {
        return KeyDef.parse(key_idx, &self.h);
    }
};

pub const KeyPressBehavior = @import("behaviors/key_press.zig");
pub const HoldTapBehavior = @import("behaviors/hold_tap.zig");
pub const TapDanceBehavior = @import("behaviors/tap_dance.zig");

pub const BehaviorConfig = union(enum) {
    key_press: KeyPressBehavior.Config,
    hold_tap: HoldTapBehavior.Config,
    tap_dance: TapDanceBehavior.Config,

    pub fn asBehavior(self: BehaviorConfig) Behavior {
        return switch (self) {
            .key_press => |cfg| .{ .key_press = KeyPressBehavior.init(cfg) },
            .hold_tap => |cfg| .{ .hold_tap = HoldTapBehavior.init(cfg) },
            .tap_dance => |cfg| .{ .tap_dance = TapDanceBehavior.init(cfg) },
        };
    }
};

pub const Behavior = union(enum) {
    key_press: KeyPressBehavior,
    hold_tap: HoldTapBehavior,
    tap_dance: TapDanceBehavior,
};

pub const KeyDef = struct {
    key_idx: KeyIndex,
    behavior: Behavior,

    pub fn parse(key_idx: KeyIndex, h: *Keymap.Hana) KeyDef {
        const behavior_cfg = h.value.behaviors.at(h, key_idx);
        return .{
            .key_idx = key_idx,
            .behavior = behavior_cfg.asBehavior(),
        };
    }

    pub fn process(self: *KeyDef, engine: *Engine, ev: *Event) ProcessResult {
        return switch (self.behavior) {
            inline else => |*behavior| behavior.process(self.key_idx, engine, ev),
        };
    }
};
