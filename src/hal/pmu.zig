const common = @import("common.zig");

const SleepWakeCtrl = packed struct(u8) {
    usb: bool,
    usb2: bool,
    __R0: bool,
    rtc: bool,
    gpio: bool,
    batt: bool,
    internal_memory_mode: bool,
    __R1: bool,
};

const PficSysCtrl = packed struct(u32) {
    __R0: bool,
    sleep_on_exit: bool,
    deep_sleep: bool,
    wfi_to_wfe: bool,
    sevonpend: bool, // TODO: Better name
    wake_on_event: bool,
    __R1: u25,
    sys_reset: bool,
};

const sleep_wake_ctrl: *volatile SleepWakeCtrl = @ptrFromInt(0x4000100E);

const pfic_sys_ctrl: *volatile PficSysCtrl = @ptrFromInt(0xE000ED10);

pub fn setWakeUpEvent(event: enum { usb, usb2, rtc, gpio, batt }, enabled: bool) void {
    common.safe_access_reg.enable();
    defer common.safe_access_reg.disable();

    switch (event) {
        .usb => sleep_wake_ctrl.usb = enabled,
        .usb2 => sleep_wake_ctrl.usb2 = enabled,
        .rtc => sleep_wake_ctrl.rtc = enabled,
        .gpio => sleep_wake_ctrl.gpio = enabled,
        .batt => sleep_wake_ctrl.batt = enabled,
    }
}

pub fn sleepIdle() void {
    pfic_sys_ctrl.deep_sleep = false;
    asm volatile ("wfi");
    common.safeOperate();
}
