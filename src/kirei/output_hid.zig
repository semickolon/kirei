const std = @import("std");
const engine = @import("engine.zig");

const Self = @This();

pub const HidReport = [8]u8;

const HidReportMods = std.bit_set.IntegerBitSet(8);
const HidReportCodes = [6]u8;
const ReportQueue = std.TailQueue(HidReport);

report: HidReport = std.mem.zeroes(HidReport),
report_queue: ReportQueue,
impl: engine.Implementation,

pub fn init(impl: engine.Implementation) Self {
    return .{
        .report_queue = .{},
        .impl = impl,
    };
}

pub fn pushHidEvent(self: *Self, code: u8, down: bool) !void {
    const report_mods: *HidReportMods = @ptrCast(&self.report[0]);
    const report_codes: *HidReportCodes = self.report[2..];

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
        const node = try self.impl.allocator.create(ReportQueue.Node);
        node.data = self.report;
        self.report_queue.prepend(node);
    }
}

pub fn sendReports(self: *Self) void {
    while (self.peekReport()) |*head| {
        if (self.impl.onReportPush(head)) {
            _ = self.popReport();
        } else {
            break;
        }
    }
}

pub fn peekReport(self: Self) ?HidReport {
    if (self.report_queue.last) |last| {
        return last.data;
    } else {
        return null;
    }
}

pub fn popReport(self: *Self) ?HidReport {
    if (self.report_queue.pop()) |node| {
        defer self.impl.allocator.destroy(node);
        return node.data;
    } else {
        return null;
    }
}
