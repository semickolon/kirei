const std = @import("std");

const OutputHid = @import("output_hid.zig");

const keymap = @import("keymap.zig");
pub const KeyMap = keymap.KeyMap;
pub const KeyDef = keymap.KeyDef;
pub const KeyGroup = keymap.KeyGroup;
pub const KeyCode = keymap.KeyCode;

pub const KeyIndex = u8;
pub const TimeMillis = u16;
pub const ScheduleToken = u8;

const compiled_key_map = true;

pub const KM: KeyMap = &.{
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 4 } } } },
    .{
        .literal = .{
            .key_press = .{
                .key_group = .{
                    .key_code = 5,
                    .mods = .{
                        .shift = .{ .side = .both, .props = .{ .anti = true, .retention = .weak } },
                    },
                },
            },
        },
    },
    .{
        .literal = .{
            .key_press = .{
                .key_group = .{
                    // .key_code = 5,
                    .mods = .{
                        .shift = .{
                            .side = .both,
                            .props = .{ .retention = .normal },
                        },
                    },
                },
            },
        },
    },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 8 } } } },
    .{ .literal = .{
        .key_press = .{
            .key_group = .{
                .key_code = 0x1E,
                .mods = .{
                    .shift = .{
                        .side = .left,
                        .props = .{ .retention = .weak },
                    },
                },
            },
        },
    } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 0 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 10 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 11 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 12 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 13 } } } },
    .{ .literal = .{ .key_toggle = .{ .key_group = .{ .key_code = 0xE8 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 0x107 } } } },
    // .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 16 } } } },
    .{
        .swt = .{
            .branches = &.{
                .{
                    .condition = .{ .logical_and = &.{
                        .{ .query = .{ .is_pressed = 0x04 } },
                        .{ .query = .{ .is_pressed = 0xE8 } },
                        .{ .query = .{ .is_pressed = 0xE1 } },
                    } },
                    .value = .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 19 } } } },
                },
                .{
                    .condition = .{ .query = .{ .is_pressed = 0xE8 } },
                    .value = .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 18 } } } },
                },
                .{
                    .condition = .{ .query = .{ .is_pressed = 0x04 } },
                    .value = .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 17 } } } },
                },
            },
            .fallback = .{ .key_press = .{ .key_group = .{ .key_code = 16 } } },
        },
    },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 17 } } } },
    .{
        .swt = .{
            .branches = &.{
                .{
                    .condition = .{ .logical_or = &.{
                        .{ .query = .{ .is_pressed = 0xE1 } },
                        .{ .query = .{ .is_pressed = 0xE5 } },
                    } },
                    .value = .{
                        .literal = .{ .key_press = .{
                            .key_group = .{
                                .key_code = 0x21,
                                .mods = .{
                                    .shift = .{
                                        .side = .both,
                                        .props = .{ .retention = .weak, .anti = true },
                                    },
                                },
                            },
                        } },
                    },
                },
            },
            .fallback = .{ .key_press = .{
                .key_group = .{
                    .key_code = 0x21,
                    .mods = .{
                        .shift = .{
                            .side = .left,
                            .props = .{ .retention = .weak },
                        },
                    },
                },
            } },
        },
    },
    // .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 18 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 19 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 20 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 21 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 22 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 23 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 24 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 25 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 26 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 27 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 28 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 29 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 4 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 4 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 4 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 4 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 20 } } } },
    // .{ .key_press = .{ .key_group = .{ .key_code = 21 } } },
    .{ .literal = .{ .hold_tap = .{
        .tap_key_def = &.{ .key_press = .{ .key_group = .{ .key_code = 4 } } },
        .hold_key_def = &.{ .key_press = .{ .key_group = .{ .key_code = 5 } } },
        .timeout_ms = 1000,
    } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 22 } } } },
    .{ .literal = .{ .key_press = .{ .key_group = .{ .key_code = 23 } } } },
};

fn resolveKeyDef(key_idx: KeyIndex, engine: *const Engine) KeyDef {
    if (compiled_key_map) {
        std.debug.assert(KM.len <= std.math.maxInt(KeyIndex) + 1);

        inline for (KM, 0..) |expr, i| {
            if (key_idx == i) {
                return (comptime expr.resolveFn())(engine);
            }
        }
        unreachable;
    } else {
        return engine.key_map[key_idx].resolve(engine);
    }
}

const KEY_COUNT = 34; // TODO

pub const KeyEvent = struct {
    key_idx: KeyIndex,
    down: bool,
};

pub const TimeEvent = struct {
    token: ScheduleToken,
};

pub const Event = struct {
    data: Data,
    time: TimeMillis,

    pub const Data = union(enum) {
        key: KeyEvent,
        time: TimeEvent,
    };
};

pub const Implementation = struct {
    allocator: std.mem.Allocator,

    onReportPush: *const fn (report: *const OutputHid.HidReport) bool,
    getTimeMillis: *const fn () TimeMillis,
    scheduleCall: *const fn (duration: TimeMillis, token: ScheduleToken) void,
    cancelCall: *const fn (token: ScheduleToken) void,
};

pub const Engine = struct {
    impl: Implementation,
    key_map: if (compiled_key_map) void else KeyMap,
    keys_pressed: KeysPressed = KeysPressed.initEmpty(),
    schedule_token_counter: ScheduleToken = 0,
    output_hid: OutputHid,
    key_defs: [KEY_COUNT]?KeyDef,
    sync_key_idx: ?KeyIndex = null,
    events: EventList,
    ev_idx: u8 = 0,

    const Self = @This();

    const EventList = std.BoundedArray(Event, 64);
    const KeysPressed = std.StaticBitSet(KEY_COUNT);

    pub fn init(impl: Implementation, key_map: KeyMap) !Self {
        return Self{
            .impl = impl,
            .key_map = if (compiled_key_map) {} else key_map,
            .output_hid = OutputHid.init(impl),
            .key_defs = [_]?KeyDef{null} ** KEY_COUNT,
            .events = EventList.init(0) catch unreachable,
        };
    }

    pub fn process(self: *Self) void {
        self.processEvents();
        self.output_hid.sendReports();
    }

    fn pushEvent(self: *Self, data: Event.Data) void {
        self.events.append(.{
            .data = data,
            .time = self.getTimeMillis(),
        }) catch @panic("Engine event overflow - push");
    }

    fn setKeyDef(self: *Self, key_idx: KeyIndex, key_def: ?KeyDef) void {
        if (key_def != null and key_def.?.getType() == .sync) {
            if (self.sync_key_idx) |i| {
                // If we're setting a new sync KeyDef while there's currently one, it must be the same key index.
                std.debug.assert(key_idx == i);
            } else {
                self.sync_key_idx = key_idx;
            }
        } else if (self.sync_key_idx == key_idx) {
            self.sync_key_idx = null;
        }

        self.key_defs[key_idx] = key_def;
    }

    fn processEvents(self: *Self) void {
        blk_ev: while (self.ev_idx < self.events.len) {
            const ev = self.events.get(self.ev_idx);

            switch (ev.data) {
                .key => |k| {
                    const key_def = self.key_defs[k.key_idx];

                    if (self.sync_key_idx != k.key_idx and key_def != null) {
                        const completed = key_def.?.processSimple(self, k.down);
                        _ = self.events.orderedRemove(self.ev_idx);

                        if (completed) {
                            self.setKeyDef(k.key_idx, null);
                        }

                        continue :blk_ev;
                    }
                },
                .time => {},
            }

            if (self.sync_key_idx) |key_idx| {
                const key_def = self.key_defs[key_idx].?;
                const result = key_def.processSync(self, key_idx, ev);

                if (result.event_handled) {
                    _ = self.events.orderedRemove(self.ev_idx);
                }

                switch (result.action) {
                    .block => if (!result.event_handled) {
                        self.ev_idx += 1;
                    },
                    .transform => |to_key_def| {
                        self.setKeyDef(key_idx, to_key_def);
                        self.ev_idx = 0;
                    },
                }

                continue :blk_ev;
            }

            switch (ev.data) {
                .key => |k| if (k.down) {
                    const key_def = resolveKeyDef(k.key_idx, self);
                    self.setKeyDef(k.key_idx, key_def);
                    continue :blk_ev;
                },
                .time => {},
            }

            _ = self.events.orderedRemove(self.ev_idx);
        }
    }

    pub fn scheduleTimeEvent(self: *Self, time: TimeMillis) ScheduleToken {
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
        for (self.events.constSlice(), 0..) |ev, i| {
            if (ev.time >= time) {
                self.events.insert(i, .{
                    .data = .{ .time = .{ .token = token } },
                    .time = time,
                }) catch @panic("Engine event overflow - retroactive");
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

    pub fn pushKeyEvent(self: *Self, key_idx: KeyIndex, down: bool) void {
        if (self.isKeyPressed(key_idx) == down)
            return;

        self.keys_pressed.toggle(key_idx);
        self.pushEvent(.{ .key = .{
            .key_idx = key_idx,
            .down = down,
        } });
    }

    pub fn isKeyPressed(self: Self, key_idx: KeyIndex) bool {
        return self.keys_pressed.isSet(key_idx);
    }
};
