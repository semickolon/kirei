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

const SleepPowerCtrl = packed struct(u8) {
    delay_cycle: enum { long, short, ultra_short, none },
    __R0: u2,
    clock_ram_30k_disable: bool,
    clock_ram_2k_disable: bool,
    aux_low_power: bool, // Auxiliary power low voltage enable during SRAM sleep
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

const PowerPlan = packed struct(u16) {
    flash_rom: bool = false,
    ram_2k: bool = false,
    core: bool = false,
    extend: bool = false, // USB, RF
    ram_30k: bool = false,
    __R0: bool = false,
    __R1: bool = false,
    sys_power: bool = false, // Provide sys power on VSW pin
    ldo: bool = false,
    dcdc_enable: bool = false,
    dcdc_pre: bool = false,
    __R2: u4 = 0b0010,
    enable: bool = false,
};

const sleep_wake_ctrl: *volatile SleepWakeCtrl = @ptrFromInt(0x4000100E);
const sleep_power_ctrl: *volatile SleepPowerCtrl = @ptrFromInt(0x4000100F);
const power_plan: *volatile PowerPlan = @ptrFromInt(0x40001020);

const pfic_sys_ctrl: *volatile PficSysCtrl = @ptrFromInt(0xE000ED10);

pub inline fn useDcDc(enable: bool) void {
    common.safe_access_reg.enable();
    defer common.safe_access_reg.disable();

    power_plan.dcdc_enable = enable;
    power_plan.dcdc_pre = enable;
}

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
    // TODO: Code left from WCH's examples and I don't know why
    // - FLASH_ROM_SW_RESET();
    // - R8_FLASH_CTRL = 0x04;

    pfic_sys_ctrl.deep_sleep = false;
    common.wfi();
}

pub fn sleepDeep(req_power_plan: PowerPlan) void {
    // TODO: Things left from WCH's examples and I don't know why
    // - Save and restore MAC address
    // - Disable batt. voltage detection (I get this though)
    // - Set tuning
    // - Set R8_PLL_CONFIG

    pfic_sys_ctrl.deep_sleep = true;

    var new_power_plan = req_power_plan;
    new_power_plan.dcdc_enable = power_plan.dcdc_enable;
    new_power_plan.dcdc_pre = power_plan.dcdc_pre;
    new_power_plan.core = true;
    new_power_plan.enable = true;

    common.nop();
    common.safe_access_reg.enable();

    sleep_power_ctrl.aux_low_power = true;
    power_plan.* = new_power_plan;

    common.wfi();
    // TODO: Delay 70us here

    common.safe_access_reg.disable();
}
