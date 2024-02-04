const std = @import("std");
const engine = @import("engine.zig");

const OutputHid = @This();

pub const HidReport = [8]u8;

const HidReportMods = std.bit_set.IntegerBitSet(8);
const HidReportCodes = [6]u8;
// TODO: Likely better if this is a static ring buffer
const ReportQueue = std.BoundedArray(HidReport, 32);

report: HidReport = std.mem.zeroes(HidReport),
report_queue: ReportQueue = ReportQueue.init(0) catch unreachable,
is_report_dirty: bool = false,
impl: engine.Implementation,

pub fn init(impl: engine.Implementation) OutputHid {
    return .{ .impl = impl };
}

pub fn pushHidEvent(self: *OutputHid, code: u8, down: bool) void {
    if (self.is_report_dirty) {
        self.report_queue.append(self.report) catch @panic("OutputHid report queue overflow.");
        self.is_report_dirty = false;
    }

    const report_mods: *HidReportMods = @ptrCast(&self.report[0]);
    const report_codes: *HidReportCodes = self.report[2..];

    if (code >= 0xE0 and code <= 0xE7) {
        report_mods.setValue(code - 0xE0, down);
        self.is_report_dirty = true;
    } else {
        var idx: ?usize = null;

        for (report_codes, 0..) |rc, i| {
            if ((down and rc == 0) or (!down and rc == code)) {
                idx = i;
                break;
            }
        }

        if (idx) |i| {
            report_codes[i] = if (down) code else 0;
            self.is_report_dirty = true;
        } else if (down) {
            // TODO: Handle case if there's no free space
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
