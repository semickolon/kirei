const std = @import("std");

const tmos = @import("tmos.zig");
const rtc = @import("../hal/rtc.zig");
const Duration = @import("../duration.zig").Duration;

const kirei = @import("kirei");
const interface = @import("../interface.zig");

const max_token_count = std.math.maxInt(kirei.ScheduleToken) + 1;

const blueprint = tmos.TaskBlueprint{
    .Event = enum(u4) { call_0 },
    .events_callback = &.{tmosEvtCall0},
};
var tmos_task: ?tmos.Task(blueprint.Event) = null;

var task_tokens = std.BoundedArray(kirei.ScheduleToken, max_token_count).init(0) catch unreachable;
var task_time_millis = std.BoundedArray(u32, max_token_count).init(0) catch unreachable;
var active_tokens = std.StaticBitSet(max_token_count).initEmpty();

pub fn scheduleCall(duration: kirei.TimeMillis, token: kirei.ScheduleToken) void {
    cancelCall(token);

    const time_millis = rtc.getTimeMillis() + duration;
    if (time_millis >= rtc.MAX_CYCLE_32K) {
        return; // TODO: Handle case
    }

    const idx = for (task_time_millis.constSlice(), 0..) |other_time_millis, i| {
        if (other_time_millis > time_millis)
            break i;
    } else task_time_millis.len;

    task_time_millis.insert(idx, time_millis) catch unreachable;
    task_tokens.insert(idx, token) catch unreachable;
    active_tokens.set(token);

    if (idx == 0) {
        scheduleNext();
    }
}

pub fn cancelCall(token: kirei.ScheduleToken) void {
    if (!active_tokens.isSet(token))
        return;

    for (task_tokens.constSlice(), 0..) |t, i| {
        if (token != t)
            continue;

        _ = task_tokens.orderedRemove(i);
        _ = task_time_millis.orderedRemove(i);
        active_tokens.unset(token);
        return;
    }

    unreachable;
}

fn scheduleNext() void {
    if (task_tokens.len == 0)
        return;

    if (tmos_task == null)
        tmos_task = tmos.register(blueprint);

    const duration_ms = task_time_millis.get(0) -| rtc.getTimeMillis();

    if (duration_ms > 0) {
        tmos_task.?.scheduleEvent(.call_0, Duration.fromMillis(@truncate(duration_ms)));
    } else {
        tmosEvtCall0();
    }
}

fn tmosEvtCall0() void {
    const token = task_tokens.get(0);
    interface.callScheduled(token);
    cancelCall(token);
    scheduleNext();
}
