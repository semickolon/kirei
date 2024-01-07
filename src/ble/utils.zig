const std = @import("std");
const config = @import("../config.zig");

fn sizeOfBleData(comptime ptr: anytype) comptime_int {
    // TODO: Only the `name` string gets its null terminator excluded.
    // Other strings won't receive this treatment.
    return if (@TypeOf(ptr) == @TypeOf(config.ble.name) and ptr == config.ble.name)
        return config.ble.name.len
    else
        return @sizeOf(@TypeOf(ptr.*));
}

fn bleDataBytesLen(comptime tuple: anytype) comptime_int {
    if (tuple.len == 0)
        @compileError("Tuple cannot be empty.");
    if (tuple.len % 2 != 0)
        @compileError("Tuple must be of even length.");

    var len = tuple.len; // Two bytes each entry for length and type

    for (tuple, 0..) |v, i| {
        if (i % 2 == 0) continue;
        len += sizeOfBleData(v);
    }

    return len;
}

pub fn bleDataBytes(comptime tuple: anytype) [bleDataBytesLen(tuple)]u8 {
    const len = bleDataBytesLen(tuple);
    var bytes: [len]u8 = undefined;
    var k = 0;

    for (tuple, 0..) |v, i| {
        const is_data = i % 2 == 1;
        const data_size = sizeOfBleData(if (is_data) v else tuple[i + 1]);

        if (!is_data) {
            bytes[k] = 1 + data_size;
            bytes[k + 1] = v;
            k += 2;
        } else {
            @memcpy(bytes[k..(k + data_size)], std.mem.toBytes(v.*)[0..data_size]);
            k += data_size;
        }
    }

    if (k != len) {
        @compileError("Size mismatch.");
    }

    return bytes;
}
