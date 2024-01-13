const common = @import("common.zig");
const Reg32 = common.Reg32;
const Reg16 = common.Reg16;

const interrupts = @import("interrupts.zig");

const std = @import("std");
const InterruptBitSet = std.bit_set.IntegerBitSet(16);

var pa_int_trig = InterruptBitSet.initEmpty();
var pb_int_trig = InterruptBitSet.initEmpty();

const ports = .{
    .a = Port{
        .registers = .{
            .dir = Reg32(0x400010A0),
            .pin = Reg32(0x400010A4),
            .out = Reg32(0x400010A8),
            .pu = Reg32(0x400010B0),
            .pd_drv = Reg32(0x400010B4),
            .interrupt_enable = Reg16(0x40001090),
            .interrupt_mode = Reg16(0x40001094),
            .interrupt_flag = Reg16(0x4000109C),
        },
        .interrupt_num = .gpio_a,
        .interrupt_triggered = @ptrCast(&pa_int_trig),
    },
    .b = Port{
        .registers = .{
            .dir = Reg32(0x400010C0),
            .pin = Reg32(0x400010C4),
            .out = Reg32(0x400010C8),
            .pu = Reg32(0x400010D0),
            .pd_drv = Reg32(0x400010D4),
            .interrupt_enable = Reg16(0x40001092),
            .interrupt_mode = Reg16(0x40001096),
            .interrupt_flag = Reg16(0x4000109E),
        },
        .interrupt_num = .gpio_b,
        .interrupt_triggered = @ptrCast(&pb_int_trig),
    },
};

const Port = struct {
    registers: struct {
        dir: type,
        pin: type,
        out: type,
        pu: type,
        pd_drv: type,
        interrupt_enable: type,
        interrupt_mode: type,
        interrupt_flag: type,
    },
    interrupt_num: interrupts.InterruptNum,
    interrupt_triggered: *InterruptBitSet,
};

const Mode = enum {
    input,
    input_pull_up,
    input_pull_down,
    output,
    output_drv,
};

fn Pin(comptime port: Port, comptime num: u5) type {
    const port_regs = port.registers;

    return struct {
        pub fn config(comptime mode: Mode) void {
            const is_output = switch (mode) {
                .output, .output_drv => true,
                .input, .input_pull_up, .input_pull_down => false,
            };

            const set_pd_drv = switch (mode) {
                .input_pull_down, .output_drv => true,
                .input, .input_pull_up, .output => false,
            };

            port_regs.dir.setBit(num, is_output);
            port_regs.pd_drv.setBit(num, set_pd_drv);

            if (!is_output) {
                port_regs.pu.setBit(num, mode == .input_pull_up);
            }
        }

        pub fn read() bool {
            return port_regs.pin.getBit(num);
        }

        pub fn write(high: bool) void {
            port_regs.out.setBit(num, high);
        }

        pub inline fn toggle() void {
            port_regs.out.toggleBit(num);
        }

        pub fn setInterrupt(trigger: ?enum(u1) { level, edge }) void {
            if (trigger) |trig| {
                port_regs.interrupt_mode.setBit(num, trig == .edge);
                port_regs.out.setBit(num, true);
                port_regs.interrupt_enable.setBit(num, true);
                interrupts.set(port.interrupt_num, true);
            } else {
                port_regs.interrupt_enable.setBit(num, false);
                interrupts.set(port.interrupt_num, port_regs.interrupt_enable.get() != 0);
            }
        }

        pub fn isInterruptTriggered() bool {
            defer port.interrupt_triggered.unset(num);
            return port.interrupt_triggered.isSet(num);
        }
    };
}

pub fn isInterruptTriggered() bool {
    return pa_int_trig.mask != 0 or pb_int_trig.mask != 0;
}

pub const pins = struct {
    pub const A0 = Pin(ports.a, 0);
    pub const A1 = Pin(ports.a, 1);
    pub const A2 = Pin(ports.a, 2);
    pub const A3 = Pin(ports.a, 3);
    pub const A4 = Pin(ports.a, 4);
    pub const A5 = Pin(ports.a, 5);
    pub const A6 = Pin(ports.a, 6);
    pub const A7 = Pin(ports.a, 7);
    pub const A8 = Pin(ports.a, 8);
    pub const A9 = Pin(ports.a, 9);
    pub const A10 = Pin(ports.a, 10);
    pub const A11 = Pin(ports.a, 11);
    pub const A12 = Pin(ports.a, 12);
    pub const A13 = Pin(ports.a, 13);
    pub const A14 = Pin(ports.a, 14);
    pub const A15 = Pin(ports.a, 15);

    pub const B0 = Pin(ports.b, 0);
    pub const B1 = Pin(ports.b, 1);
    pub const B2 = Pin(ports.b, 2);
    pub const B3 = Pin(ports.b, 3);
    pub const B4 = Pin(ports.b, 4);
    pub const B5 = Pin(ports.b, 5);
    pub const B6 = Pin(ports.b, 6);
    pub const B7 = Pin(ports.b, 7);
    pub const B8 = Pin(ports.b, 8);
    pub const B9 = Pin(ports.b, 9);
    pub const B10 = Pin(ports.b, 10);
    pub const B11 = Pin(ports.b, 11);
    pub const B12 = Pin(ports.b, 12);
    pub const B13 = Pin(ports.b, 13);
    pub const B14 = Pin(ports.b, 14);
    pub const B15 = Pin(ports.b, 15);
    pub const B16 = Pin(ports.b, 16);
    pub const B17 = Pin(ports.b, 17);
    pub const B18 = Pin(ports.b, 18);
    pub const B19 = Pin(ports.b, 19);
    pub const B20 = Pin(ports.b, 20);
    pub const B21 = Pin(ports.b, 21);
    pub const B22 = Pin(ports.b, 22);
    pub const B23 = Pin(ports.b, 23);
};

inline fn irq_handler(comptime port: Port) void {
    const int_flag = port.registers.interrupt_flag;
    const flags = int_flag.get();

    port.interrupt_triggered.mask |= flags;
    int_flag.set(flags);
}

export fn GPIOA_IRQHandler() callconv(.Naked) noreturn {
    defer common.mret();
    irq_handler(ports.a);
}

export fn GPIOB_IRQHandler() callconv(.Naked) noreturn {
    defer common.mret();
    irq_handler(ports.b);
}
