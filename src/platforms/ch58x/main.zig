const std = @import("std");

const ble = @import("ble/ble.zig");
const ble_dev = @import("ble/ble_dev.zig");

const config = @import("config.zig");
const interface = @import("interface.zig");

const pmu = @import("hal/pmu.zig");
const clocks = @import("hal/clocks.zig");
const gpio = @import("hal/gpio.zig");

const debug = @import("debug.zig");

const led_1 = config.sys.led_1;

inline fn main() noreturn {
    pmu.useDcDc(true);

    clocks.use(config.sys.clock);
    clocks.useXt32k(false);

    led_1.config(.output);
    led_1.write(true);

    debug.init();

    std.log.info("Kirei 🌸", .{});

    ble.init() catch |e| {
        std.log.err("ble.init failed! {any}", .{e});
    };
    ble.initPeripheralRole() catch |e| {
        std.log.err("ble.perinit failed! {any}", .{e});
    };

    ble_dev.init();
    interface.init();

    std.log.debug("init success!", .{});

    while (true) {
        interface.process();
        ble.process();
    }
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("PANIC: {s}", .{message});
    while (true) {}
}

pub fn log(comptime level: std.log.Level, comptime scope: @TypeOf(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    _ = scope;
    debug.print(switch (level) {
        .debug => "[D] ",
        .info => "[I] ",
        .err => "[E] ",
        .warn => "[W] ",
    });

    var buf: [256]u8 = undefined;
    _ = std.fmt.bufPrintZ(&buf, format, args) catch return;

    debug.print(&buf);
    debug.print("\r\n");

    for (0..1024) |_| {
        asm volatile ("nop");
    }
}

pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = log;
};

export fn _zigstart() noreturn {
    main();
}

export fn HardFault_Handler() noreturn {
    const mcause: usize = asm volatile ("csrr %[ret], mcause"
        : [ret] "={t0}" (-> usize),
    );

    const mepc: usize = asm volatile ("csrr %[ret], mepc"
        : [ret] "={t0}" (-> usize),
    );

    const mtval: usize = asm volatile ("csrr %[ret], mtval"
        : [ret] "={t0}" (-> usize),
    );

    std.log.err("MCAUSE: {}", .{mcause});
    std.log.err("MEPC: {}", .{mepc});
    std.log.err("MTVAL: {}", .{mtval});
    @panic("HARD FAULT");
}
