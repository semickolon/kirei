const c = @import("lib/ch583.zig");
const clocks = @import("hal/clocks.zig");
const gpio = @import("hal/gpio.zig");

const ble_max_connections = .{
    .peripheral = 1,
    .central = 3,
};

pub const ble = .{
    .mem_heap_size = 1024 * 6,
    .mac_addr = [6]u8{ 0x69, 0x69, 0x69, 0x04, 0x20, 0x66 },
    .buf_max_len = 27,
    .buf_number = 5,
    .tx_num_event = 1,
    .tx_power = c.LL_TX_POWEER_0_DBM,
    .peripheral_max_connections = ble_max_connections.peripheral,
    .central_max_connections = ble_max_connections.central,
    .total_max_connections = ble_max_connections.peripheral + ble_max_connections.central,
    .conn_interval_min = 8, // in 1.25ms units
    .conn_interval_max = 8,
    .name = "Codename Kiwi :)",
};

pub const sys = .{
    .clock = clocks.SysClock.pll_60_mhz,
    .led_1 = gpio.pins.A8,
};

pub const engine = .{
    .callbacks = .{
        .onHidWrite = @import("ble/ble_dev.zig").onHidWrite,
    },
};
