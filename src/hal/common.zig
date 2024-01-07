pub fn Reg(comptime T: type, comptime address: u32) type {
    return struct {
        const ptr: *volatile T = @ptrFromInt(address);

        const Self = @This();

        pub inline fn get() T {
            return ptr.*;
        }

        pub inline fn set(value: T) void {
            ptr.* = value;
        }

        pub inline fn getBit(comptime offset: comptime_int) bool {
            return (ptr.* & (1 << offset)) != 0;
        }

        pub inline fn setBit(comptime offset: comptime_int, high: bool) void {
            if (high) {
                ptr.* |= (1 << offset);
            } else {
                ptr.* &= ~@as(T, 1 << offset);
            }
        }

        pub inline fn toggleBit(comptime offset: comptime_int) void {
            ptr.* ^= (1 << offset);
        }
    };
}

pub fn Reg32(comptime address: u32) type {
    return Reg(u32, address);
}

pub fn Reg16(comptime address: u32) type {
    return Reg(u16, address);
}

pub fn Reg8(comptime address: u32) type {
    return Reg(u8, address);
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
