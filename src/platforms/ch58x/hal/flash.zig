const isp = @import("isp.zig");
const interrupts = @import("interrupts.zig");

fn toCLong(n: anytype) c_long {
    return @intCast(n);
}

pub fn erase(addr: []const u8) !void {
    interrupts.globalSet(false);
    defer interrupts.globalSet(true);

    const result = isp.FLASH_ROM_ERASE(
        toCLong(@intFromPtr(addr.ptr)),
        toCLong(addr.len),
    );
    if (result != 0)
        return error.Failure;
}

pub fn write(addr: *const anyopaque, buf: []align(4) u8) !void {
    interrupts.globalSet(false);
    defer interrupts.globalSet(true);

    const result = isp.FLASH_ROM_WRITE(
        toCLong(@intFromPtr(addr)),
        buf.ptr,
        toCLong(buf.len),
    );
    if (result != 0)
        return error.Failure;
}

pub fn verify(addr: *const anyopaque, buf: []align(4) u8) !void {
    interrupts.globalSet(false);
    defer interrupts.globalSet(true);

    const result = isp.FLASH_ROM_VERIFY(
        toCLong(@intFromPtr(addr)),
        buf.ptr,
        toCLong(buf.len),
    );
    if (result != 0)
        return error.Failure;
}
