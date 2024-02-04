const std = @import("std");
const kirei = @import("kirei");

const Token = kirei.ScheduleToken;
const Duration = kirei.TimeMillis;

pub fn SingleScheduler(
    comptime AbsoluteMillis: type,
    comptime implGetTime: *const fn () AbsoluteMillis,
    comptime implSchedule: *const fn (time: ?AbsoluteMillis) void,
    comptime implCallback: *const fn (token: Token) void,
) type {
    std.debug.assert(AbsoluteMillis == u32 or AbsoluteMillis == u64);

    return struct {
        tasks: TaskArray = TaskArray.init(0) catch unreachable,
        active_tokens: TokenSet = TokenSet.initEmpty(),

        const MAX_TOKEN_COUNT = std.math.maxInt(Token) + 1;

        const Self = @This();
        const TaskArray = std.BoundedArray(Task, MAX_TOKEN_COUNT);
        const TokenSet = std.StaticBitSet(MAX_TOKEN_COUNT);

        const Task = struct {
            time_millis: AbsoluteMillis,
            token: Token,
        };

        pub fn enqueue(self: *Self, duration: Duration, token: Token) void {
            self.cancel(token);

            const time_millis = implGetTime() + duration;

            const idx = for (self.tasks.constSlice(), 0..) |task, i| {
                if (task.time_millis > time_millis)
                    break i;
            } else self.tasks.len;

            self.tasks.insert(idx, .{
                .time_millis = time_millis,
                .token = token,
            }) catch @panic("schedins");

            self.active_tokens.set(token);

            if (idx == 0) {
                self.scheduleNextTask();
            }
        }

        pub fn cancel(self: *Self, token: Token) void {
            if (!self.active_tokens.isSet(token))
                return;

            const idx = for (self.tasks.constSlice(), 0..) |task, i| {
                if (token == task.token)
                    break i;
            } else unreachable;

            _ = self.tasks.orderedRemove(idx);
            self.active_tokens.unset(token);

            if (idx == 0) {
                if (self.tasks.len > 0) {
                    self.scheduleNextTask();
                } else {
                    implSchedule(null);
                }
            }
        }

        pub fn callScheduled(self: *Self) void {
            self.callAndRemoveCurrentTask();
            self.scheduleNextTask();
        }

        fn scheduleNextTask(self: *Self) void {
            const now = implGetTime();

            while (self.tasks.len > 0) {
                const task = self.tasks.get(0);

                if (now >= task.time_millis) {
                    self.callAndRemoveCurrentTask();
                } else {
                    implSchedule(task.time_millis);
                    break;
                }
            }
        }

        fn callAndRemoveCurrentTask(self: *Self) void {
            const task = self.tasks.get(0);
            implCallback(task.token);
            _ = self.tasks.orderedRemove(0);
            self.active_tokens.unset(task.token);
        }
    };
}

test {
    const expected_called_tokens = [_]Token{ 1, 2, 3 };

    const host = struct {
        var called_tokens = std.ArrayList(Token).init(std.testing.allocator);
        var scheduled_time: ?u64 = null;

        fn call(token: Token) void {
            std.debug.print("called {}\n", .{token});
            called_tokens.append(token) catch unreachable;
        }

        fn getTime() u64 {
            return @intCast(std.time.milliTimestamp());
        }

        fn schedule(time: ?u64) void {
            scheduled_time = time;
        }

        fn process() bool {
            if (scheduled_time) |t| {
                if (getTime() >= t) {
                    scheduled_time = null;
                    return true;
                }
            }
            return false;
        }
    };

    const Scheduler = SingleScheduler(u64, host.getTime, host.schedule, host.call);
    var scheduler = Scheduler{};
    defer scheduler.deinit();

    scheduler.enqueue(100, 1);
    scheduler.enqueue(300, 3);
    scheduler.enqueue(2000, 2);
    scheduler.enqueue(400, 3);
    scheduler.enqueue(9999, 5);
    scheduler.cancel(5);

    if (host.process()) scheduler.callScheduled();
    std.time.sleep(150 * 1000 * 1000);
    scheduler.enqueue(50, 2);

    while (host.called_tokens.items.len < expected_called_tokens.len) {
        if (host.process()) scheduler.callScheduled();
    }

    try std.testing.expectEqualSlices(
        Token,
        &expected_called_tokens,
        host.called_tokens.items,
    );

    host.called_tokens.deinit();
}
