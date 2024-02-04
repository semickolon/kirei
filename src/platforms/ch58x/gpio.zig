const std = @import("std");
const common = @import("common");

const gpio = @import("hal/gpio.zig");

pub const Gpio = common.Gpio(PinEnum, impl);

const GpioImplementation = common.GpioImplementation(PinEnum);
const GpioDirection = common.GpioDirection;
const GpioIrqLevel = common.GpioIrqLevel;

const impl = GpioImplementation{
    .config = config,
    .read = read,
    .write = write,
    .toggle = toggle,
    .setInterrupt = setInterrupt,
    .takeInterruptTriggered = takeInterruptTriggered,
};

fn config(num: PinEnum, dir: GpioDirection) void {
    num.pin().config(switch (dir) {
        .input => .input_pull_down,
        .output => .output,
    });
}

fn read(num: PinEnum) bool {
    return num.pin().read();
}

fn write(num: PinEnum, value: bool) void {
    num.pin().write(value);
}

fn toggle(num: PinEnum) void {
    num.pin().toggle();
}

fn setInterrupt(num: PinEnum, irq_level: ?GpioIrqLevel) void {
    if (irq_level) |level| {
        num.pin().setInterrupt(switch (level) {
            .rise => .edge,
        });
    } else {
        num.pin().setInterrupt(null);
    }
}

fn takeInterruptTriggered(num: PinEnum) bool {
    defer num.pin().clearInterruptTriggered();
    return num.pin().isInterruptTriggered();
}

pub const PinEnum = enum {
    A0,
    A1,
    A2,
    A3,
    A4,
    A5,
    A6,
    A7,
    A8,
    A9,
    A10,
    A11,
    A12,
    A13,
    A14,
    A15,

    B0,
    B1,
    B2,
    B3,
    B4,
    B5,
    B6,
    B7,
    B8,
    B9,
    B10,
    B11,
    B12,
    B13,
    B14,
    B15,
    B16,
    B17,
    B18,
    B19,
    B20,
    B21,
    B22,
    B23,

    pub fn pin(self: PinEnum) gpio.Pin {
        const n = @intFromEnum(self);
        const port_id: gpio.PortId = if (n <= @intFromEnum(PinEnum.A15)) .a else .b;
        const num: u5 = @intCast(if (port_id == .a) n else (n - 16));
        return .{ .num = num, .port_id = port_id };
    }
};
