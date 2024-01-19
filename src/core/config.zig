pub const key_map = [_]u8{
    3, 2, 0,    0,
    3, 0, 0x1A, 0,
    // 3, 0, 0x08, 0,
    3, 1, 0,    0,
    3, 0, 0x15, 0,
    3, 0, 0x17, 0,
    3, 0, 0x1C, 0,
    3, 0, 0x18, 0,
    3, 0, 0x0C, 0,
    3, 0, 0xE1, 0,
};

pub const key_event_queue_size: usize = 32;
pub const report_queue_size: usize = 16;

// .callbacks = .{
//     // .onReportPush = @import("platforms/ch58x/ble/ble_dev.zig").onReportPush,
// },
// .functions = .{
//     // .getTimeMillis = @import("platforms/ch58x/hal/rtc.zig").getTimeMillisForEngine,
//     // .scheduleCall = @import("platforms/ch58x/ble/scheduler.zig").scheduleCallForEngine,
// },
