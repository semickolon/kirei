const std = @import("std");

const Queue = @import("data_structs.zig").Queue;
const List = @import("data_structs.zig").List;

const config = @import("../config.zig");
const output = @import("output_hid.zig");

const keymap = @import("keymap.zig");
const KeyDef = keymap.KeyDef;

const KEY_EVENT_QUEUE_CAPACITY = config.engine.key_event_queue_size;
const KEY_COUNT = config.engine.key_map.len;

pub const KeyIndex = u15;
pub const TimeMillis = u16;
pub const ScheduleToken = u8;

pub const KeyEvent = packed struct(u16) {
    key_idx: KeyIndex,
    down: bool,
};

pub const TimeEvent = packed struct {
    token: ScheduleToken,
};

pub const Interface = struct {
    handleKeycode: *const fn (keycode: u16, down: bool) void,
    scheduleTimeEvent: *const fn (duration: TimeMillis) ScheduleToken,
};

var event_id_counter: Event.Id = 0;

pub const Event = struct {
    id: Id,
    data: Data,
    time: TimeMillis = 0,
    handled: bool = false,

    pub const Id = u32; // TODO: Can we make this smaller? How do we handle overflow?

    pub const Data = union(enum) {
        key: KeyEvent,
        time: TimeEvent,
    };

    fn init(data: Data) Event {
        event_id_counter +%= 1;
        return Event{
            .id = event_id_counter,
            .data = data,
            .time = getTimeMillis(),
        };
    }

    pub fn markHandled(self: *Event) void {
        self.handled = true;
    }

    pub fn isHandled(self: Event) bool {
        return self.handled;
    }
};

pub const ProcessResult = union(enum) {
    pass: void,
    block: void,
    complete: void,
    transform: KeyDef,
};

const interface = Interface{
    .handleKeycode = handleKeycode,
    .scheduleTimeEvent = scheduleTimeEvent,
};

var key_event_queue = Queue(KeyEvent, KEY_EVENT_QUEUE_CAPACITY).init();
var key_defs = List(KeyDef, 32).init();
var events = List(Event, 32).init();

const key_map = config.engine.key_map;
const callbacks = config.engine.callbacks;

pub fn process() void {
    processEvents() catch unreachable;
    output.sendReports();
}

var ev_idx: usize = 0;

fn processEvents() !void {
    blk_ev: while (ev_idx < events.size) {
        const ev = events.at(ev_idx);
        var kd_idx: usize = 0;

        while (kd_idx < key_defs.size) {
            const key_def = key_defs.at(kd_idx);

            if (ev.id <= key_def.last_processed_event_id) {
                kd_idx += 1;
                continue;
            }

            const result = key_def.process(&interface, ev);
            const is_ev_handled = ev.isHandled();

            if (is_ev_handled) {
                _ = events.remove(ev_idx);
            }

            switch (result) {
                .pass => {},
                .block => {},
                .transform => |next| {
                    key_def.* = next;
                    ev_idx = 0;
                },
                .complete => {
                    _ = key_defs.remove(kd_idx);
                },
            }

            if (is_ev_handled) {
                continue :blk_ev;
            }

            switch (result) {
                .pass => kd_idx += 1,
                .block => {
                    ev_idx += 1;
                    continue :blk_ev;
                },
                .transform => continue :blk_ev,
                .complete => {},
            }
        }

        // At this point, event is NOT handled. Try salvaging it. Otherwise, sayonara.
        switch (ev.data) {
            .key => |key_ev| if (key_ev.down) {
                const key_def = keymap.Keymap.parseKeydef(key_ev.key_idx);
                try key_defs.pushBack(key_def);
                continue :blk_ev;
            },
            else => {},
        }

        _ = events.remove(ev_idx);
    }
}

fn handleKeycode(keycode: u16, down: bool) void {
    output.pushHidEvent(@truncate(keycode), down) catch unreachable;
}

fn scheduleTimeEvent(duration: TimeMillis) ScheduleToken {
    return config.engine.functions.scheduleCall(duration);
}

fn getTimeMillis() TimeMillis {
    return config.engine.functions.getTimeMillis();
}

pub fn callScheduled(token: u8) void {
    const time_ev = Event.init(.{ .time = .{ .token = token } });
    events.pushBack(time_ev) catch unreachable;
}

// Caller must guarantee that all key events are "toggles"
// That is, caller must not report the same values of `down` consecutively (e.g. true->true, false->false)
// That would be undefined behavior
pub fn pushKeyEvent(key_idx: KeyIndex, down: bool) void {
    events.pushBack(Event.init(.{
        .key = .{
            .key_idx = key_idx,
            .down = down,
        },
    })) catch unreachable;
}
