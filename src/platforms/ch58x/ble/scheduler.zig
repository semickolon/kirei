const tmos = @import("tmos.zig");
const rtc = @import("../hal/rtc.zig");
const Duration = @import("../duration.zig").Duration;

const kirei = @import("kirei");
const interface = @import("../interface.zig");

const blueprint = tmos.TaskBlueprint{
    .Event = enum(u4) {
        call_0,
        call_1,
        call_2,
        call_3,
        call_4,
        call_5,
        call_6,
        call_7,
        call_8,
        call_9,
        call_10,
        call_11,
        call_12,
        call_13,
        call_14,
    },
    .events_callback = &.{
        tmosEvtCall0,
        tmosEvtCall1,
        tmosEvtCall2,
        tmosEvtCall3,
        tmosEvtCall4,
        tmosEvtCall5,
        tmosEvtCall6,
        tmosEvtCall7,
        tmosEvtCall8,
        tmosEvtCall9,
        tmosEvtCall10,
        tmosEvtCall11,
        tmosEvtCall12,
        tmosEvtCall13,
        tmosEvtCall14,
    },
};
var tmos_task: ?tmos.Task(blueprint.Event) = null;

pub fn scheduleCall(duration_ms: kirei.TimeMillis, token: kirei.ScheduleToken) void {
    if (tmos_task == null) {
        tmos_task = tmos.register(blueprint);
    }

    const task = tmos_task.?;
    const duration = Duration.fromMillis(duration_ms);

    switch (token % 15) {
        0 => task.scheduleEvent(.call_0, duration),
        1 => task.scheduleEvent(.call_1, duration),
        2 => task.scheduleEvent(.call_2, duration),
        3 => task.scheduleEvent(.call_3, duration),
        4 => task.scheduleEvent(.call_4, duration),
        5 => task.scheduleEvent(.call_5, duration),
        6 => task.scheduleEvent(.call_6, duration),
        7 => task.scheduleEvent(.call_7, duration),
        8 => task.scheduleEvent(.call_8, duration),
        9 => task.scheduleEvent(.call_9, duration),
        10 => task.scheduleEvent(.call_10, duration),
        11 => task.scheduleEvent(.call_11, duration),
        12 => task.scheduleEvent(.call_12, duration),
        13 => task.scheduleEvent(.call_13, duration),
        14 => task.scheduleEvent(.call_14, duration),
        else => unreachable,
    }
}

pub fn cancelCall(token: kirei.ScheduleToken) void {
    const task = tmos_task.?;
    switch (token % 15) {
        0 => task.cancelEvent(.call_0),
        1 => task.cancelEvent(.call_1),
        2 => task.cancelEvent(.call_2),
        3 => task.cancelEvent(.call_3),
        4 => task.cancelEvent(.call_4),
        5 => task.cancelEvent(.call_5),
        6 => task.cancelEvent(.call_6),
        7 => task.cancelEvent(.call_7),
        8 => task.cancelEvent(.call_8),
        9 => task.cancelEvent(.call_9),
        10 => task.cancelEvent(.call_10),
        11 => task.cancelEvent(.call_11),
        12 => task.cancelEvent(.call_12),
        13 => task.cancelEvent(.call_13),
        14 => task.cancelEvent(.call_14),
        else => unreachable,
    }
}

fn onCall(idx: kirei.ScheduleToken) void {
    interface.callScheduled(idx);
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

fn tmosEvtCall4() void {
    onCall(4);
}

fn tmosEvtCall5() void {
    onCall(5);
}

fn tmosEvtCall6() void {
    onCall(6);
}

fn tmosEvtCall7() void {
    onCall(7);
}

fn tmosEvtCall8() void {
    onCall(8);
}

fn tmosEvtCall9() void {
    onCall(9);
}

fn tmosEvtCall10() void {
    onCall(10);
}

fn tmosEvtCall11() void {
    onCall(11);
}

fn tmosEvtCall12() void {
    onCall(12);
}

fn tmosEvtCall13() void {
    onCall(13);
}

fn tmosEvtCall14() void {
    onCall(14);
}
