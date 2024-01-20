const std = @import("std");

const Queue = @import("data_structs.zig").Queue;
const List = @import("data_structs.zig").List;

const config = @import("config.zig");
const output = @import("output_hid.zig");

const keymap = @import("keymap.zig");
const KeyDef = keymap.KeyDef;

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

pub const Event = struct {
    data: Data,
    time: TimeMillis = 0,
    handled: bool = false,
    kd_idx: u6 = 0,
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

var t: u8 = 69;

pub const Engine = struct {
    key_defs: KeyDefList = KeyDefList.init(),
    events: EventList = EventList.init(),
    ev_idx: u8 = 0,
    impl: Implementation,

    const Self = @This();
    const KeyDefList = List(KeyDef, 64);
    const EventList = List(Event, 256);

    const key_map = config.key_map;
    const callbacks = config.callbacks;

    pub fn init(comptime impl: Implementation) Self {
        return Self{ .impl = impl };
    }

    pub fn process(self: *Self) void {
        self.processEvents() catch unreachable;
        output.sendReports(self.impl);
    }

    fn pushEvent(self: *Self, data: Event.Data) void {
        self.events.pushBack(Event.init(data, self.getTimeMillis())) catch unreachable;
    }

    fn unblockEvents(self: *Self, kd_idx: u6, pass_to_next_kd: bool) ?u8 {
        var first_blocked_ev_idx: ?u8 = null;

        for (self.events.array[0..self.events.size], 0..) |*event, i| {
            if (event.kd_idx == kd_idx and event.blocked) {
                event.blocked = false;

                if (pass_to_next_kd)
                    event.kd_idx += 1;

                if (first_blocked_ev_idx == null)
                    first_blocked_ev_idx = @truncate(i);
            } else if (first_blocked_ev_idx != null) {
                // Blocked events are contiguous so if there's no more matching blocked events, that's all of it
                break;
            }
        }

        return first_blocked_ev_idx;
    }

    fn processEvents(self: *Self) !void {
        blk_ev: while (self.ev_idx < self.events.size) {
            const ev = self.events.at(self.ev_idx);

            if (ev.blocked) {
                unreachable;
            }

            var kd_idx = ev.kd_idx;

            while (kd_idx < self.key_defs.size) {
                const key_def = self.key_defs.at(kd_idx);
                const result = key_def.process(self, ev);
                const is_ev_handled = ev.isHandled();

                if (is_ev_handled) {
                    _ = self.events.remove(self.ev_idx);
                }

                switch (result) {
                    .pass => {},
                    .block => {},
                    .transform => |next| {
                        key_def.* = next;

                        if (self.unblockEvents(kd_idx, false)) |i| {
                            self.ev_idx = i;
                            continue :blk_ev;
                        }
                    },
                    .complete => {
                        const first_blocked_ev_idx = self.unblockEvents(kd_idx, false);

                        for (self.events.array[0..self.events.size]) |*event| {
                            if (event.kd_idx > kd_idx)
                                event.kd_idx -= 1;
                        }

                        _ = self.key_defs.remove(kd_idx);

                        if (first_blocked_ev_idx) |i| {
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
                        if (self.unblockEvents(kd_idx, true)) |i| {
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

    pub fn handleKeycode(self: Self, keycode: u16, down: bool) void {
        _ = self;
        output.pushHidEvent(@truncate(keycode), down) catch unreachable;
    }

    pub fn scheduleTimeEvent(self: *Self, time: TimeMillis) ScheduleToken {
        const cur_time = self.impl.getTimeMillis();

        if (time <= cur_time) {
            for (self.events.array[0..self.events.size], 0..) |ev, i| {
                if (ev.time >= time) {
                    self.events.insert(i, .{
                        .data = .{ .time = .{ .token = t } },
                        .kd_idx = ev.kd_idx,
                        .blocked = ev.blocked,
                    }) catch unreachable;
                    break;
                }
            } else {
                self.callScheduled(t);
            }

            defer t +%= 1;
            return t;
        } else {
            return self.impl.scheduleCall(time - cur_time);
        }
    }

    fn getTimeMillis(self: Self) TimeMillis {
        return self.impl.getTimeMillis();
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
