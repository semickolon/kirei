const std = @import("std");
const kirei = @import("kirei");

const Scheduler = @import("scheduler.zig");

const HidReport = [8]u8;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var scheduler = Scheduler.init(callScheduled);

var engine = kirei.Engine.init(.{
    .allocator = gpa.allocator(),
    .onReportPush = onReportPush,
    .getTimeMillis = getTimeMillis,
    .scheduleCall = scheduleCall,
    .cancelCall = cancelCall,
    .readKeymapBytes = readKeymapBytes,
    .print = print,
});

pub const key_map = [_]u8{
    0x69, 0xFA, 1,    0,
    9,    0,    0,    0,
    3,    2,    0xFA, 0x50,
    3,    0,    0x1A, 0,
    3,    0,    10,   0,
    3,    0,    0x15, 0,
    3,    0,    0x17, 0,
    3,    0,    0x1C, 0,
    3,    0,    0x18, 0,
    3,    0,    0x0C, 0,
    3,    0,    0xE1, 0,
};

fn onReportPush(report: *const HidReport) bool {
    std.debug.print("{any}\n", .{report.*});
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

fn readKeymapBytes(offset: usize, len: usize) []const u8 {
    return key_map[offset .. offset + len];
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
    Step.k(0, true),
    Step.w(175),
    Step.k(0, false),
    Step.w(100),
    Step.k(0, true),
    Step.k(0, false),
    Step.w(200),
    Step.k(0, true),
    Step.w(300),
};

fn process() void {
    scheduler.process();
    engine.process();
}

pub fn main() !void {
    engine.setup() catch unreachable;

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
