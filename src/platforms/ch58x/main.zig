const std = @import("std");

const ble = @import("ble/ble.zig");
const ble_dev = @import("ble/ble_dev.zig");

const config = @import("config.zig");
const kscan = @import("kscan.zig");
const interface = @import("interface.zig");

const pmu = @import("hal/pmu.zig");
const clocks = @import("hal/clocks.zig");
const gpio = @import("hal/gpio.zig");

const debug = @import("debug.zig");

const led_1 = config.sys.led_1;

inline fn main() noreturn {
    pmu.useDcDc(true);

    clocks.use(config.sys.clock);
    clocks.useXt32k(false);

    led_1.config(.output);
    led_1.write(true);

    debug.init();

    var buf = [_]u8{0} ** 128;

    ble.init() catch |e| {
        _ = std.fmt.bufPrintZ(&buf, "ble.init failed! {any}\r\n", .{e}) catch unreachable;
        debug.print(&buf);
    };
    ble.initPeripheralRole() catch |e| {
        _ = std.fmt.bufPrintZ(&buf, "ble.perinit failed! {any}\r\n", .{e}) catch unreachable;
        debug.print(&buf);
    };

    ble_dev.init();
    kscan.init();
    interface.init();

    debug.print("init success!\r\n");

    while (true) {
        kscan.process();
        interface.process();
        ble.process();
    }
}

export fn _zigstart() noreturn {
    main();
}
