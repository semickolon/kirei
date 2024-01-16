const clocks = @import("hal/clocks.zig");
const gpio = @import("hal/gpio.zig");
const P = gpio.pins;
const TxPower = @import("ble/ble.zig").TxPower;

pub const engine = .{
    .key_map = [_]u8{
        3, 0, 0x14, 0,
        3, 0, 0x1A, 0,
        // 3, 0, 0x08, 0,
        3, 1, 0,    0,
        3, 0, 0x15, 0,
        3, 0, 0x17, 0,
        3, 0, 0x1C, 0,
        3, 0, 0x18, 0,
        3, 0, 0x0C, 0,
        3, 0, 0xE1, 0,
    },
    .key_event_queue_size = 32,
    .report_queue_size = 16,
    .callbacks = .{
        .onReportPush = @import("ble/ble_dev.zig").onReportPush,
    },
    .functions = .{
        .getTimeMillis = @import("hal/rtc.zig").getTimeMillisForEngine,
        .scheduleCall = @import("ble/scheduler.zig").scheduleCallForEngine,
    },
};

pub const kscan = .{
    .matrix = .{
        .cols = [_]gpio.Pin{ P.B15, P.B14, P.B13 },
        .rows = [_]gpio.Pin{ P.B10, P.B7, P.B4 },
    },
    .scan_interval = 2, // in 625us units
};

const ble_max_connections = .{
    .peripheral = 1,
    .central = 3,
};

pub const ble = .{
    .name = "Kirei",
    .mac_addr = [6]u8{ 0x68, 0x69, 0xEF, 0xBE, 0xAD, 0xDE },
    .mem_heap_size = 1024 * 6,
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
    .led_1 = P.A8,
};
