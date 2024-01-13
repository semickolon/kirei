pub fn Reg(comptime T: type) type {
    return struct {
        ptr: *volatile T,

        const Self = @This();
        const Offset = switch (T) {
            u32 => u5,
            u16 => u4,
            u8 => u3,
            else => unreachable,
        };

        pub fn init(comptime address: u32) Self {
            return .{ .ptr = @ptrFromInt(address) };
        }

        pub inline fn get(self: Self) T {
            return self.ptr.*;
        }

        pub inline fn set(self: Self, value: T) void {
            self.ptr.* = value;
        }

        pub inline fn getBit(self: Self, offset: anytype) bool {
            return (self.ptr.* & (@as(T, 1) << offset)) != 0;
        }

        pub inline fn setBit(self: Self, offset: anytype, high: bool) void {
            const mask_bit = @as(T, 1) << @truncate(offset);
            if (high) {
                self.ptr.* |= mask_bit;
            } else {
                self.ptr.* &= ~mask_bit;
            }
        }

        pub inline fn toggleBit(self: Self, offset: anytype) void {
            self.ptr.* ^= @as(T, 1) << offset;
        }
    };
}

pub fn Reg32(comptime address: u32) Reg(u32) {
    return Reg(u32).init(address);
}

pub fn Reg16(comptime address: u32) Reg(u16) {
    return Reg(u16).init(address);
}

pub fn Reg8(comptime address: u32) Reg(u8) {
    return Reg(u8).init(address);
}

pub const safe_access = struct {
    const reg = Reg8(0x40001040);

    pub fn enable() void {
        reg.set(0x57);
        reg.set(0xA8);
        safeOperate();
    }

    pub fn disable() void {
        reg.set(0);
    }
};

pub inline fn nop() void {
    asm volatile ("nop");
}

pub inline fn mret() noreturn {
    asm volatile ("mret");
    unreachable;
}

pub inline fn wfi() void {
    asm volatile ("wfi");
    safeOperate();
}

pub inline fn safeOperate() void {
    nop();
    nop();
}
