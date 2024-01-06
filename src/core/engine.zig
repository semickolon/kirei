const std = @import("std");

const engine = @import("../config.zig").engine;

const KeyState = packed struct {
    down: bool = false,
};

const KEY_COUNT = 4;

const key_map = [KEY_COUNT]u8{
    0x09, 0x04,
    0x0E, 0x37,
};

var key_states: [KEY_COUNT]KeyState = .{.{}} ** KEY_COUNT;

const KeyboardHidOutput = struct {
    bytes: [32]u8 = std.mem.zeroes([32]u8),

    const Self = @This();

    pub fn read(self: Self, code: u8) bool {
        const byte = self.bytes[code / 8];
        const bit = byte & (1 << (code % 8));
        return bit != 0;
    }

    pub fn write(self: *Self, code: u8, down: bool) void {
        const byte = &self.bytes[code / 8];
        const bit = @as(u8, 1) << @as(u3, @intCast(code % 8));

        if (down) {
            byte.* |= bit;
        } else {
            byte.* &= ~bit;
        }

        engine.callbacks.onHidWrite(code, down);
    }
};

var hid_out = KeyboardHidOutput{};

pub fn reportKeyDown(key_idx: usize, down: bool) void {
    var ks = &key_states[key_idx];
    if (ks.down == down) return;

    ks.down = down;
    hid_out.write(key_map[key_idx], down);
}
