const std = @import("std");

const Queue = @import("data_structs.zig").Queue;
const List = @import("data_structs.zig").List;

const config = @import("config.zig");
const output = @import("output_hid.zig");

const keymap = @import("keymap.zig");
const KeyDef = keymap.KeyDef;

const KEY_EVENT_QUEUE_CAPACITY = config.key_event_queue_size;
const KEY_COUNT = config.key_map.len;

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
    toggleLed: *const fn () void,
};

pub const Event = struct {
    data: Data,
    time: TimeMillis = 0,
    handled: bool = false,
    kd_idx: usize = 0,
    blocked: bool = false,

    pub const Data = union(enum) {
        key: KeyEvent,
        time: TimeEvent,
    };

    fn init(data: Data, time: TimeMillis) Event {
        return Event{
            .data = data,
            .time = time,
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

pub const Implementation = struct {
    onReportPush: *const fn (report: *const output.HidReport) bool,
    getTimeMillis: *const fn () TimeMillis,
    scheduleCall: *const fn (duration: TimeMillis) ScheduleToken,
    toggleLed: *const fn () void,
};

pub fn Engine(comptime impl: Implementation) type {
    return struct {
        key_event_queue: Queue(KeyEvent, KEY_EVENT_QUEUE_CAPACITY) = Queue(KeyEvent, KEY_EVENT_QUEUE_CAPACITY).init(),
        key_defs: List(KeyDef, 32) = List(KeyDef, 32).init(),
        events: List(Event, 32) = List(Event, 32).init(),
        ev_idx: usize = 0,

        const Self = @This();

        const key_map = config.key_map;
        const callbacks = config.callbacks;

        const interface = Interface{
            .handleKeycode = handleKeycode,
            .scheduleTimeEvent = scheduleTimeEvent,
            .toggleLed = impl.toggleLed,
        };

        pub fn process(self: *Self) void {
            self.processEvents() catch unreachable;
            output.sendReports(impl);
        }

        fn pushEvent(self: *Self, data: Event.Data) void {
            self.events.pushBack(Event.init(data, getTimeMillis())) catch unreachable;
        }

        fn processEvents(self: *Self) !void {
            blk_ev: while (self.ev_idx < self.events.size) {
                const ev = self.events.at(self.ev_idx);

                if (ev.blocked) {
                    unreachable;
                }

                var kd_idx: usize = ev.kd_idx;

                while (kd_idx < self.key_defs.size) {
                    const key_def = self.key_defs.at(kd_idx);
                    const result = key_def.process(&interface, ev);
                    const is_ev_handled = ev.isHandled();

                    if (is_ev_handled) {
                        _ = self.events.remove(self.ev_idx);
                    }

                    switch (result) {
                        .pass => {},
                        .block => {},
                        .transform => |next| {
                            key_def.* = next;

                            var first_ev_idx: ?usize = null;

                            for (self.events.array[0..self.events.size], 0..) |*event, i| {
                                if (event.kd_idx == kd_idx and event.blocked) {
                                    event.blocked = false;

                                    if (first_ev_idx == null)
                                        first_ev_idx = i;
                                }
                            }

                            if (first_ev_idx) |i| {
                                self.ev_idx = i;
                                continue :blk_ev;
                            }
                        },
                        .complete => {
                            var first_ev_idx: ?usize = null;

                            for (self.events.array[0..self.events.size], 0..) |*event, i| {
                                if (event.kd_idx == kd_idx and event.blocked) {
                                    event.blocked = false;

                                    if (first_ev_idx == null)
                                        first_ev_idx = i;
                                }
                            }

                            for (self.events.array[0..self.events.size]) |*event| {
                                if (event.kd_idx > kd_idx)
                                    event.kd_idx -= 1;
                            }

                            _ = self.key_defs.remove(kd_idx);

                            if (first_ev_idx) |i| {
                                self.ev_idx = i;
                                continue :blk_ev;
                            }
                        },
                    }

                    if (is_ev_handled) {
                        continue :blk_ev;
                    }

                    switch (result) {
                        .pass => {
                            var first_ev_idx: ?usize = null;

                            for (self.events.array[0..self.events.size], 0..) |*event, i| {
                                if (event.kd_idx == kd_idx and event.blocked) {
                                    if (first_ev_idx == null)
                                        first_ev_idx = i;

                                    event.kd_idx += 1;
                                    event.blocked = false;
                                }
                            }

                            if (first_ev_idx) |i| {
                                ev.kd_idx = kd_idx + 1;
                                self.ev_idx = i;
                                continue :blk_ev;
                            } else {
                                kd_idx += 1;
                            }
                        },
                        .block => {
                            ev.kd_idx = kd_idx;
                            ev.blocked = true;
                            self.ev_idx += 1;
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
                        try self.key_defs.pushBack(key_def);
                        continue :blk_ev;
                    },
                    else => {},
                }

                _ = self.events.remove(self.ev_idx);
            }
        }

        fn handleKeycode(keycode: u16, down: bool) void {
            output.pushHidEvent(@truncate(keycode), down) catch unreachable;
        }

        fn scheduleTimeEvent(duration: TimeMillis) ScheduleToken {
            return impl.scheduleCall(duration);
        }

        fn getTimeMillis() TimeMillis {
            return impl.getTimeMillis();
        }

        pub fn callScheduled(self: *Self, token: u8) void {
            self.pushEvent(.{ .time = .{
                .token = token,
            } });
        }

        // Caller must guarantee that all key events are "toggles"
        // That is, caller must not report the same values of `down` consecutively (e.g. true->true, false->false)
        // That would be undefined behavior
        pub fn pushKeyEvent(self: *Self, key_idx: KeyIndex, down: bool) void {
            self.pushEvent(.{ .key = .{
                .key_idx = key_idx,
                .down = down,
            } });
        }
    };
}