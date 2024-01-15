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

pub const KeyEvent = packed struct(u16) {
    key_idx: KeyIndex,
    down: bool,
};

pub const Interface = struct {
    handleKeycode: *const fn (keycode: u16, down: bool) void,
};

pub const Event = struct {
    data: Data,
    time: TimeMillis = 0,
    handled: bool = false,

    pub const Data = union(enum) {
        key: KeyEvent,
    };

    fn init(data: Data) Event {
        return Event{ .data = data };
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

fn processEvents() !void {
    var ev_idx: usize = 0;

    blk_ev: while (ev_idx < events.size) {
        const ev = events.at(ev_idx);
        var kd_idx: usize = 0;

        while (kd_idx < key_defs.size) {
            const key_def = key_defs.at(kd_idx);
            const result = key_def.process(&interface, ev);

            switch (result) {
                .pass => {},
                .block => {},
                .transform => |next| key_def.* = next,
                .complete => _ = key_defs.remove(kd_idx),
            }

            if (ev.isHandled()) {
                _ = events.remove(ev_idx);
                continue :blk_ev;
            }

            switch (result) {
                .pass => kd_idx += 1,
                .block => continue :blk_ev,
                .transform => {},
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
        }

        _ = events.remove(ev_idx);
    }
}

fn handleKeycode(keycode: u16, down: bool) void {
    output.pushHidEvent(@truncate(keycode), down) catch unreachable;
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
