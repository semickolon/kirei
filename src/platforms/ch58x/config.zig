const clocks = @import("hal/clocks.zig");
const gpio = @import("gpio.zig");
const TxPower = @import("ble/ble.zig").TxPower;

pub const kscan = .{
    .scan_interval = 2, // in 625us units
};

const ble_max_connections = .{
    .peripheral = 1,
    .central = 3,
};

pub const engine = .{
    .mem_heap_size = 1024 * 8,
};

pub const ble = .{
    .name = "Kirei",
    .mac_addr = [6]u8{ 0x68, 0x69, 0xEF, 0xBE, 0xAD, 0xDE },
    .mem_heap_size = 1024 * 4,
    .buf_max_len = 27,
    .buf_number = 8,
    .tx_num_event = 8,
    .tx_power = TxPower.dbm_n3,
    .peripheral_max_connections = ble_max_connections.peripheral,
    .central_max_connections = ble_max_connections.central,
    .total_max_connections = ble_max_connections.peripheral + ble_max_connections.central,
    .conn_interval_min = 6, // in 1.25ms units
    .conn_interval_max = 10,
};

pub const sys = .{
    .clock = clocks.SysClock.pll_60_mhz,
    .led_1 = gpio.PinEnum.A8.pin(),
};
