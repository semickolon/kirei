const std = @import("std");

const config = @import("../config.zig");
const Queue = @import("data_structs.zig").Queue;
const output = @import("output_hid.zig");
const keymap = @import("keymap.zig");

const KeyState = packed struct {
    down: bool = false,
};

const KEY_EVENT_QUEUE_CAPACITY = config.engine.key_event_queue_size;
const KEY_COUNT = config.engine.key_map.len;

pub const KeyIndex = u15;
pub const TimeMillis = u16;

pub const KeyEvent = packed struct(u32) {
    key_idx: KeyIndex,
    down: bool,
    time: TimeMillis,
};

pub const EngineInterface = struct {
    handleKeycode: *const fn (keycode: u16, down: bool) void,
};

pub const ReikiEvent = struct {
    data: union(enum) {
        key: KeyEvent,
    },
    time: TimeMillis = 0,
};

const interface = EngineInterface{
    .handleKeycode = handleKeycode,
};

var key_event_queue: Queue(KeyEvent, KEY_EVENT_QUEUE_CAPACITY) = undefined;

const key_map = config.engine.key_map;
const callbacks = config.engine.callbacks;

var key_states: [KEY_COUNT]KeyState = .{.{}} ** KEY_COUNT;

var mem_heap: [1024 * 12]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&mem_heap);
var key_def_map = std.AutoArrayHashMap(KeyIndex, keymap.KeyDef).init(fba.allocator());

pub fn process() void {
    while (key_event_queue.pop()) |ev| {
        const k = ev.key_idx;

        if (!key_def_map.contains(k)) {
            key_def_map.put(k, keymap.Keymap.parseKeydef(k)) catch unreachable;
        }

        const key_def = key_def_map.getPtr(k).?;

        const rev = ReikiEvent{ .data = .{ .key = .{
            .key_idx = k,
            .down = ev.down,
            .time = ev.time,
        } } };

        if (key_def.process(&interface, &rev)) {
            _ = key_def_map.swapRemove(k);
        }
    }

    config.sys.led_1.write(key_def_map.count() == 0);

    output.sendReports();
}

fn handleKeycode(keycode: u16, down: bool) void {
    output.pushHidEvent(@truncate(keycode), down) catch unreachable;
}

pub fn pushKeyEvent(key_idx: KeyIndex, down: bool) void {
    var ks = &key_states[key_idx];
    if (ks.down == down) return;

    ks.down = down;
    key_event_queue.push(.{
        .key_idx = key_idx,
        .down = down,
        .time = 0,
    }) catch unreachable;
}
