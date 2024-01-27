const std = @import("std");
const eng = @import("../engine.zig");
const Keymap = @import("../keymap.zig").Keymap;

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;

pub const Config = struct {
    key_codes: Keymap.indices.keycodes.Slice,
};

key_codes: Keymap.indices.keycodes.Slice,

const Self = @This();

pub fn init(config: Config) Self {
    return .{ .key_codes = config.key_codes };
}

pub fn process(self: *Self, key_idx: KeyIndex, engine: *Engine, ev: *Event) ProcessResult {
    switch (ev.data) {
        .key => |key_ev| {
            if (key_idx == key_ev.key_idx) {
                ev.markHandled();
                self.handle(key_ev.down, engine);
                return if (key_ev.down) .block else .complete;
            }
        },
        else => {},
    }
    return .pass;
}

fn handle(self: Self, down: bool, engine: *Engine) void {
    for (self.key_codes.slice(&engine.keymap.h)) |key_code| {
        engine.handleKeycode(key_code, down);
    }
}
