const c = @import("../lib/ch583.zig");

const Duration = @import("../duration.zig").Duration;

pub const TaskId = c.tmosTaskID;

pub const SYSTEM_TIME_US: u32 = c.SYSTEM_TIME_MICROSEN;

pub const TaskBlueprint = struct {
    sys_event_callback: ?*const fn (*anyopaque) void = null,
    Event: type,
    events_callback: []const *const fn () void,

    fn validate(comptime self: TaskBlueprint) void {
        if (self.events_callback.len == 0 or self.events_callback.len > 15) {
            @compileError("Invalid amount of event callbacks.");
        }

        switch (@typeInfo(self.Event)) {
            .Enum => |e| {
                inline for (e.fields) |field| {
                    if (field.value == 15)
                        @compileError("Cannot take up reserved system event 15.");
                }

                if (e.tag_type != u4)
                    @compileError("Event enum tag must be u4.");

                if (e.fields.len != self.events_callback.len)
                    @compileError("Event enum field count doesn't match event callbacks count.");
            },
            else => @compileError("Expecting enum, got tomfoolery."),
        }
    }
};

pub fn Task(comptime EventEnum: type) type {
    return struct {
        id: TaskId,

        const Self = @This();
        pub const Event = EventEnum;

        pub fn scheduleEvent(self: Self, comptime event: Event, duration: Duration) void {
            _ = c.tmos_start_task(self.id, eventToNative(event), asTmosTime(duration));
        }

        pub fn setEvent(self: Self, comptime event: Event) void {
            _ = c.tmos_set_event(self.id, eventToNative(event));
        }

        fn eventToNative(comptime event: Event) u16 {
            return @as(u16, 1) << @intFromEnum(event);
        }
    };
}

pub fn init() !void {
    const err = c.TMOS_TimerInit(null);
    if (err == c.FAILURE) {
        return error.Failure;
    }
}

pub fn register(comptime blueprint: TaskBlueprint) Task(blueprint.Event) {
    blueprint.validate();

    const handler = struct {
        pub fn process(task_id: TaskId, events: u16) callconv(.C) u16 {
            if (events & c.SYS_EVENT_MSG != 0) {
                const msg = c.tmos_msg_receive(task_id);

                if (@intFromPtr(msg) != 0) {
                    if (blueprint.sys_event_callback) |cb| {
                        cb(@ptrCast(msg));
                    }

                    _ = c.tmos_msg_deallocate(msg);
                }

                return @intCast(events ^ c.SYS_EVENT_MSG);
            }

            inline for (blueprint.events_callback, 0..) |func, i| {
                const value: u4 = switch (@typeInfo(blueprint.Event)) {
                    .Enum => |e| e.fields[i].value,
                    else => unreachable,
                };

                if (events & (1 << value) != 0) {
                    func();
                    return events ^ (1 << value);
                }
            }

            return events;
        }
    };

    return .{ .id = c.TMOS_ProcessEventRegister(handler.process) };
}

pub fn asTmosTime(duration: Duration) c.tmosTimer {
    return duration.micros / SYSTEM_TIME_US;
}
