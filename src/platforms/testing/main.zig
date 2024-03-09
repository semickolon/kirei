const std = @import("std");
const kirei = @import("kirei");

const scheduler = @import("scheduler.zig");

const test_suite: TestSuite = @import("test").test_suite;

const HidReport = [8]u8;

pub const TestSuite = struct {
    key_map: kirei.KeyMap,
    tests: []const Test,
};

pub const Test = struct {
    name: []const u8,
    steps: []const Step,
    expected: []const ExpectedHidReport,
};

pub const ExpectedHidReport = struct {
    mods: u8,
    codes: []const u8,

    fn matches(self: ExpectedHidReport, actual: HidReport) bool {
        if (self.mods != actual[0])
            return false;

        const actual_codes = blk: {
            var list = std.ArrayList(u8).init(allocator);
            for (actual[2..]) |code| {
                if (code != 0)
                    list.append(code) catch unreachable;
            }
            break :blk list.toOwnedSlice() catch unreachable;
        };

        if (self.codes.len != actual_codes.len)
            return false;

        if (self.codes.len == 0)
            return true;

        const codes: []u8 = allocator.alloc(u8, self.codes.len) catch unreachable;
        defer allocator.free(codes);
        @memcpy(codes, self.codes);

        std.sort.insertion(u8, codes, {}, std.sort.asc(u8));
        std.sort.insertion(u8, actual_codes, {}, std.sort.asc(u8));

        for (0..codes.len) |i| {
            if (codes[i] != actual_codes[i])
                return false;
        }

        return true;
    }
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

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var engine: kirei.Engine = undefined;

var test_idx: usize = 0;
var expected_report_idx: usize = 0;

const allocator = gpa.allocator();

fn onReportPush(report: *const HidReport) bool {
    std.log.debug("{any}", .{report.*});

    const @"test" = &test_suite.tests[test_idx];

    if (expected_report_idx >= @"test".expected.len) {
        @panic("Not enough expected reports.");
    }

    const expected = @"test".expected[expected_report_idx];

    if (!expected.matches(report.*)) {
        std.log.err("Expected {any}, got {any} at index {d}.", .{
            expected,
            report.*,
            expected_report_idx,
        });
        @panic("Test failed.");
    }

    expected_report_idx += 1;
    return true;
}

fn getKireiTimeMillis() kirei.TimeMillis {
    const t: u64 = scheduler.getTimeMillis();
    return @truncate(t % (std.math.maxInt(kirei.TimeMillis) + 1));
}

fn process() void {
    scheduler.process();
    engine.process();
}

pub fn main() !void {
    for (test_suite.tests, 0..) |@"test", i| {
        std.log.info("{s}", .{@"test".name});
        scheduler.reset();

        test_idx = i;
        expected_report_idx = 0;

        engine = try kirei.Engine.init(
            .{
                .allocator = allocator,
                .onReportPush = onReportPush,
                .getTimeMillis = getKireiTimeMillis,
                .scheduleCall = scheduler.enqueue,
                .cancelCall = scheduler.cancel,
            },
            test_suite.key_map,
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
        std.log.info("PASS", .{});
    }
}
