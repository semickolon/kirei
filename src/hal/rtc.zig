const common = @import("common.zig");

const RtcModeCtrl = packed struct(u8) {
    timing_cycle_sec: enum(u3) { s0p125, s0p25, s0p5, s1, s2, s4, s8, s16 },
    ignore_lowest_bit: bool,
    timing_mode_enable: bool,
    trigger_mode_enable: bool,
    load_low_word: bool,
    load_high_word: bool,
};

const CountControl = packed struct(u32) {
    enable: bool,
    interrupt_enable: bool,
    clock_source: enum { div8, div1 },
    auto_reload: bool,
    mode: enum { up, down },
    initial_update: bool,
    __R0: u25,
    swi_enable: bool, // Software interrupt
};

const CountStatus = packed struct(u32) {
    compare_flag: bool,
    __R0: u31,
};

const rtc_mode_ctrl: *volatile RtcModeCtrl = @ptrFromInt(0x40001031);
const rtc_trig_value: *volatile u32 = @ptrFromInt(0x40001034);

const count_control: *volatile CountControl = @ptrFromInt(0xE000F000);
const count_status: *volatile CountStatus = @ptrFromInt(0xE000F004);
const counter: *volatile u64 = @ptrFromInt(0xE000F008);
const count_reload: *volatile u64 = @ptrFromInt(0xE000F0010);

pub fn count() u64 {
    return counter.*;
}

pub fn init() void {
    setTime(0, 0, 0);
}

fn setTime(day: u14, sec2: u16, khz32: u16) void {
    common.safe_access_reg.enable();
    rtc_trig_value.* = day;
    rtc_mode_ctrl.load_high_word = true;
    // Wait until actually set
    while (day != @as(@TypeOf(day), @truncate(rtc_trig_value.*))) {}

    common.safe_access_reg.enable();
    rtc_trig_value.* = (@as(u32, sec2) << 16) | khz32;
    rtc_mode_ctrl.load_low_word = true;

    common.safe_access_reg.disable();
}
