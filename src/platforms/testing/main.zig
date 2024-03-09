const std = @import("std");
const kirei = @import("kirei");

const scheduler = @import("scheduler.zig");

const @"test": Test = @import("test").@"test";

const HidReport = [8]u8;

pub const Test = struct {
    key_map: kirei.KeyMap,
    steps: []const Step,
    expected: []const HidEvent,
};

pub const HidEvent = union(enum) {
    pressed: u8,
    released: u8,
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
var last_report = std.mem.zeroes(HidReport);
var expected_event_idx: usize = 0;

const allocator = gpa.allocator();

fn onReportPush(report: *const HidReport) bool {
    var events = std.ArrayList(HidEvent).init(allocator);
    defer events.deinit();

    deriveHidEvents(last_report, report.*, &events) catch unreachable;

    for (events.items) |event| {
        std.log.debug("{any}", .{event});

        if (expected_event_idx >= @"test".expected.len) {
            @panic("Not enough expected events.");
        }

        const expected_event = @"test".expected[expected_event_idx];

        if (!std.meta.eql(expected_event, event)) {
            std.log.err("Expected {any}, got {any} at index {d}.", .{
                expected_event,
                event,
                expected_event_idx,
            });
            @panic("Test failed.");
        }

        expected_event_idx += 1;
    }

    last_report = report.*;
    return true;
}

fn deriveHidEvents(
    old_report: HidReport,
    new_report: HidReport,
    events: *std.ArrayList(HidEvent),
) !void {
    if (old_report[0] != new_report[0]) {
        const changed_mods = old_report[0] ^ new_report[0];

        for (0..8) |i| {
            const mask = @as(u8, 1) << @intCast(i);

            if ((changed_mods & mask) != 0) {
                const pressed = (new_report[0] & mask) != 0;
                const usage_id: u8 = 0xE0 + @as(u8, @intCast(i));

                const event: HidEvent = if (pressed)
                    .{ .pressed = usage_id }
                else
                    .{ .released = usage_id };

                try events.append(event);
            }
        }
    }

    outer: for (old_report[2..]) |old_code| {
        if (old_code == 0)
            continue;

        for (new_report[2..]) |new_code| {
            if (old_code == new_code)
                continue :outer; // No change
        }

        try events.append(.{ .released = old_code });
    }

    outer: for (new_report[2..]) |new_code| {
        if (new_code == 0)
            continue;

        for (old_report[2..]) |old_code| {
            if (old_code == new_code)
                continue :outer; // No change
        }

        try events.append(.{ .pressed = new_code });
    }
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
    engine = try kirei.Engine.init(
        .{
            .allocator = allocator,
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
    std.log.debug("PASS", .{});
}
