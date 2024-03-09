const std = @import("std");
const kirei = @import("kirei");
const common = @import("common");

const interface = @import("interface.zig");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;

const Scheduler = common.SingleScheduler(u64, getTimeMillis, implSchedule, interface.callScheduled);

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
    return time.get_time_since_boot().to_us() / 1000;
}

pub fn enqueue(duration: kirei.Duration, token: kirei.ScheduleToken) void {
    scheduler.enqueue(duration, token);
}

pub fn cancel(token: kirei.ScheduleToken) void {
    scheduler.cancel(token);
}

fn implSchedule(t: ?u64) void {
    scheduled_time = t;
}
