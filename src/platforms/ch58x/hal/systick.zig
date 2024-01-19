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

const count_control: *volatile CountControl = @ptrFromInt(0xE000F000);
const count_status: *volatile CountStatus = @ptrFromInt(0xE000F004);
const counter: *volatile u64 = @ptrFromInt(0xE000F008);
const count_reload: *volatile u64 = @ptrFromInt(0xE000F0010);

pub fn count() u64 {
    return counter.*;
}
