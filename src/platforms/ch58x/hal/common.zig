pub fn Reg(comptime T: type) type {
    return struct {
        ptr: *volatile T,

        const Self = @This();
        const Offset = switch (@bitSizeOf(T)) {
            32 => u5,
            16 => u4,
            8 => u3,
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

pub const Reg32 = Reg(u32);
pub const Reg16 = Reg(u16);
pub const Reg8 = Reg(u8);

pub const safe_access = struct {
    const reg = Reg8.init(0x40001040);

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
