const std = @import("std");
const kirei = @import("kirei");
const common = @import("common");

const tmos = @import("tmos.zig");
const rtc = @import("../hal/rtc.zig");
const interface = @import("../interface.zig");

const Duration = @import("../duration.zig").Duration;
const Scheduler = common.SingleScheduler(u32, rtc.getTimeMillis, implSchedule, interface.callScheduled);

const blueprint = tmos.TaskBlueprint{
    .Event = enum(u4) { call_0 },
    .events_callback = &.{tmosEvtCall0},
};
var tmos_task: tmos.Task(blueprint.Event) = undefined;

var scheduler = Scheduler{};

fn implSchedule(time: ?u32) void {
    if (time) |t| {
        const duration_ms = t -| rtc.getTimeMillis();
        tmos_task.scheduleEvent(.call_0, Duration.fromMillis(@truncate(duration_ms)));
    } else {
        tmos_task.cancelEvent(.call_0);
    }
}

fn tmosEvtCall0() void {
    scheduler.callScheduled();
}

pub fn enqueue(duration: kirei.Duration, token: kirei.ScheduleToken) void {
    scheduler.enqueue(duration, token);
}

pub fn cancel(token: kirei.ScheduleToken) void {
    scheduler.cancel(token);
}
