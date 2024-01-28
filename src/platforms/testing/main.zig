const std = @import("std");
const kirei = @import("kirei");

const Scheduler = @import("scheduler.zig");

const HidReport = [8]u8;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var scheduler = Scheduler.init(callScheduled);

var engine: kirei.Engine = undefined;

pub const keymap align(4) = @embedFile("keymap").*;

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
        &keymap,
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
