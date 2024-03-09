const std = @import("std");
const s2s = @import("s2s");
const key_map = @import("keymap").key_map;

pub fn main() !void {
    try s2s.serialize(std.io.getStdOut().writer(), @TypeOf(key_map), key_map);
    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
