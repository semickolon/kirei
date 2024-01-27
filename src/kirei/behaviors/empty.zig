const std = @import("std");
const eng = @import("../engine.zig");

const KeyIndex = eng.KeyIndex;
const Engine = eng.Engine;
const Event = eng.Event;
const ProcessResult = eng.ProcessResult;

const Self = @This();

pub const Config = struct {};

pub fn init(_: Config) Self {
    return .{};
}

pub fn process(_: *Self, _: KeyIndex, _: *Engine, ev: *Event) ProcessResult {
    ev.markHandled();
    return .complete;
}
