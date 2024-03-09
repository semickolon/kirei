const std = @import("std");
const kirei = @import("kirei");

const scheduler = @import("scheduler.zig");

const @"test": Test = @import("test").@"test";

const HidReport = [8]u8;

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var engine: kirei.Engine = undefined;

fn onReportPush(report: *const HidReport) bool {
    std.log.debug("{any}", .{report.*});
    return true;
}

fn getKireiTimeMillis() kirei.TimeMillis {
    const t: u64 = scheduler.getTimeMillis();
    return @truncate(t % (std.math.maxInt(kirei.TimeMillis) + 1));
}

pub const Test = struct {
    key_map: kirei.KeyMap,
    steps: []const Step,
    expected: []const u8,
};

pub const Step = union(enum) {
    press: kirei.KeyIndex,
    release: kirei.KeyIndex,
    wait: kirei.Duration,

    fn k(key_idx: kirei.KeyIndex, down: bool) Step {
        return if (down)
            .{ .press = key_idx }
        else
            .{ .release = key_idx };
    }

    fn w(duration: kirei.Duration) Step {
        return .{ .wait = duration };
    }

    fn do(self: Step) ?u64 {
        switch (self) {
            .press => |key_idx| engine.pushKeyEvent(key_idx, true),
            .release => |key_idx| engine.pushKeyEvent(key_idx, false),
            .wait => |ms| return scheduler.getTimeMillis() + ms,
        }
        return null;
    }
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
        @"test".key_map,
    );

    for (@"test".steps) |step| {
        process();

        if (step.do()) |wait_until| {
            while (scheduler.getTimeMillis() < wait_until) {
                process();
            }
        }
    }

    process();
}
