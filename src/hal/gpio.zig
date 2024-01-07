const common = @import("common.zig");
const Reg32 = common.Reg32;

const ports = .{
    .a = Port{ .registers = .{
        .dir = Reg32(0x400010A0),
        .pin = Reg32(0x400010A4),
        .out = Reg32(0x400010A8),
        .pu = Reg32(0x400010B0),
        .pd_drv = Reg32(0x400010B4),
    } },
    .b = Port{ .registers = .{
        .dir = Reg32(0x400010C0),
        .pin = Reg32(0x400010C4),
        .out = Reg32(0x400010C8),
        .pu = Reg32(0x400010D0),
        .pd_drv = Reg32(0x400010D4),
    } },
};

const Port = struct {
    registers: struct {
        dir: type,
        pin: type,
        out: type,
        pu: type,
        pd_drv: type,
    },
};

const Mode = enum {
    input,
    input_pull_up,
    input_pull_down,
    output,
    output_drv,
};

fn Pin(comptime port: Port, comptime num: u5) type {
    const port_regs = port.registers;

    return packed struct {
        pub const my_port = port;
        pub const my_num = num;

        pub fn config(comptime mode: Mode) void {
            const is_output = switch (mode) {
                .output, .output_drv => true,
                .input, .input_pull_up, .input_pull_down => false,
            };

            const set_pd_drv = switch (mode) {
                .input_pull_down, .output_drv => true,
                .input, .input_pull_up, .output => false,
            };

            port_regs.dir.setBit(num, is_output);
            port_regs.pd_drv.setBit(num, set_pd_drv);

            if (!is_output) {
                port_regs.pu.setBit(num, mode == .input_pull_up);
            }
        }

        pub fn read() bool {
            return port_regs.pin.getBit(num);
        }

        pub fn write(high: bool) void {
            port_regs.out.setBit(num, high);
        }

        pub fn toggle() void {
            port_regs.out.toggleBit(num);
        }
    };
}

pub const pins = struct {
    pub const A0 = Pin(ports.a, 0);
    pub const A1 = Pin(ports.a, 1);
    pub const A2 = Pin(ports.a, 2);
    pub const A3 = Pin(ports.a, 3);
    pub const A4 = Pin(ports.a, 4);
    pub const A5 = Pin(ports.a, 5);
    pub const A6 = Pin(ports.a, 6);
    pub const A7 = Pin(ports.a, 7);
    pub const A8 = Pin(ports.a, 8);
    pub const A9 = Pin(ports.a, 9);
    pub const A10 = Pin(ports.a, 10);
    pub const A11 = Pin(ports.a, 11);
    pub const A12 = Pin(ports.a, 12);
    pub const A13 = Pin(ports.a, 13);
    pub const A14 = Pin(ports.a, 14);
    pub const A15 = Pin(ports.a, 15);

    pub const B0 = Pin(ports.b, 0);
    pub const B1 = Pin(ports.b, 1);
    pub const B2 = Pin(ports.b, 2);
    pub const B3 = Pin(ports.b, 3);
    pub const B4 = Pin(ports.b, 4);
    pub const B5 = Pin(ports.b, 5);
    pub const B6 = Pin(ports.b, 6);
    pub const B7 = Pin(ports.b, 7);
    pub const B8 = Pin(ports.b, 8);
    pub const B9 = Pin(ports.b, 9);
    pub const B10 = Pin(ports.b, 10);
    pub const B11 = Pin(ports.b, 11);
    pub const B12 = Pin(ports.b, 12);
    pub const B13 = Pin(ports.b, 13);
    pub const B14 = Pin(ports.b, 14);
    pub const B15 = Pin(ports.b, 15);
    pub const B16 = Pin(ports.b, 16);
    pub const B17 = Pin(ports.b, 17);
    pub const B18 = Pin(ports.b, 18);
    pub const B19 = Pin(ports.b, 19);
    pub const B20 = Pin(ports.b, 20);
    pub const B21 = Pin(ports.b, 21);
    pub const B22 = Pin(ports.b, 22);
    pub const B23 = Pin(ports.b, 23);
};
