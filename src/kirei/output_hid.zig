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
weak_mods_binding: u8 = 0,
current_hid_keyboard_code: u8 = 0,

state_a: std.StaticBitSet(32) = std.StaticBitSet(32).initEmpty(),

// key_record_history: [16]KeyRecord,
// current_key_record: ?KeyRecord,

pub const KeyRecord = packed struct(u64) {
    mods: u8,
    key_code: KeyCode,
    __pad1: u12,
    time: engine.TimeMillis,
    __pad2: u16,
};

pub const HidKeyboardPattern = struct {
    mods: [4]ModifierPattern = [_]ModifierPattern{.{ .independent = .{} }} ** 4,
    code: CodePattern,

    pub const Necessity = enum { unwanted, required, optional };

    pub const ModifierPattern = union(enum) {
        either: void,
        xor: void,
        independent: struct {
            left: Necessity = .unwanted,
            right: Necessity = .unwanted,
        },
    };

    pub const CodePattern = union(enum) {
        any: Necessity,
        exact: u8,
        range: struct { from: u8, to: u8 },
    };

    pub fn matchesCode(self: HidKeyboardPattern, code: KeyCode) bool {
        return switch (self.code) {
            .any => |necessity| switch (necessity) {
                .unwanted => code == 0,
                .required => code != 0,
                .optional => true,
            },
            .exact => |c| c == code,
            .range => |range| range.from <= code and code <= range.to,
        };
    }

    pub fn matchesMods(self: HidKeyboardPattern, mods: u8) bool {
        var mask_both: u8 = 0x11;

        for (self.mods) |pattern| {
            const mask_left = mask_both & 0x0F;
            const mask_right = mask_both & 0xF0;
            const mods_masked_both = mods & mask_both;

            switch (pattern) {
                .either => {
                    if (mods_masked_both == 0)
                        return false;
                },
                .xor => {
                    if (mods_masked_both != mask_left and mods_masked_both != mask_right)
                        return false;
                },
                .independent => |ind| {
                    const left_down = (mods & mask_left) != 0;
                    const right_down = (mods & mask_right) != 0;

                    if ((ind.left == .unwanted and left_down) or (ind.left == .required and !left_down))
                        return false;

                    if ((ind.right == .unwanted and right_down) or (ind.right == .required and !right_down))
                        return false;
                },
            }

            mask_both <<= 1;
        }

        return true;
    }

    pub fn matches(self: HidKeyboardPattern, mods: u8, code: KeyCode) bool {
        return self.matchesMods(mods) and self.matchesCode(code);
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
    const kc_info = keymap.keyCodeInfo(key_code);

    { // Mods
        const report_mods = &self.report[0];

        if (self.hasWeakMods() and kc_info.kind == .hid_keyboard_code) {
            const has_binding = self.weak_mods_binding != 0;
            const is_bound_to_key_code = self.weak_mods_binding == kc_info.id;

            if (has_binding and (if (down) !is_bound_to_key_code else is_bound_to_key_code)) {
                self.weak_mods = 0;
                self.weak_anti_mods = 0;
                self.weak_mods_binding = 0;
            } else if (down) {
                self.weak_mods_binding = kc_info.id;
            }
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
    }

    // Code
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
                const new_code = if (down) hid_code else 0;

                if (report_codes[i] != new_code) {
                    report_codes[i] = new_code;
                    self.is_report_dirty = true;

                    if (down) {
                        self.current_hid_keyboard_code = hid_code;
                    } else if (!down and self.current_hid_keyboard_code == hid_code) {
                        self.current_hid_keyboard_code = 0;
                    }

                    if (down and self.hasWeakMods()) {
                        self.weak_mods_binding = new_code;
                    }
                }
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

// TODO: Unused right now. Would be useful as a query.
fn isAnyHidKeyboardCodePressed(self: OutputHid) bool {
    for (self.report[2..]) |code| {
        if (code != 0)
            return true;
    }
    return false;
}

// TODO: Unused right now. Would be useful as a query.
fn isAnyHidKeyboardCodeInRangePressed(self: OutputHid, from_incl: u8, to_incl: u8) bool {
    for (self.report[2..]) |code| {
        if (code != 0 and from_incl >= code and code <= to_incl)
            return true;
    }
    return false;
}

fn hasWeakMods(self: OutputHid) bool {
    return (self.weak_mods | self.weak_anti_mods) != 0;
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

pub fn isKeyGroupPressed(self: OutputHid, key_group: KeyGroup) bool {
    const kc = key_group.key_code;
    if (kc != 0 and !self.isKeyCodePressed(kc))
        return false;

    inline for (.{ "ctrl", "shift", "alt", "gui" }, 0..) |mod_name, i| {
        const mod: KeyGroup.Modifier = @field(key_group.mods, mod_name);
        const mods = self.getModsOfProps(mod.props);
        const mask = mod.mask(@truncate(i));

        if ((mods & mask) != mask)
            return false;
    }

    return true;
}

pub fn getModsOfProps(self: OutputHid, props: KeyGroup.Props) u8 {
    return switch (props.retention) {
        .normal => if (props.anti) self.normal_anti_mods else self.normal_mods,
        .weak => if (props.anti) self.weak_anti_mods else self.weak_mods,
    };
}

pub fn matches(self: OutputHid, pattern: HidKeyboardPattern) bool {
    return pattern.matches(self.report[0], self.current_hid_keyboard_code);
}
