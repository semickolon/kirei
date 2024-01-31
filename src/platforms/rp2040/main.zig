const std = @import("std");
const microzig = @import("microzig");

const usb = @import("usb.zig");
const interface = @import("interface.zig");
const gpio = @import("gpio.zig").Gpio;

const rp2040 = microzig.hal;
const time = rp2040.time;

const led = gpio.pin(.P25);
const uart = rp2040.uart.num(0);

pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = rp2040.uart.log;
};

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub fn main() !void {
    led.config(.output);
    led.write(true);

    uart.apply(.{
        .baud_rate = 115200,
        .tx_pin = rp2040.gpio.num(0),
        .rx_pin = rp2040.gpio.num(1),
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.init_logger(uart);

    try usb.init();
    interface.init();

    var old: u64 = time.get_time_since_boot().to_us();
    var new: u64 = 0;

    while (true) {
        try usb.process();
        interface.process();

        new = time.get_time_since_boot().to_us();

        if (new - old > 500000) {
            old = new;
            led.toggle();
        }
    }
}
