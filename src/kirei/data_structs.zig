const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn Queue(comptime T: type, comptime capacity: comptime_int) type {
    return struct {
        size: usize = 0,
        array: [capacity]T = undefined,

        const Self = @This();

        pub fn init() Self {
            return .{};
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

        pub fn peek(self: *Self) ?*T {
            return if (self.size == 0)
                null
            else
                &self.array[0];
        }

        pub fn isEmpty(self: Self) bool {
            return self.size == 0;
        }
    };
}

pub fn List(comptime T: type, comptime capacity: comptime_int) type {
    return struct {
        size: usize = 0,
        array: [capacity]T = undefined,

        const Self = @This();

        pub fn init() Self {
            return .{};
        }

        pub fn asSlice(self: *Self) []T {
            return self.array[0..self.size];
        }

        pub fn pushFront(self: *Self, elem: T) !void {
            try self.insert(0, elem);
        }

        pub fn pushBack(self: *Self, elem: T) !void {
            try self.insert(self.size, elem);
        }

        pub fn insert(self: *Self, idx: usize, elem: T) !void {
            if (self.size == capacity)
                return error.Overflow;
            if (idx > self.size)
                return error.InvalidIndex;

            if (idx < self.size) {
                std.mem.copyBackwards(T, self.array[idx + 1 .. self.size + 1], self.array[idx..self.size]);
            }

            self.array[idx] = elem;
            self.size += 1;
        }

        pub fn remove(self: *Self, idx: usize) T {
            const elem = self.array[idx];

            if (idx < self.size - 1) { // Not the last element
                std.mem.copyForwards(T, self.array[idx..self.size], self.array[idx + 1 .. self.size + 1]);
            }

            self.size -= 1;
            return elem;
        }

        pub fn at(self: *Self, idx: usize) *T {
            return &self.array[idx];
        }

        pub fn atOrNull(self: *Self, idx: usize) ?*T {
            return if (idx < self.size) &self.array[idx] else null;
        }

        pub fn first(self: *Self) ?*T {
            return self.atOrNull(0);
        }

        pub fn last(self: *Self) ?*T {
            return if (self.size > 0) self.array[self.size - 1] else null;
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

test {
    var q = List(u8, 16).init();
    try expect(q.isEmpty());
    try q.pushFront(100);
    try q.pushBack(70);
    try q.pushFront(32);
    try q.pushBack(11);
    try q.pushBack(69);

    try expectEqual(q.size, 5);
    try expectEqual(q.at(0).*, 32);
    try expectEqual(q.at(1).*, 100);
    try expectEqual(q.at(2).*, 70);
    try expectEqual(q.at(3).*, 11);
    try expectEqual(q.at(4).*, 69);

    _ = q.remove(1);
    try expectEqual(q.size, 4);
    try expectEqual(q.at(0).*, 32);
    try expectEqual(q.at(1).*, 70);
    try expectEqual(q.at(2).*, 11);
    try expectEqual(q.at(3).*, 69);

    _ = q.remove(3);
    try expectEqual(q.size, 3);
    try expectEqual(q.at(0).*, 32);
    try expectEqual(q.at(1).*, 70);
    try expectEqual(q.at(2).*, 11);

    _ = q.remove(0);
    _ = q.remove(1);
    try expectEqual(q.size, 1);
    try expectEqual(q.at(0).*, 70);

    _ = q.remove(0);
    try expect(q.isEmpty());
}
