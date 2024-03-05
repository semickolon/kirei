const std = @import("std");
const s2s = @import("s2s");
const keymap = @import("kirei").KM;

pub fn main() !void {
    try s2s.serialize(std.io.getStdOut().writer(), @TypeOf(keymap), keymap);
    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
