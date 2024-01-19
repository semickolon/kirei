const std = @import("std");
const config = @import("config.zig");

const engine = @import("engine.zig");
const KeyIndex = engine.KeyIndex;

pub const Keymap = struct {
    const km = config.key_map;

    pub fn parseKeydef(key_idx: KeyIndex) KeyDef {
        var offset: usize = 0;
        var i = key_idx;

        while (i > 0) : (i -= 1) {
            offset += km[offset] + 1;
        }

        var len: usize = km[offset];
        return KeyDef.parse(key_idx, km[offset + 1 .. offset + 1 + len]);
    }
};

pub const KeyDef = struct {
    key_idx: KeyIndex,
    behavior: Behavior,
    last_processed_event_id: engine.Event.Id = 0,

    pub const Behavior = union(enum) {
        key_press: KeyPressBehavior,
        hold_tap: HoldTapBehavior,
        tap_dance: TapDanceBehavior,
    };

    const Self = @This();

    pub fn parse(key_idx: KeyIndex, bytes: []const u8) Self {
        return Self{
            .key_idx = key_idx,
            .behavior = switch (bytes[0]) {
                0 => .{ .key_press = KeyPressBehavior.parse(bytes[1..]) },
                1 => .{ .hold_tap = HoldTapBehavior.parse() },
                2 => .{ .tap_dance = TapDanceBehavior.parse() },
                else => unreachable,
            },
        };
    }

    pub fn process(self: *Self, eif: *const engine.Interface, ev: *engine.Event) engine.ProcessResult {
        self.last_processed_event_id = ev.id;
        return switch (self.behavior) {
            inline else => |*behavior| behavior.process(self.key_idx, eif, ev),
        };
    }
};

const KeyPressBehavior = struct {
    key_code: u16,

    const Self = @This();

    fn parse(bytes: []const u8) Self {
        return .{ .key_code = std.mem.readInt(u16, bytes[0..2], .Little) };
    }

    fn process(self: *Self, key_idx: KeyIndex, eif: *const engine.Interface, ev: *engine.Event) engine.ProcessResult {
        switch (ev.data) {
            .key => |key_ev| {
                if (key_idx == key_ev.key_idx) {
                    ev.markHandled();
                    eif.handleKeycode(self.key_code, key_ev.down);
                    return if (key_ev.down) .block else .complete;
                }
            },
            else => {},
        }
        return .pass;
    }
};

const HoldTapBehavior = struct {
    hold_keycode: u16 = 0xE0,
    tap_keycode: u16 = 0x08,
    timeout_ms: u16 = 200,
    timeout_token: engine.ScheduleToken = 0,

    const Self = @This();

    fn parse() Self {
        return .{};
    }

    fn process(self: *Self, key_idx: KeyIndex, eif: *const engine.Interface, ev: *engine.Event) engine.ProcessResult {
        const hold_decision = .{ .transform = keyPressDef(key_idx, self.hold_keycode) };
        const tap_decision = .{ .transform = keyPressDef(key_idx, self.tap_keycode) };

        // TODO: Nested hold-taps are not yet time-aware
        switch (ev.data) {
            .key => |key_ev| {
                if (key_idx == key_ev.key_idx) {
                    if (key_ev.down) {
                        self.timeout_token = eif.scheduleTimeEvent(self.timeout_ms);
                    } else {
                        return tap_decision;
                    }
                } else {
                    return hold_decision;
                }
            },
            .time => |time_ev| {
                if (time_ev.token == self.timeout_token) {
                    ev.markHandled();
                    return hold_decision;
                }
            },
        }
        return .block;
    }

    fn keyPressDef(key_idx: KeyIndex, keycode: u16) KeyDef {
        return .{
            .key_idx = key_idx,
            .behavior = .{ .key_press = .{ .key_code = keycode } },
        };
    }
};

const TapDanceBehavior = struct {
    tapping_term_ms: u12 = 250,
    max_tap_count: u4 = 5,

    tap_counter: u8 = 0,
    resolved_tap_count: u8 = 0,
    tapping_term_token: engine.ScheduleToken = 0,
    unwind: bool = false,

    const Self = @This();

    fn parse() Self {
        return .{};
    }

    fn process(self: *Self, key_idx: KeyIndex, eif: *const engine.Interface, ev: *engine.Event) engine.ProcessResult {
        if (self.unwind) {
            switch (ev.data) {
                .key => |key_ev| if (key_idx == key_ev.key_idx) {
                    ev.markHandled();
                    if (!key_ev.down) {
                        self.tap_counter -= 1;
                    }
                },
                else => {},
            }

            if (self.tap_counter == 1) {
                return .{ .transform = keyPressDef(key_idx, 4 + self.resolved_tap_count - 1) };
            }
        } else {
            self.unwind = self.tally(key_idx, eif, ev);

            if (self.unwind) {
                self.resolved_tap_count = self.tap_counter;

                return if (self.resolved_tap_count == 1)
                    .{ .transform = keyPressDef(key_idx, 4) }
                else if (self.resolved_tap_count > 1)
                    .{ .transform = KeyDef{ .key_idx = key_idx, .behavior = .{ .tap_dance = self.* } } }
                else
                    .complete;
            }
        }
        return .block;
    }

    fn tally(self: *Self, key_idx: KeyIndex, eif: *const engine.Interface, ev: *engine.Event) bool {
        switch (ev.data) {
            .key => |key_ev| {
                if (key_idx == key_ev.key_idx) {
                    if (key_ev.down) {
                        self.tap_counter += 1;

                        if (self.tap_counter < self.max_tap_count) {
                            // TODO: This will keep scheduling. Provide API for rescheduling using the same token.
                            self.tapping_term_token = eif.scheduleTimeEvent(self.tapping_term_ms);
                        } else {
                            return true;
                        }
                    }
                } else {
                    return true;
                }
            },
            .time => |time_ev| if (time_ev.token == self.tapping_term_token) {
                ev.markHandled();
                return true;
            },
        }
        return false;
    }

    fn keyPressDef(key_idx: KeyIndex, keycode: u16) KeyDef {
        return .{
            .key_idx = key_idx,
            .behavior = .{ .key_press = .{ .key_code = keycode } },
        };
    }
};
