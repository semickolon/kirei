export fn _zigstart() noreturn {
    main();
}

const ble = @import("ble/ble.zig");
const ble_dev = @import("ble/ble_dev.zig");

const config = @import("config.zig");

const common = @import("hal/common.zig");
const clocks = @import("hal/clocks.zig");
const gpio = @import("hal/gpio.zig");

const led_1 = config.sys.led_1;

const P = gpio.pins;
const matrix_cols = [_]type{ P.B10, P.B11, P.B12, P.B13, P.B14 };
const matrix_rows = [_]type{ P.B22, P.A4, P.B4 };

const KeyState = struct {
    pressed: bool = false,
    ticks: u16 = 0,
};

var key_states: [matrix_cols.len][matrix_rows.len]KeyState = .{
    .{ KeyState{}, KeyState{}, KeyState{} },
    .{ KeyState{}, KeyState{}, KeyState{} },
    .{ KeyState{}, KeyState{}, KeyState{} },
    .{ KeyState{}, KeyState{}, KeyState{} },
    .{ KeyState{}, KeyState{}, KeyState{} },
};

pub fn main() noreturn {
    common.useDcDc(true);

    clocks.use(config.sys.clock);
    clocks.useXt32k(false);

    led_1.config(.output);
    led_1.write(true);

    inline for (matrix_cols) |col| {
        col.config(.output);
    }

    inline for (matrix_rows) |row| {
        row.config(.input_pull_down);
    }

    ble.init() catch unreachable;
    ble.initPeripheralRole() catch unreachable;

    ble_dev.init();

    while (true) {
        inline for (matrix_cols, 0..) |col, i| {
            col.write(true);
            colSwitchDelay();

            inline for (matrix_rows, 0..) |row, j| {
                var ks = &key_states[i][j];
                const reading = row.read();

                if (ks.ticks > 0) {
                    ks.ticks -= 1;

                    if (ks.ticks == 0 and reading != ks.pressed) {
                        ks.pressed = reading;
                        const code: u8 = (j * matrix_cols.len) + i + 4;
                        ble_dev.notify(if (reading) code else 0);
                    }
                } else if (reading != ks.pressed) {
                    ks.ticks = 100;
                }
            }

            col.write(false);
        }

        ble.process();
    }
}

fn colSwitchDelay() void {
    inline for (0..4) |_| {
        asm volatile ("nop");
    }
}
