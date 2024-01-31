const std = @import("std");
const kirei = @import("kirei");

const scheduler = @import("scheduler.zig");

const HidReport = [8]u8;

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var engine: kirei.Engine = undefined;

const keymap align(4) = @embedFile("keymap").*;

fn onReportPush(report: *const HidReport) bool {
    std.log.debug("{any}", .{report.*});
    return true;
}

fn getKireiTimeMillis() kirei.TimeMillis {
    const t: u64 = scheduler.getTimeMillis();
    return @truncate(t % (std.math.maxInt(kirei.TimeMillis) + 1));
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
            .wait => |ms| return scheduler.getTimeMillis() + ms,
        }
        return null;
    }
};

const steps = [_]Step{
    Step.k(0, true),
    Step.k(0, false),
    Step.w(300),
    Step.k(0, true),
    Step.w(100),
    Step.k(0, false),
    Step.w(100),
    Step.k(0, true),
    Step.w(300),
    Step.k(1, true),
    Step.k(1, false),
    Step.k(1, true),
    Step.w(250),
    // Step.k(1, false),
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
            .getTimeMillis = getKireiTimeMillis,
            .scheduleCall = scheduler.enqueue,
            .cancelCall = scheduler.cancel,
        },
        &keymap,
    );

    for (steps) |step| {
        process();

        if (step.do()) |wait_until| {
            while (scheduler.getTimeMillis() < wait_until) {
                process();
            }
        }
    }

    process();
}
