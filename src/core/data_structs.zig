const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn Queue(comptime T: type, comptime capacity: comptime_int) type {
    return struct {
        size: usize,
        array: [capacity]T,

        const Self = @This();

        pub fn init() Self {
            return .{
                .size = 0,
                .array = undefined,
            };
        }

        pub fn push(self: *Self, elem: T) !void {
            if (self.size >= capacity) {
                return error.QueueOverflow;
            }

            self.array[self.size] = elem;
            self.size += 1;
        }

        pub fn pop(self: *Self) ?T {
            if (self.size == 0)
                return null;

            const elem = self.array[0];

            for (0..@min(self.size, capacity - 1)) |i| {
                self.array[i] = self.array[i + 1];
            }

            self.size -= 1;
            return elem;
        }

        pub fn isEmpty(self: Self) bool {
            return self.size == 0;
        }
    };
}

test {
    var q = Queue(u8, 4).init();
    try expect(q.isEmpty());
    try expect(q.pop() == null);

    try q.push(2);
    try q.push(3);
    try q.push(4);
    try q.push(5);
    try expect(q.size == 4);
    try expectEqual(q.array, [_]u8{ 2, 3, 4, 5 });

    try expect(q.pop() == 2);
    try expect(q.pop() == 3);
    try expect(q.size == 2);
    try expect(q.pop() == 4);
    try expect(q.pop() == 5);
    try expect(q.pop() == null);
}
