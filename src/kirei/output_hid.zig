const std = @import("std");
const config = @import("config.zig");
const engine = @import("engine.zig");

const REPORT_QUEUE_CAPACITY = config.report_queue_size;

const Queue = @import("data_structs.zig").Queue;

pub const HidReport = [8]u8;
const HidReportMods = std.bit_set.IntegerBitSet(8);
const HidReportCodes = [6]u8;

var report = std.mem.zeroes(HidReport);
const report_mods: *HidReportMods = @ptrCast(&report[0]);
const report_codes: *HidReportCodes = report[2..];

var report_queue = Queue(HidReport, REPORT_QUEUE_CAPACITY).init();

pub fn pushHidEvent(code: u8, down: bool) !void {
    var dirty = false;

    if (code >= 0xE0 and code <= 0xE7) {
        report_mods.setValue(code - 0xE0, down);
        dirty = true;
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
            dirty = true;
        } else if (down) {
            // TODO: Handle case if there's no free space
        }
    }

    if (dirty) {
        try report_queue.push(report);
    }
}

pub fn sendReports(comptime impl: engine.Implementation) void {
    while (report_queue.peek()) |head| {
        if (impl.onReportPush(head)) {
            _ = report_queue.pop();
        } else {
            break;
        }
    }
}

pub fn peekReport() ?*HidReport {
    return report_queue.peek();
}

pub fn popReport() ?HidReport {
    return report_queue.pop();
}
