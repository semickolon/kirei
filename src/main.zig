const ble = @import("ble/ble.zig");
const ble_dev = @import("ble/ble_dev.zig");

const config = @import("config.zig");
const kscan = @import("kscan.zig");

const pmu = @import("hal/pmu.zig");
const clocks = @import("hal/clocks.zig");
const gpio = @import("hal/gpio.zig");

const led_1 = config.sys.led_1;

pub inline fn main() noreturn {
    pmu.useDcDc(true);

    clocks.use(config.sys.clock);
    clocks.useXt32k(false);

    led_1.config(.output);
    led_1.write(true);

    kscan.init();

    ble.init() catch unreachable;
    ble.initPeripheralRole() catch unreachable;

    ble_dev.init();

    while (true) {
        ble.process();
    }
}

export fn _zigstart() noreturn {
    main();
}
