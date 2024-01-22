const std = @import("std");
const kirei = struct { // TODO: Yep. When we have a better build.zig.
    const TimeMillis = u16;
    const ScheduleToken = u8;
};

const max_token_count = std.math.maxInt(kirei.ScheduleToken) + 1;

const Self = @This();
const TaskArray = std.BoundedArray(Task, max_token_count);
const TokenSet = std.StaticBitSet(max_token_count);

const Task = struct {
    time_millis: u64,
    token: kirei.ScheduleToken,
};

pub const TaskCallback = *const fn (token: kirei.ScheduleToken) void;

tasks: TaskArray,
token_set: TokenSet,
task_callback: TaskCallback,

pub fn init(task_callback: TaskCallback) Self {
    return .{
        .tasks = TaskArray.init(0) catch unreachable,
        .token_set = TokenSet.initEmpty(),
        .task_callback = task_callback,
    };
}

pub fn process(self: *Self) void {
    const cur_time_millis = getTimeMillis();

    while (self.tasks.len > 0) {
        const next_task = self.tasks.get(0);

        if (next_task.time_millis > cur_time_millis)
            break;

        self.task_callback(next_task.token);
        self.cancel(next_task.token);
    }
}

pub fn getTimeMillis() u64 {
    return @intCast(std.time.milliTimestamp());
}

pub fn schedule(self: *Self, duration: kirei.TimeMillis, token: kirei.ScheduleToken) void {
    self.cancel(token);

    const time_millis = getTimeMillis() + duration;

    const idx = for (self.tasks.constSlice(), 0..) |task, i| {
        if (task.time_millis > time_millis)
            break i;
    } else self.tasks.len;

    self.tasks.insert(idx, .{
        .time_millis = time_millis,
        .token = token,
    }) catch unreachable;

    self.token_set.set(token);
}

pub fn cancel(self: *Self, token: kirei.ScheduleToken) void {
    if (!self.token_set.isSet(token))
        return;

    const idx = for (self.tasks.constSlice(), 0..) |task, i| {
        if (token == task.token)
            break i;
    } else unreachable;

    _ = self.tasks.orderedRemove(idx);
    self.token_set.unset(token);
}

// --- Tests ---

test {
    const expected_called_tokens = [_]kirei.ScheduleToken{ 1, 2, 3 };

    const host = struct {
        var called_tokens = std.ArrayList(kirei.ScheduleToken).init(std.testing.allocator);

        fn call(token: kirei.ScheduleToken) void {
            std.debug.print("called {}\n", .{token});
            called_tokens.append(token) catch unreachable;
        }
    };

    var scheduler = Self.init(host.call);
    scheduler.schedule(100, 1);
    scheduler.schedule(300, 3);
    scheduler.schedule(2000, 2);
    scheduler.schedule(400, 3);
    scheduler.schedule(9999, 5);
    scheduler.cancel(5);

    scheduler.process();
    std.time.sleep(150 * 1000 * 1000);
    scheduler.schedule(50, 2);

    while (host.called_tokens.items.len < expected_called_tokens.len) {
        scheduler.process();
    }

    try std.testing.expectEqualSlices(
        kirei.ScheduleToken,
        &expected_called_tokens,
        host.called_tokens.items,
    );

    host.called_tokens.deinit();
}
