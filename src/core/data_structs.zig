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
            if (self.size == 0) {
                return null;
            }

            const elem = self.array[0];
            @memcpy(self.array[0 .. self.size - 1], self.array[1..self.size]);
            self.size -= 1;

            return elem;
        }

        pub fn isEmpty(self: Self) bool {
            return self.size != 0;
        }
    };
}
