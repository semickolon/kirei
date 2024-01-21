const gpio = @import("hal/gpio.zig");
const config = @import("config.zig");

const txd1 = gpio.pins.A9;

const R8_UART1_FCR: *volatile u8 = @ptrFromInt(0x40003402);
const R8_UART1_LCR: *volatile u8 = @ptrFromInt(0x40003403);
const R8_UART1_IER: *volatile u8 = @ptrFromInt(0x40003401);
const R8_UART1_DIV: *volatile u8 = @ptrFromInt(0x4000340E);
const R16_UART1_DL: *volatile u16 = @ptrFromInt(0x4000340C);
const R8_UART1_TFC: *volatile u8 = @ptrFromInt(0x4000340B);
const R8_UART1_THR: *volatile u8 = @ptrFromInt(0x40003408);

pub fn init() void {
    txd1.write(true);
    txd1.config(.output);

    R16_UART1_DL.* = baudRateDl(115200);
    R8_UART1_FCR.* = 135;
    R8_UART1_LCR.* = 3;
    R8_UART1_IER.* = 0x40;
    R8_UART1_DIV.* = 1;
}

fn baudRateDl(baudrate: u32) u16 {
    var x: u32 = undefined;
    x = 10 * config.sys.clock.freq() / 8 / baudrate;
    x = (x + 5) / 10;
    return @truncate(x);
}

pub fn print(str: []const u8) void {
    var i: usize = 0;

    while (i < str.len) {
        if (str[i] == 0)
            break;

        if (R8_UART1_TFC.* != 8) {
            R8_UART1_THR.* = str[i];
            i += 1;
        }
    }
}
