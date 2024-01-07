const clocks = @import("hal/clocks.zig");
const P = @import("hal/gpio.zig").pins;
const TxPower = @import("ble/ble.zig").TxPower;

pub const engine = .{
    .key_map = [_]u8{
        // Basic HID keycodes
        0x09, 0x04, 0x0E,
        0x05, 0x06, 0x07,
        0x2A, 0x28, 0x2C,
    },
    .callbacks = .{
        .onHidWrite = @import("ble/ble_dev.zig").onHidWrite,
    },
};

pub const kscan = .{
    .matrix = .{
        .cols = .{ P.B15, P.B14, P.B13 },
        .rows = .{ P.B10, P.B7, P.B4 },
    },
};

const ble_max_connections = .{
    .peripheral = 1,
    .central = 3,
};

pub const ble = .{
    .name = "Codename Kiwi :)",
    .mac_addr = [6]u8{ 0x69, 0x69, 0x69, 0x04, 0x20, 0x66 },
    .mem_heap_size = 1024 * 6,
    .buf_max_len = 27,
    .buf_number = 5,
    .tx_num_event = 1,
    .tx_power = TxPower.dbm_0,
    .peripheral_max_connections = ble_max_connections.peripheral,
    .central_max_connections = ble_max_connections.central,
    .total_max_connections = ble_max_connections.peripheral + ble_max_connections.central,
    .conn_interval_min = 6, // in 1.25ms units
    .conn_interval_max = 10,
};

pub const sys = .{
    .clock = clocks.SysClock.pll_60_mhz,
    .led_1 = P.A8, // Flashes on sleep/wake
};
