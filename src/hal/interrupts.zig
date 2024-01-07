const common = @import("common.zig");

const rtc = @import("rtc.zig");

const InterruptNum = enum(u6) {
    reset = 1,
    nmi = 2,
    exc = 3,
    ecall_m = 5,
    ecall_u = 8,
    breakpoint = 9,
    systick = 12,
    swi = 14,
    tmr0 = 16,
    gpio_a = 17,
    gpio_b = 18,
    spi0 = 19,
    ble_lle = 20,
    ble_bb = 21,
    usb = 22,
    usb2 = 23,
    tmr1 = 24,
    tmr2 = 25,
    uart0 = 26,
    uart1 = 27,
    rtc = 28,
    adc = 29,
    i2c = 30,
    pwmx = 31,
    tmr3 = 32,
    uart2 = 33,
    uart3 = 34,
    wdog_batt = 35,
};

const ISR: *volatile [2]u32 = @ptrFromInt(0xE000E000);
const IENR: *volatile [2]u32 = @ptrFromInt(0xE000E100);
const IRER: *volatile [2]u32 = @ptrFromInt(0xE000E180);

var isr_backup: [2]u32 = undefined;

pub fn set(comptime num: InterruptNum, comptime enable: bool) void {
    const irqn = @intFromEnum(num);
    const reg = if (enable) IENR else IRER;

    reg[(irqn >> 5) & 1] = 1 << (irqn & 0x1F);

    if (!enable) {
        common.safeOperate();
    }
}

// Enables/disables all interrupts
pub fn globalSet(comptime enabled: bool) void {
    // TODO: Not atomic, not nice
    if (!enabled) {
        isr_backup = ISR.*;
        @memset(IRER, 0xFFFFFFFF);
        common.safeOperate();
    } else {
        IENR.* = isr_backup;
    }
}
