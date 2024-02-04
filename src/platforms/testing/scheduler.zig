const std = @import("std");
const kirei = @import("kirei");
const main = @import("main.zig");

const Scheduler = @import("common").SingleScheduler(u64, getTimeMillis, implSchedule, implCallback);

var scheduler = Scheduler{};
var scheduled_time: ?u64 = null;

pub fn process() void {
    if (scheduled_time) |t| {
        if (t <= getTimeMillis()) {
            scheduled_time = null;
            scheduler.callScheduled();
        }
    }
}

pub fn getTimeMillis() u64 {
    return @intCast(std.time.milliTimestamp());
}

pub fn enqueue(duration: kirei.TimeMillis, token: kirei.ScheduleToken) void {
    scheduler.enqueue(duration, token);
}

pub fn cancel(token: kirei.ScheduleToken) void {
    scheduler.cancel(token);
}

fn implSchedule(time: ?u64) void {
    scheduled_time = time;
}

fn implCallback(token: u8) void {
    main.engine.callScheduled(token);
}
