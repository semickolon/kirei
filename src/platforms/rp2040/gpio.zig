const std = @import("std");
const common = @import("common");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;

const PinEnum = enum(u5) {
    P0,
    P1,
    P2,
    P3,
    P4,
    P5,
    P6,
    P7,
    P8,
    P9,
    P10,
    P11,
    P12,
    P13,
    P14,
    P15,
    P16,
    P17,
    P18,
    P19,
    P20,
    P21,
    P22,
    P23,
    P24,
    P25,
    P26,
    P27,
    P28,
    P29,

    pub fn pin(self: PinEnum) gpio.Pin {
        return gpio.num(@intFromEnum(self));
    }
};

pub const Gpio = common.Gpio(PinEnum, impl);

const GpioImplementation = common.GpioImplementation(PinEnum);
const GpioDirection = common.GpioDirection;

const impl = GpioImplementation{
    .config = config,
    .read = read,
    .write = write,
    .toggle = toggle,
};

fn config(num: PinEnum, dir: GpioDirection) void {
    num.pin().set_function(.sio);
    num.pin().set_direction(switch (dir) {
        .input => .in,
        .output => .out,
    });
}

fn read(num: PinEnum) bool {
    return num.pin().read() != 0;
}

fn write(num: PinEnum, value: bool) void {
    num.pin().put(if (value) 1 else 0);
}

fn toggle(num: PinEnum) void {
    num.pin().toggle();
}
