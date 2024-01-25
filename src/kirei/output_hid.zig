const std = @import("std");
const engine = @import("engine.zig");

const OutputHid = @This();

pub const HidReport = [8]u8;

const HidReportMods = std.bit_set.IntegerBitSet(8);
const HidReportCodes = [6]u8;
const ReportQueue = LinkedList(HidReport);

report: HidReport = std.mem.zeroes(HidReport),
report_queue: ReportQueue,
is_report_dirty: bool = false,
impl: engine.Implementation,

pub fn init(impl: engine.Implementation) OutputHid {
    return .{
        .report_queue = ReportQueue.init(impl.allocator),
        .impl = impl,
    };
}

pub fn pushHidEvent(self: *OutputHid, code: u8, down: bool) !void {
    if (self.is_report_dirty) {
        try self.report_queue.append(self.report);
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

pub fn sendReports(self: *OutputHid) !void {
    while (self.report_queue.peek()) |head| {
        if (self.impl.onReportPush(&head)) {
            _ = self.report_queue.pop();
        } else {
            break;
        }
    } else if (self.is_report_dirty) {
        if (self.impl.onReportPush(&self.report))
            self.is_report_dirty = false;
    }
}

// Singly linked list but with a pointer to the last node for append operations
pub fn LinkedList(comptime T: type) type {
    const SinglyLinkedList = std.SinglyLinkedList(T);

    return struct {
        list: SinglyLinkedList = SinglyLinkedList{},
        last_node: ?*SinglyLinkedList.Node = null,
        allocator: std.mem.Allocator,

        const Self = @This();
        const Node = SinglyLinkedList.Node;

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        fn createNode(self: Self, data: T) !*Node {
            const node = try self.allocator.create(Node);
            node.data = data;
            return node;
        }

        pub fn prepend(self: *Self, data: T) !void {
            const node = try self.createNode(data);

            if (self.list.first == null)
                self.last_node = node;

            self.list.prepend(node);
        }

        pub fn append(self: *Self, data: T) !void {
            if (self.last_node) |last| {
                last.insertAfter(try self.createNode(data));
            } else {
                try self.prepend(data);
            }
        }

        pub fn peek(self: Self) ?T {
            if (self.list.first) |first| {
                return first.data;
            } else {
                return null;
            }
        }

        pub fn pop(self: *Self) ?T {
            if (self.list.popFirst()) |node| {
                if (node == self.last_node)
                    self.last_node = null;

                defer self.allocator.destroy(node);
                return node.data;
            } else {
                return null;
            }
        }
    };
}
