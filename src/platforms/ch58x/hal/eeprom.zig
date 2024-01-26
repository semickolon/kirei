const isp = @import("isp.zig");

pub const Address = u15; // EEPROM is 32KB

fn cu32(n: u32) c_long {
    return @intCast(n);
}

pub fn read(addr: Address, buf: []u8) !void {
    if (addr % 4 != 0)
        return error.InvalidAddressAlignment;

    const result = isp.EEPROM_READ(addr, buf.ptr, cu32(buf.len));

    if (result != 0)
        return error.Failure;
}

pub fn write(addr: Address, buf: []u8) !void {
    if (addr % 4 != 0)
        return error.InvalidAddressAlignment;

    try erase(addr, buf.len);
    const result = isp.EEPROM_WRITE(addr, buf.ptr, cu32(buf.len));

    if (result != 0)
        return error.Failure;
}

pub fn erase(addr: Address, len: usize) !void {
    if (addr % 4 != 0)
        return error.InvalidAddressAlignment;

    const result = isp.EEPROM_ERASE(addr, cu32(len));

    if (result != 0)
        return error.Failure;
}
