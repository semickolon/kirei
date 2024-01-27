const std = @import("std");
const kirei = @import("kirei");

const Scheduler = @import("scheduler.zig");

const HidReport = [8]u8;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var scheduler = Scheduler.init(callScheduled);

var engine: kirei.Engine = undefined;

pub const key_map align(4) = [_]u8{ 105, 250, 1, 0, 9, 0, 10, 0, 17, 0, 0, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 26, 0, 9, 0, 10, 0, 11, 0, 12, 0, 13, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 9, 0, 19, 0, 1, 0, 0, 0, 254, 127, 0, 0, 1, 167, 34, 0, 1, 0, 1, 0, 254, 127, 0, 0, 1, 167, 34, 0, 1, 0, 2, 0, 254, 127, 0, 0, 1, 167, 34, 0, 1, 0, 3, 0, 254, 127, 0, 0, 1, 167, 34, 0, 1, 0, 4, 0, 254, 127, 0, 0, 1, 167, 34, 0, 1, 0, 6, 0, 254, 127, 0, 0, 1, 16, 41, 0, 1, 0, 7, 0, 254, 127, 0, 0, 1, 16, 41, 0, 1, 0, 8, 0, 254, 127, 0, 0, 1, 16, 41, 0, 1, 0, 9, 0, 254, 127, 0, 0, 1, 16, 41, 0, 1, 0, 10, 0, 254, 127, 0, 0, 1, 16, 41, 0, 5, 0, 0, 0, 250, 0, 170, 170, 3, 1, 0, 0, 1, 0, 5, 0, 250, 0, 170, 170, 1, 1, 0, 0, 5, 0, 5, 0, 250, 0, 170, 170, 3, 1, 0, 0, 1, 0, 11, 0, 250, 0, 170, 170, 1, 1, 0, 0, 1, 0, 12, 0, 250, 0, 170, 170, 1, 1, 0, 0, 1, 0, 13, 0, 250, 0, 170, 170, 1, 1, 0, 0, 1, 0, 14, 0, 250, 0, 170, 170, 1, 1, 0, 0, 1, 0, 15, 0, 250, 0, 170, 170, 1, 1, 0, 0, 1, 0, 16, 0, 250, 0, 170, 170, 1, 1, 0, 0, 0, 0, 0, 0 };

fn onReportPush(report: *const HidReport) bool {
    std.log.debug("{any}", .{report.*});
    return true;
}

fn getTimeMillis() kirei.TimeMillis {
    const t: u64 = Scheduler.getTimeMillis();
    return @truncate(t % (std.math.maxInt(kirei.TimeMillis) + 1));
}

fn scheduleCall(duration: kirei.TimeMillis, token: kirei.ScheduleToken) void {
    scheduler.schedule(duration, token);
}

fn cancelCall(token: kirei.ScheduleToken) void {
    scheduler.cancel(token);
}

fn callScheduled(token: kirei.ScheduleToken) void {
    engine.callScheduled(token);
}

fn print(str: []const u8) void {
    _ = std.io.getStdOut().write(str) catch unreachable;
}

pub const Step = union(enum) {
    key: struct {
        key_idx: kirei.KeyIndex,
        down: bool,
    },
    wait: kirei.TimeMillis,

    fn k(key_idx: kirei.KeyIndex, down: bool) Step {
        return .{ .key = .{ .key_idx = key_idx, .down = down } };
    }

    fn w(duration: kirei.TimeMillis) Step {
        return .{ .wait = duration };
    }

    fn do(self: Step) ?u64 {
        switch (self) {
            .key => |ks| engine.pushKeyEvent(ks.key_idx, ks.down),
            .wait => |ms| return Scheduler.getTimeMillis() + ms,
        }
        return null;
    }
};

const steps = [_]Step{
    Step.k(4, true),
    Step.k(0, true),
    Step.w(175),
    Step.k(0, false),
    Step.w(100),
    Step.k(0, true),
    Step.k(0, false),
    Step.w(200),
    Step.k(0, true),
    Step.w(300),
    Step.k(0, false),
    Step.w(300),
    Step.k(1, true),
    Step.k(5, true),
    Step.k(1, false),
    Step.k(5, false),
};

fn process() void {
    scheduler.process();
    engine.process();
}

pub fn main() !void {
    engine = try kirei.Engine.init(
        .{
            .allocator = gpa.allocator(),
            .onReportPush = onReportPush,
            .getTimeMillis = getTimeMillis,
            .scheduleCall = scheduleCall,
            .cancelCall = cancelCall,
        },
        &key_map,
    );

    for (steps) |step| {
        process();

        if (step.do()) |wait_until| {
            while (Scheduler.getTimeMillis() < wait_until) {
                process();
            }
        }
    }

    process();
}
