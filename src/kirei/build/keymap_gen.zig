const std = @import("std");

const keymap_obj = @import("keymap_obj").K;
const serializeKeymap = @import("kirei").Keymap.Hana.serialize;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try serializeKeymap(std.io.getStdOut().writer(), keymap_obj, allocator);
    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
