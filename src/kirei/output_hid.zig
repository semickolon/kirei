const std = @import("std");
const engine = @import("engine.zig");
const keymap = @import("keymap.zig");

const KeyGroup = keymap.KeyGroup;
const KeyCode = keymap.KeyCode;

const OutputHid = @This();

pub const HidReport = [8]u8;

// TODO: Likely better if this is a static ring buffer
const ReportQueue = std.BoundedArray(HidReport, 32);

report: HidReport = std.mem.zeroes(HidReport),
report_queue: ReportQueue = ReportQueue.init(0) catch unreachable,
is_report_dirty: bool = false,
impl: engine.Implementation,

normal_mods: u8 = 0,
weak_mods: u8 = 0,
normal_anti_mods: u8 = 0,
weak_anti_mods: u8 = 0,

state_a: std.StaticBitSet(32) = std.StaticBitSet(32).initEmpty(),

// key_record_history: [16]KeyRecord,
// current_key_record: ?KeyRecord,

pub const KeyRecord = packed struct(u64) {
    mods: u8,
    key_code: KeyCode,
    __pad1: u12,
    time: engine.TimeMillis,
    __pad2: u16,

    pub fn matches(self: KeyRecord, pattern: KeyPattern) bool {
        return pattern.matches(self.key_code, self.mods);
    }
};

pub const KeyPattern = struct {
    mods: [8]ModifierNecessity = [_]ModifierNecessity{.unwanted} ** 8,
    key_code: KeyCodePattern,

    pub const ModifierNecessity = enum { unwanted, required, optional };

    pub const KeyCodePattern = union(enum) {
        none: void,
        exact: KeyCode,
        range: struct { from: KeyCode, to: KeyCode },
    };

    pub fn matchesKeyCode(self: KeyPattern, key_code: KeyCode) bool {
        return switch (self) {
            .none => true,
            .exact => |kc| kc == key_code,
            .range => |range| range.from >= key_code and range.to <= key_code,
        };
    }

    pub fn matchesMods(self: KeyPattern, mods: u8) bool {
        var optional_mods: u8 = 0;
        var exact_mods: u8 = 0;
        var mask: u8 = 1;

        for (self.mods) |mod| {
            switch (mod) {
                .optional => optional_mods |= mask,
                .required => exact_mods |= mask,
                .unwanted => {},
            }

            mask <<= 1;
        }

        return (mods & ~optional_mods) == exact_mods;
    }

    pub fn matches(self: KeyPattern, key_code: KeyCode, mods: u8) bool {
        return self.matchesKeyCode(key_code) and self.matchesMods(mods);
    }
};

pub fn init(impl: engine.Implementation) OutputHid {
    return .{ .impl = impl };
}

pub fn pushKeyGroup(self: *OutputHid, key_group: KeyGroup, down: bool) void {
    if (self.is_report_dirty) {
        self.report_queue.append(self.report) catch @panic("OutputHid report queue overflow.");
        self.is_report_dirty = false;
    }

    const key_code = key_group.key_code;

    // Mods
    const report_mods = &self.report[0];

    // TODO: `key_code != 0` doesn't necessarily guarantee lack of change in reported HID codes.
    // For example, pressing A then A on another key, or pressing a Kirei-space key.
    if ((self.weak_mods | self.weak_anti_mods) != 0 and down and key_code != 0) {
        self.weak_mods = 0;
        self.weak_anti_mods = 0;
    }

    const kc_normal_mods = key_group.modsAsByte(.normal, false);
    const kc_weak_mods = key_group.modsAsByte(.weak, false);
    const kc_normal_anti_mods = key_group.modsAsByte(.normal, true);
    const kc_weak_anti_mods = key_group.modsAsByte(.weak, true);

    if (down) {
        self.weak_mods |= kc_weak_mods;
        self.weak_anti_mods |= kc_weak_anti_mods;

        self.normal_mods |= kc_normal_mods;
        self.normal_anti_mods |= kc_normal_anti_mods;
    } else {
        self.weak_mods &= ~kc_weak_mods;
        self.weak_anti_mods &= ~kc_weak_anti_mods;

        self.normal_mods &= ~kc_normal_mods;
        self.normal_anti_mods &= ~kc_normal_anti_mods;
    }

    const new_mods = (self.normal_mods | self.weak_mods) & ~(self.normal_anti_mods | self.weak_anti_mods);

    if (new_mods != report_mods.*) {
        report_mods.* = new_mods;
        self.is_report_dirty = true;
    }

    // Code
    const kc_info = keymap.keyCodeInfo(key_code);

    switch (kc_info.kind) {
        .hid_keyboard_code => {
            const hid_code = kc_info.id;
            if (hid_code < 4) return;

            const report_codes: *[6]u8 = self.report[2..];
            var idx: ?usize = null;

            for (report_codes, 0..) |rc, i| {
                if ((down and (rc == 0 or rc == hid_code)) or (!down and rc == hid_code)) {
                    idx = i;
                    break;
                }
            }

            if (idx) |i| {
                report_codes[i] = if (down) hid_code else 0;
                self.is_report_dirty = true;
            } else if (down) {
                @panic("Unhandled case: No more HID report space."); // TODO
            }
        },
        .kirei_state_a => {
            const idx: u5 = @truncate(kc_info.id);

            if (down) {
                self.state_a.set(idx);
            } else {
                self.state_a.unset(idx);
            }
        },
        .hid_keyboard_modifier, .reserved => {},
    }
}

pub fn sendReports(self: *OutputHid) void {
    while (self.report_queue.len > 0) {
        const head = &self.report_queue.get(0);

        if (self.impl.onReportPush(head)) {
            _ = self.report_queue.orderedRemove(0);
        } else {
            return;
        }
    }

    if (self.is_report_dirty) {
        if (self.impl.onReportPush(&self.report))
            self.is_report_dirty = false;
    }
}

pub fn isKeyCodePressed(self: OutputHid, key_code: KeyCode) bool {
    const kc_info = keymap.keyCodeInfo(key_code);

    switch (kc_info.kind) {
        .hid_keyboard_code => {
            for (self.report[2..]) |hid_code| {
                if (kc_info.id == hid_code)
                    return true;
            }
            return false;
        },
        .hid_keyboard_modifier => {
            const mod_idx: u3 = @truncate(kc_info.id);
            return (self.report[0] & (@as(u8, 1) << mod_idx)) != 0;
        },
        .kirei_state_a => {
            const idx: u5 = @truncate(kc_info.id);
            return self.state_a.isSet(idx);
        },
        .reserved => return false,
    }
}

pub fn matches(self: OutputHid, pattern: KeyPattern) bool {
    const key_code_matches = switch (pattern.key_code) {
        .none => true,
        .exact => |kc| self.isKeyCodePressed(kc),
        .range => |range| for (range.from..range.to) |kc| {
            if (self.isKeyCodePressed(@truncate(kc))) break true;
        } else false,
    };

    return key_code_matches and pattern.matchesMods(self.report[0]);
}
