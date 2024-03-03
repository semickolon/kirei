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

pub fn init(impl: engine.Implementation) OutputHid {
    return .{ .impl = impl };
}

pub fn pushHidEvent(self: *OutputHid, key_group: KeyGroup, down: bool) void {
    if (self.is_report_dirty) {
        self.report_queue.append(self.report) catch @panic("OutputHid report queue overflow.");
        self.is_report_dirty = false;
    }

    const key_code = key_group.key_code;

    // Mods
    const report_mods = &self.report[0];

    // TODO: `key_code != 0` doesn't necessarily guarantee lack of change in HID code.
    // For example, pressing A then A on another key.
    if ((self.weak_mods | self.weak_anti_mods) != 0 and down and key_code != 0) {
        self.weak_mods = 0;
        self.weak_anti_mods = 0;
        std.log.debug("cleared weak mods", .{});
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
    const report_codes: *[6]u8 = self.report[2..];

    if (key_code < 0xE0) {
        const hid_code: u8 = @truncate(key_code);
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
