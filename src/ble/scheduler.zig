const tmos = @import("tmos.zig");
const rtc = @import("../hal/rtc.zig");
const Duration = @import("../duration.zig").Duration;
const engine = @import("../core/engine.zig");

const blueprint = tmos.TaskBlueprint{
    .Event = enum(u4) {
        call_0,
        call_1,
        call_2,
        call_3,
    },
    .events_callback = &.{
        tmosEvtCall0,
        tmosEvtCall1,
        tmosEvtCall2,
        tmosEvtCall3,
    },
};
var tmos_task: ?tmos.Task(blueprint.Event) = null;

var token: u8 = 0;

pub fn scheduleCallForEngine(duration_ms: engine.TimeMillis) engine.ScheduleToken {
    if (tmos_task == null) {
        tmos_task = tmos.register(blueprint);
    }

    const task = tmos_task.?;
    const duration = Duration.fromMillis(duration_ms);

    switch (token) {
        0 => task.scheduleEvent(.call_0, duration),
        1 => task.scheduleEvent(.call_1, duration),
        2 => task.scheduleEvent(.call_2, duration),
        3 => task.scheduleEvent(.call_3, duration),
        else => unreachable,
    }

    defer token = (token + 1) % 4;
    return token;
}

fn onCall(idx: u2) void {
    engine.callScheduled(idx);
}

fn tmosEvtCall0() void {
    onCall(0);
}

fn tmosEvtCall1() void {
    onCall(1);
}

fn tmosEvtCall2() void {
    onCall(2);
}

fn tmosEvtCall3() void {
    onCall(3);
}
