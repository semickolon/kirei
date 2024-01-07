const common = @import("common.zig");
const safe_access = common.safe_access;

const clk_sys_cfg: *volatile Reg16ClkSysCfg = @ptrFromInt(0x40001008);
const hfck_pwr_ctrl: *volatile Reg8HfckPwrCtrl = @ptrFromInt(0x4000100A);
const ck32k_cfg: *volatile Reg8Ck32kCfg = @ptrFromInt(0x4000102F);
const analog_ie = common.Reg16(0x4000101A);

const Reg16ClkSysCfg = packed struct(u16) {
    freq_div: u5,
    __R0: bool,
    clk_src: SysClockSource,
    __R1: u8,
};

const Reg8HfckPwrCtrl = packed struct(u8) {
    __R0: u2,
    xt32m_power_on: bool,
    xt32m_keep: bool,
    pll_power_on: bool,
    __R1: u3,
};

const Reg8Ck32kCfg = packed struct(u8) {
    xt_power_on: bool,
    int_power_on: bool,
    xt_use: bool,
    int_filter: bool,
    __R0: u3,
    clk_pin: bool,
};

const SysClockSource = enum(u2) {
    ck32m = 0,
    pll = 1,
    ck32k = 3,
};

pub const SysClock = enum {
    xt32k,
    int32k,
    xt32m_2_mhz,
    xt32m_3_2_mhz,
    xt32m_4_mhz,
    xt32m_6_4_mhz,
    xt32m_8_mhz,
    pll_20_mhz,
    pll_24_mhz,
    pll_30_mhz,
    pll_32_mhz,
    pll_48_mhz,
    pll_60_mhz,

    pub fn clkSrc(comptime self: @This()) SysClockSource {
        return switch (self) {
            .xt32m_2_mhz, .xt32m_3_2_mhz, .xt32m_4_mhz, .xt32m_6_4_mhz, .xt32m_8_mhz => .ck32m,
            .pll_20_mhz, .pll_24_mhz, .pll_30_mhz, .pll_32_mhz, .pll_48_mhz, .pll_60_mhz => .pll,
            .xt32k, .int32k => .ck32k,
        };
    }

    pub fn freqDiv(comptime self: @This()) comptime_int {
        return switch (self) {
            .xt32k, .int32k => 2,
            .xt32m_2_mhz => 16,
            .xt32m_3_2_mhz => 10,
            .xt32m_4_mhz => 8,
            .xt32m_6_4_mhz => 5,
            .xt32m_8_mhz => 4,
            .pll_20_mhz => 24,
            .pll_24_mhz => 20,
            .pll_30_mhz => 16,
            .pll_32_mhz => 15,
            .pll_48_mhz => 10,
            .pll_60_mhz => 8,
        };
    }

    pub fn freq(comptime self: @This()) comptime_int {
        return switch (self) {
            .xt32k, .int32k => 32_000,
            .xt32m_2_mhz => 2_000_000,
            .xt32m_3_2_mhz => 3_200_000,
            .xt32m_4_mhz => 4_000_000,
            .xt32m_6_4_mhz => 6_400_000,
            .xt32m_8_mhz => 8_000_000,
            .pll_20_mhz => 20_000_000,
            .pll_24_mhz => 24_000_000,
            .pll_30_mhz => 30_000_000,
            .pll_32_mhz => 32_000_000,
            .pll_48_mhz => 48_000_000,
            .pll_60_mhz => 60_000_000,
        };
    }
};

pub fn use(comptime sys_clock: SysClock) void {
    const clk_src = sys_clock.clkSrc();
    const freq_div = sys_clock.freqDiv();

    safe_access.enable();

    clk_sys_cfg.clk_src = clk_src;
    clk_sys_cfg.freq_div = freq_div;

    hfck_pwr_ctrl.pll_power_on = clk_src == .pll;

    if (sys_clock == .xt32k) {
        useXt32k(true);
    } else if (sys_clock == .int32k) {
        useXt32k(false);
    }

    safe_access.disable();
}

pub fn useXt32k(comptime enable: bool) void {
    ck32k_cfg.xt_power_on = enable;
    ck32k_cfg.int_power_on = !enable;
    ck32k_cfg.xt_use = enable;

    analog_ie.setBit(13, enable);
}
