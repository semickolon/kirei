const common = @import("common.zig");
const Reg = common.Reg;

const interrupts = @import("interrupts.zig");

const std = @import("std");
const InterruptBitSet = std.bit_set.IntegerBitSet(16);

var pa_int_trig = InterruptBitSet.initEmpty();
var pb_int_trig = InterruptBitSet.initEmpty();

const port_a = Port{
    .registers = .{
        .dir = common.Reg32(0x400010A0),
        .pin = common.Reg32(0x400010A4),
        .out = common.Reg32(0x400010A8),
        .pu = common.Reg32(0x400010B0),
        .pd_drv = common.Reg32(0x400010B4),
        .interrupt_enable = common.Reg16(0x40001090),
        .interrupt_mode = common.Reg16(0x40001094),
        .interrupt_flag = common.Reg16(0x4000109C),
    },
    .interrupt_num = .gpio_a,
    .interrupt_triggered = @ptrCast(&pa_int_trig),
};

const port_b = Port{
    .registers = .{
        .dir = common.Reg32(0x400010C0),
        .pin = common.Reg32(0x400010C4),
        .out = common.Reg32(0x400010C8),
        .pu = common.Reg32(0x400010D0),
        .pd_drv = common.Reg32(0x400010D4),
        .interrupt_enable = common.Reg16(0x40001092),
        .interrupt_mode = common.Reg16(0x40001096),
        .interrupt_flag = common.Reg16(0x4000109E),
    },
    .interrupt_num = .gpio_b,
    .interrupt_triggered = @ptrCast(&pb_int_trig),
};

const Port = struct {
    registers: PortRegisters,
    interrupt_num: interrupts.InterruptNum,
    interrupt_triggered: *InterruptBitSet,
};

const PortRegisters = struct {
    dir: Reg(u32),
    pin: Reg(u32),
    out: Reg(u32),
    pu: Reg(u32),
    pd_drv: Reg(u32),
    interrupt_enable: Reg(u16),
    interrupt_mode: Reg(u16),
    interrupt_flag: Reg(u16),
};

const Mode = enum {
    input,
    input_pull_up,
    input_pull_down,
    output,
    output_drv,
};

pub const Pin = packed struct {
    num: u5,
    port_id: enum(u1) { a, b },

    const Self = @This();

    fn port(self: Self) Port {
        return switch (self.port_id) {
            .a => port_a,
            .b => port_b,
        };
    }

    fn portRegs(self: Self) PortRegisters {
        return self.port().registers;
    }

    pub fn config(self: Self, comptime mode: Mode) void {
        const is_output = switch (mode) {
            .output, .output_drv => true,
            .input, .input_pull_up, .input_pull_down => false,
        };

        const set_pd_drv = switch (mode) {
            .input_pull_down, .output_drv => true,
            .input, .input_pull_up, .output => false,
        };

        const port_regs = self.portRegs();
        port_regs.dir.setBit(self.num, is_output);
        port_regs.pd_drv.setBit(self.num, set_pd_drv);

        if (!is_output) {
            port_regs.pu.setBit(self.num, mode == .input_pull_up);
        }
    }

    pub fn read(self: Self) bool {
        return self.portRegs().pin.getBit(self.num);
    }

    pub fn write(self: Self, high: bool) void {
        self.portRegs().out.setBit(self.num, high);
    }

    pub fn toggle(self: Self) void {
        self.portRegs().out.toggleBit(self.num);
    }

    pub fn setInterrupt(self: Self, trigger: bool) void {
        const port_regs = self.portRegs();
        const int_num = self.port().interrupt_num;

        if (trigger) {
            port_regs.interrupt_mode.setBit(self.num, true);
            port_regs.out.setBit(self.num, true);
            port_regs.interrupt_enable.setBit(self.num, true);
            interrupts.set(int_num, true);
        } else {
            port_regs.interrupt_enable.setBit(self.num, false);
            interrupts.set(int_num, port_regs.interrupt_enable.get() != 0);
        }
    }

    pub fn isInterruptTriggered(self: Self) bool {
        return self.port().interrupt_triggered.isSet(self.num);
    }

    pub fn clearInterruptTriggered(self: Self) void {
        self.port().interrupt_triggered.unset(self.num);
    }
};

pub fn isInterruptTriggered() bool {
    return pa_int_trig.mask != 0 or pb_int_trig.mask != 0;
}

pub const pins = struct {
    pub const A0 = Pin{ .port_id = .a, .num = 0 };
    pub const A1 = Pin{ .port_id = .a, .num = 1 };
    pub const A2 = Pin{ .port_id = .a, .num = 2 };
    pub const A3 = Pin{ .port_id = .a, .num = 3 };
    pub const A4 = Pin{ .port_id = .a, .num = 4 };
    pub const A5 = Pin{ .port_id = .a, .num = 5 };
    pub const A6 = Pin{ .port_id = .a, .num = 6 };
    pub const A7 = Pin{ .port_id = .a, .num = 7 };
    pub const A8 = Pin{ .port_id = .a, .num = 8 };
    pub const A9 = Pin{ .port_id = .a, .num = 9 };
    pub const A10 = Pin{ .port_id = .a, .num = 10 };
    pub const A11 = Pin{ .port_id = .a, .num = 11 };
    pub const A12 = Pin{ .port_id = .a, .num = 12 };
    pub const A13 = Pin{ .port_id = .a, .num = 13 };
    pub const A14 = Pin{ .port_id = .a, .num = 14 };
    pub const A15 = Pin{ .port_id = .a, .num = 15 };

    pub const B0 = Pin{ .port_id = .b, .num = 0 };
    pub const B1 = Pin{ .port_id = .b, .num = 1 };
    pub const B2 = Pin{ .port_id = .b, .num = 2 };
    pub const B3 = Pin{ .port_id = .b, .num = 3 };
    pub const B4 = Pin{ .port_id = .b, .num = 4 };
    pub const B5 = Pin{ .port_id = .b, .num = 5 };
    pub const B6 = Pin{ .port_id = .b, .num = 6 };
    pub const B7 = Pin{ .port_id = .b, .num = 7 };
    pub const B8 = Pin{ .port_id = .b, .num = 8 };
    pub const B9 = Pin{ .port_id = .b, .num = 9 };
    pub const B10 = Pin{ .port_id = .b, .num = 10 };
    pub const B11 = Pin{ .port_id = .b, .num = 11 };
    pub const B12 = Pin{ .port_id = .b, .num = 12 };
    pub const B13 = Pin{ .port_id = .b, .num = 13 };
    pub const B14 = Pin{ .port_id = .b, .num = 14 };
    pub const B15 = Pin{ .port_id = .b, .num = 15 };
    pub const B16 = Pin{ .port_id = .b, .num = 16 };
    pub const B17 = Pin{ .port_id = .b, .num = 17 };
    pub const B18 = Pin{ .port_id = .b, .num = 18 };
    pub const B19 = Pin{ .port_id = .b, .num = 19 };
    pub const B20 = Pin{ .port_id = .b, .num = 20 };
    pub const B21 = Pin{ .port_id = .b, .num = 21 };
    pub const B22 = Pin{ .port_id = .b, .num = 22 };
    pub const B23 = Pin{ .port_id = .b, .num = 23 };
};

inline fn irq_handler(comptime port: Port) void {
    const int_flag = port.registers.interrupt_flag;
    const flags = int_flag.get();

    port.interrupt_triggered.mask |= flags;
    int_flag.set(flags);
}

export fn GPIOA_IRQHandler() callconv(.Naked) noreturn {
    defer common.mret();
    irq_handler(port_a);
}

export fn GPIOB_IRQHandler() callconv(.Naked) noreturn {
    defer common.mret();
    irq_handler(port_b);
}
