const std = @import("std");
const assert = std.debug.assert;

// `input` is always assumed to be pull-down.
// If it's not pull-down, implementation must invert the value.
pub const GpioDirection = enum { input, output };

pub fn GpioImplementation(comptime PinEnum: type) type {
    return struct {
        config: *const fn (num: PinEnum, dir: GpioDirection) void,
        read: *const fn (num: PinEnum) bool,
        write: *const fn (num: PinEnum, value: bool) void,
        toggle: *const fn (num: PinEnum) void,
    };
}

pub fn Gpio(comptime PinEnum: type, comptime impl: GpioImplementation(PinEnum)) type {
    return struct {
        pub const Pin = struct {
            num: PinEnum,

            const Self = @This();

            pub fn config(self: Self, dir: GpioDirection) void {
                impl.config(self.num, dir);
            }

            pub fn read(self: Self) bool {
                return impl.read(self.num);
            }

            pub fn write(self: Self, value: bool) void {
                impl.write(self.num, value);
            }

            pub fn toggle(self: Self) void {
                impl.toggle(self.num);
            }
        };

        pub fn pin(num: PinEnum) Pin {
            return .{ .num = num };
        }
    };
}
