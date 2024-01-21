const std = @import("std");
const eng = @import("../engine.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;

pub const Config = packed struct {
    key_code: u16,
};

key_code: u16,

const Self = @This();

pub fn init(config: Config) Self {
    return .{ .key_code = config.key_code };
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

// fn handle(self: Self, down: bool, engine: *Engine) void {
//     for (0..self.config.key_codes_len) |i| {
//         const idx = self.config.key_codes_idx_start + @as(u16, @intCast(i));
//         const key_code = engine.keymap.keyCodeAt(idx);
//         engine.handleKeycode(key_code, down);
//     }
// }
