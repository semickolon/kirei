const common = @import("common.zig");

const RtcModeCtrl = packed struct(u8) {
    timing_cycle_sec: enum(u3) { s0p125, s0p25, s0p5, s1, s2, s4, s8, s16 },
    ignore_lowest_bit: bool,
    timing_mode_enable: bool,
    trigger_mode_enable: bool,
    load_low_word: bool,
    load_high_word: bool,
};

const mode_ctrl: *volatile RtcModeCtrl = @ptrFromInt(0x40001031);
const trig_value: *volatile u32 = @ptrFromInt(0x40001034);

pub fn init() void {
    setTime(0, 0, 0);
}

pub fn setTime(day: u14, sec2: u16, khz32: u16) void {
    common.safe_access_reg.enable();
    trig_value.* = day;
    mode_ctrl.load_high_word = true;
    // Wait until actually set
    while (day != @as(@TypeOf(day), @truncate(trig_value.*))) {}

    common.safe_access_reg.enable();
    trig_value.* = (@as(u32, sec2) << 16) | khz32;
    mode_ctrl.load_low_word = true;

    common.safe_access_reg.disable();
}

pub fn setTimingMode(enabled: bool) void {
    common.safe_access_reg.enable();
    mode_ctrl.timing_mode_enable = enabled;
    common.safe_access_reg.disable();
}

pub fn setTriggerMode(enabled: bool) void {
    common.safe_access_reg.enable();
    mode_ctrl.trigger_mode_enable = enabled;
    common.safe_access_reg.disable();
}
