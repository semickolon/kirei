const std = @import("std");
const eng = @import("../engine.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;

key_code: u16,

const Self = @This();

pub fn parse(bytes: []const u8) Self {
    return .{ .key_code = std.mem.readInt(u16, bytes[0..2], .Little) };
}

pub fn process(self: *Self, key_idx: KeyIndex, engine: *Engine, ev: *Event) ProcessResult {
    switch (ev.data) {
        .key => |key_ev| {
            if (key_idx == key_ev.key_idx) {
                ev.markHandled();
                engine.handleKeycode(self.key_code, key_ev.down);
                return if (key_ev.down) .block else .complete;
            }
        },
        else => {},
    }
    return .pass;
}
