pub fn Reg(comptime T: type) type {
    return packed struct {
        ptr: *volatile T,

        pub fn get(comptime self: @This()) callconv(.Inline) T {
            return self.ptr.*;
        }

        pub fn set(comptime self: @This(), value: T) callconv(.Inline) void {
            self.ptr.* = value;
        }

        pub fn getBit(comptime self: @This(), comptime offset: comptime_int) callconv(.Inline) bool {
            return (self.ptr.* & (1 << offset)) != 0;
        }

        pub fn setBit(comptime self: @This(), comptime offset: comptime_int, high: bool) void {
            if (high) {
                self.ptr.* |= (1 << offset);
            } else {
                self.ptr.* &= ~@as(T, 1 << offset);
            }
        }

        pub fn toggleBit(comptime self: @This(), comptime offset: comptime_int) callconv(.Inline) void {
            self.ptr.* ^= (1 << offset);
        }
    };
}

pub const r32 = Reg(u32);
pub const r16 = Reg(u16);
pub const r8 = Reg(u8);

pub fn r32At(comptime address: u32) r32 {
    return .{ .ptr = @as(*volatile u32, @ptrFromInt(address)) };
}

pub fn r16At(comptime address: u32) r16 {
    return .{ .ptr = @as(*volatile u16, @ptrFromInt(address)) };
}

pub fn r8At(comptime address: u32) r8 {
    return .{ .ptr = @as(*volatile u8, @ptrFromInt(address)) };
}

pub const safe_access_reg = packed struct {
    const reg = r8At(0x40001040);

    pub fn enable() void {
        reg.set(0x57);
        reg.set(0xA8);
    }

    pub fn disable() void {
        reg.set(0);
    }
};

pub fn nop() callconv(.Inline) void {
    asm volatile ("nop");
}

const R16_POWER_PLAN = r16At(0x40001020);
const RB_PWR_DCDC_PRE = 10;
const RB_PWR_DCDC_EN = 9;

pub fn useDcDc(comptime enable: bool) callconv(.Inline) void {
    safe_access_reg.enable();

    R16_POWER_PLAN.setBit(RB_PWR_DCDC_PRE, enable);
    R16_POWER_PLAN.setBit(RB_PWR_DCDC_EN, enable);

    safe_access_reg.disable();
}
