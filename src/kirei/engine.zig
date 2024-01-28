const std = @import("std");

const OutputHid = @import("output_hid.zig");

const keymap = @import("keymap.zig");
const Keymap = keymap.Keymap;
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
    allocator: std.mem.Allocator,

    onReportPush: *const fn (report: *const OutputHid.HidReport) bool,
    getTimeMillis: *const fn () TimeMillis,
    scheduleCall: *const fn (duration: TimeMillis, token: ScheduleToken) void,
    cancelCall: *const fn (token: ScheduleToken) void,
};

pub const Engine = struct {
    keymap: Keymap,
    output_hid: OutputHid,
    key_defs: KeyDefList,
    events: EventList,
    ev_idx: u8 = 0,
    impl: Implementation,
    schedule_token_counter: ScheduleToken = 0,

    const Self = @This();

    const KeyDefList = std.ArrayList(KeyDef);
    const EventList = std.ArrayList(Event);

    pub fn init(impl: Implementation, keymap_bytes: []align(4) const u8) !Self {
        return Self{
            .impl = impl,
            .keymap = try Keymap.init(impl, keymap_bytes),
            .output_hid = OutputHid.init(impl),
            .key_defs = KeyDefList.init(impl.allocator),
            .events = EventList.init(impl.allocator),
        };
    }

    pub fn process(self: *Self) void {
        self.processEvents() catch unreachable;
        self.output_hid.sendReports() catch unreachable;
    }

    fn pushEvent(self: *Self, data: Event.Data) void {
        self.events.append(Event.init(data, self.getTimeMillis())) catch unreachable;
    }

    fn unblockEvents(self: *Self, kd_idx: u6, pass_to_next_kd: bool) ?u8 {
        var first_blocked_ev_idx: ?u8 = null;

        for (self.events.items, 0..) |*event, i| {
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
        blk_ev: while (self.ev_idx < self.events.items.len) {
            const ev = &self.events.items[self.ev_idx];

            if (ev.blocked) {
                unreachable;
            }

            var kd_idx = ev.kd_idx;

            while (kd_idx < self.key_defs.items.len) {
                const key_def = &self.key_defs.items[kd_idx];
                const result = key_def.process(self, ev);
                const is_ev_handled = ev.isHandled();

                if (is_ev_handled) {
                    _ = self.events.orderedRemove(self.ev_idx);
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

                        for (self.events.items) |*event| {
                            if (event.kd_idx > kd_idx)
                                event.kd_idx -= 1;
                        }

                        _ = self.key_defs.orderedRemove(kd_idx);

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
                    const key_def = self.keymap.parseKeyDef(key_ev.key_idx);
                    try self.key_defs.append(key_def);
                    continue :blk_ev;
                },
                else => {},
            }

            _ = self.events.orderedRemove(self.ev_idx);
        }
    }

    pub fn handleKeycode(self: *Self, keycode: u16, down: bool) void {
        self.output_hid.pushHidEvent(@truncate(keycode), down) catch unreachable;
    }

    pub fn scheduleTimeEvent(self: *Self, time: TimeMillis) ?ScheduleToken {
        const token = self.schedule_token_counter;
        self.schedule_token_counter +%= 1;

        const cur_time = self.impl.getTimeMillis();

        if (time <= cur_time)
            self.insertRetroactiveTimeEvent(time, token)
        else
            self.impl.scheduleCall(time -% cur_time, token);

        return token;
    }

    pub fn cancelTimeEvent(self: *Self, token: ScheduleToken) void {
        self.impl.cancelCall(token);
    }

    fn insertRetroactiveTimeEvent(self: *Self, time: TimeMillis, token: ScheduleToken) void {
        for (self.events.items, 0..) |ev, i| {
            if (ev.time >= time) {
                self.events.insert(i, .{
                    .data = .{ .time = .{ .token = token } },
                    .kd_idx = ev.kd_idx,
                    .blocked = ev.blocked,
                }) catch unreachable;
                break;
            }
        } else {
            self.callScheduled(token);
        }
    }

    fn getTimeMillis(self: Self) TimeMillis {
        return self.impl.getTimeMillis();
    }

    pub fn callScheduled(self: *Self, token: ScheduleToken) void {
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
