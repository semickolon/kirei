const std = @import("std");

const common = @import("common.zig");

const FlagCtrl = packed struct(u8) {
    __R0: u4,
    timing_clear: bool,
    trigger_clear: bool,
    timer_flag: bool,
    trigger_flag: bool,
};

const ModeCtrl = packed struct(u8) {
    timing_cycle_sec: enum(u3) { s0p125, s0p25, s0p5, s1, s2, s4, s8, s16 },
    ignore_lowest_bit: bool,
    timing_mode_enable: bool,
    trigger_mode_enable: bool,
    load_low_word: bool,
    load_high_word: bool,
};

const flag_ctrl: *volatile FlagCtrl = @ptrFromInt(0x40001030);
const mode_ctrl: *volatile ModeCtrl = @ptrFromInt(0x40001031);
const count_32k = common.Reg32.init(0x40001038);
const trig_value = common.Reg32.init(0x40001034);

pub const MAX_CYCLE_32K: u32 = 0xA8C00000;

var trigger_time_activated = false;

pub fn init() void {
    setTime(0, 0, 0);
}

pub fn setTime(day: u14, sec2: u16, khz32: u16) void {
    common.safe_access.enable();
    trig_value.set(day);
    mode_ctrl.load_high_word = true;
    // Wait until actually set
    while (day != @as(@TypeOf(day), @truncate(trig_value.get()))) {}

    common.safe_access.enable();
    trig_value.set((@as(u32, sec2) << 16) | khz32);
    mode_ctrl.load_low_word = true;

    common.safe_access.disable();
}

// TODO: Better naming. This isn't exactly the get version of `setTime`
// Gets RTC 32k cycle
pub fn getTime() u32 {
    var _t: u32 = undefined;
    var time: *volatile u32 = @ptrCast(&_t);

    // This is how it's done by the manufacturer.
    // I'm not sure why it has to do this, but maybe it's trying to get a stable value?
    while (time.* != count_32k.get()) {
        time.* = count_32k.get();
    }

    return time.*;
}

// TODO: Relocate
pub fn getTimeMillisForEngine() u16 {
    return @intCast((getTime() / 32000) % std.math.maxInt(u16));
}

pub fn setTimingMode(enabled: bool) void {
    common.safe_access.enable();
    mode_ctrl.timing_mode_enable = enabled;
    common.safe_access.disable();
}

pub fn setTriggerMode(enabled: bool) void {
    common.safe_access.enable();
    mode_ctrl.trigger_mode_enable = enabled;
    common.safe_access.disable();
}

pub fn setTriggerTime(time: u32) void {
    common.safe_access.enable();
    trig_value.set(time % MAX_CYCLE_32K);
    common.safe_access.disable();
    trigger_time_activated = false;
}

pub fn isTriggerTimeActivated() bool {
    return trigger_time_activated;
}

export fn RTC_IRQHandler() callconv(.Naked) noreturn {
    defer common.mret();

    flag_ctrl.timing_clear = true;
    flag_ctrl.trigger_clear = true;
    trigger_time_activated = true;
}
