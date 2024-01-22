const std = @import("std");
const testing = std.testing;

pub const Config = struct {
    block_body_size: usize = 8,
    block_selection_method: enum {
        BestFit,
        FirstFit,
    } = .BestFit,
    debug_logging: bool = false,
};

pub const std_options = struct {
    pub const log_level = .debug;
};

const logger = std.log.scoped(.umm);

pub fn UmmAllocator(comptime config: Config) type {
    return struct {
        heap: []Block.Storage,

        const Self = @This();

        pub fn init(buf: []u8) !Self {
            const self = Self{
                .heap = @as([*]Block.Storage, @ptrCast(@alignCast(buf.ptr)))[0..(buf.len / @sizeOf(Block.Storage))],
            };

            if (self.heap.len > std.math.maxInt(std.meta.Int(.unsigned, @typeInfo(BlockIndexType).Int.bits - 1)))
                return error.BufferTooBig;

            // Do this upfront instead with `std.mem.zeroes`
            // @memset(buf, 0);

            const first_block = self.get_block(0);
            const first_block_storage = first_block.get_storage(&self);

            const second_block = self.get_block(1);
            const second_block_storage = second_block.get_storage(&self);

            const last_block = self.get_last_block();
            const last_block_storage = last_block.get_storage(&self);

            // setup Block(1) which is free block with the size of the whole heap
            first_block_storage.set_prev(last_block);
            first_block_storage.set_next(second_block, true);
            first_block_storage.set_free_prev(second_block);
            first_block_storage.set_free_next(second_block);

            second_block_storage.set_next(self.get_last_block(), true);

            last_block_storage.set_prev(second_block);

            return self;
        }
        pub const Check = enum { ok, leak, fragmented };

        /// This function can be called to check if the heap ended up fragmented or
        /// if there were leaks
        pub fn deinit(self: *Self) Check {
            const first_block = Block.first;
            const last_block = self.get_last_block();

            var blocks_count: usize = 0;
            var total_free_count: usize = 1; // add one for the last block which is not marked as free

            var current_block = self.get_block(0);

            while (true) {
                blocks_count += 1;
                const next_block = current_block.next(self);

                const block_size = if (current_block == last_block) 1 else @intFromEnum(next_block) - @intFromEnum(current_block);

                if (current_block.get_storage(self).is_free())
                    total_free_count += block_size;

                current_block = next_block;
                if (current_block == first_block) break;
            }

            if (total_free_count != self.heap.len)
                return .leak;

            if (blocks_count != 3)
                return .fragmented;

            return .ok;
        }

        pub fn allocator(self: *Self) std.mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }

        fn alloc(ctx: *anyopaque, len: usize, log2_align: u8, ret_addr: usize) ?[*]u8 {
            _ = ret_addr;
            const self = @as(*Self, @ptrCast(@alignCast(ctx)));

            var target_blocks_count = Block.calculate_number_of_blocks(len);

            var best_block: Block = .first;
            var best_size: BlockIndexType = 0x7fff;
            var best_adjusted_addr: usize = 0;

            var current = self.get_block(0).free_next(self);

            loop: while (current != Block.first) {
                const next_block = current.next(self);
                const blocks_count = @intFromEnum(next_block) - @intFromEnum(current);

                if (config.debug_logging)
                    logger.debug("Looking at block {} size {}", .{ current, blocks_count });

                const current_storage = current.get_storage(self);

                const addr = @intFromPtr(&current_storage.body.data);
                const adjusted_addr = std.mem.alignForwardLog2(addr, log2_align);

                target_blocks_count = Block.calculate_number_of_blocks(adjusted_addr - addr + len);

                switch (config.block_selection_method) {
                    .BestFit => {
                        if ((blocks_count >= target_blocks_count) and (blocks_count < best_size)) {
                            best_block = current;
                            best_size = blocks_count;
                            best_adjusted_addr = adjusted_addr;
                        }
                    },
                    .FirstFit => {
                        if (blocks_count >= target_blocks_count) {
                            best_block = current;
                            best_size = blocks_count;
                            best_adjusted_addr = adjusted_addr;
                            break :loop;
                        }
                    },
                }

                if (best_size == target_blocks_count)
                    break;

                current = current.free_next(self);
            }

            if (best_block == .first or best_block == self.get_last_block()) {
                return null; // OOM
            }

            if (config.debug_logging)
                logger.debug("Found {} with size {}", .{ best_block, best_size });

            const best_block_storage = best_block.get_storage(self);
            if (best_size == target_blocks_count) {
                if (config.debug_logging)
                    logger.debug("Allocating {} blocks starting at {} - exact", .{ target_blocks_count, best_block });
                best_block_storage.disonnect_from_freelist(self);
            } else {
                if (config.debug_logging)
                    logger.debug("Allocating {} blocks starting at {} - splitting", .{ target_blocks_count, best_block });

                const new_block = best_block_storage.split(best_block, self, target_blocks_count);
                const new_block_storage = new_block.get_storage(self);

                best_block_storage.free_prev().get_storage(self).set_free_next(new_block);
                new_block_storage.set_free_prev(best_block_storage.free_prev());

                best_block_storage.free_next().get_storage(self).set_free_prev(new_block);
                new_block_storage.set_free_next(best_block_storage.free_next());

                best_block_storage.set_next(best_block_storage.next(), false);
            }

            return @ptrFromInt(best_adjusted_addr);
        }

        fn resize(ctx: *anyopaque, buf: []u8, log2_align: u8, new_len: usize, ret_addr: usize) bool {
            const self = @as(*Self, @ptrCast(@alignCast(ctx)));
            _ = self;
            _ = buf;
            _ = log2_align;
            _ = new_len;
            _ = ret_addr;
            return false;
        }

        fn free(ctx: *anyopaque, buf: []u8, log2_align: u8, ret_addr: usize) void {
            _ = log2_align;
            _ = ret_addr;
            const self = @as(*Self, @ptrCast(@alignCast(ctx)));

            const addr = @intFromPtr(buf.ptr) - @offsetOf(Block.Storage, "body");
            const aligned_addr = std.mem.alignBackward(usize, addr, @alignOf(Block.Storage));

            const block = self.get_block(@intCast(@divFloor(aligned_addr - @intFromPtr(self.heap.ptr), @sizeOf(Block.Storage))));
            const block_storage = block.get_storage(self);

            std.debug.assert(!block_storage.is_free()); // double free

            if (config.debug_logging)
                logger.debug("Freeing {}", .{block});

            block_storage.assimilate_up(block, self);

            // TODO: assimilate_down
            const prev_block = block_storage.prev();
            if (prev_block != Block.first and prev_block.get_storage(self).is_free()) {
                block_storage.assimilate_down(self, true);
            } else {
                if (config.debug_logging)
                    logger.debug("Just add to head of free list", .{});

                const first = Block.first;
                const first_storage = first.get_storage(self);

                const first_next = first_storage.free_next();
                const first_next_storage = first_next.get_storage(self);

                first_next_storage.set_free_prev(block);
                block_storage.set_free_next(first_next);

                block_storage.set_free_prev(first);
                first_storage.set_free_next(block);

                block_storage.set_next(block_storage.next(), true);
            }
        }

        fn dump_heap(self: *const Self) void {
            var current = self.get_block(0);
            const last = self.get_last_block();
            while (true) {
                const next_block = current.next(self);

                const block_size = if (current == last) 1 else @intFromEnum(next_block) - @intFromEnum(current);
                if (config.debug_logging)
                    logger.debug("{} = {} size: {}", .{ current, current.get_storage(self), block_size });
                current = next_block;
                if (current == Block.first) break;
            }
        }

        inline fn get_block(_: Self, index: BlockIndexType) Block {
            return @enumFromInt(@as(BlockIndexType, @intCast(index)));
        }

        fn get_last_block(self: Self) Block {
            return @enumFromInt(@as(BlockIndexType, @intCast(self.heap.len - 1)));
        }

        const BlockIndexType = u16;
        const Block = enum(BlockIndexType) {
            first = 0,
            _,

            const FreeListMask: BlockIndexType = 0x8000;
            const BlockNumberMask: BlockIndexType = 0x7fff;

            const Storage = extern struct {
                const PointerPair = extern struct {
                    next: Block,
                    prev: Block,
                };

                const Header = extern union {
                    used: PointerPair,
                };

                const Body = extern union {
                    free: PointerPair,
                    data: [(config.block_body_size - @sizeOf(Header))]u8,
                };

                header: Header,
                body: Body,

                fn is_free(self: *const Storage) bool {
                    return @intFromEnum(self.header.used.next) & FreeListMask == FreeListMask;
                }

                fn next(self: *const Storage) Block {
                    return @enumFromInt(@as(BlockIndexType, @intCast(@intFromEnum(self.header.used.next) & BlockNumberMask)));
                }

                fn set_next(self: *Storage, next_: Block, free_: bool) void {
                    self.header.used.next = if (free_) next_.get_marked_as_free() else next_.get_marked_as_used();
                }

                fn set_next_raw(self: *Storage, next_: Block) void {
                    self.header.used.next = next_;
                }

                fn prev(self: *const Storage) Block {
                    return @enumFromInt(@as(BlockIndexType, @intCast(@intFromEnum(self.header.used.prev) & BlockNumberMask)));
                }

                fn set_prev(self: *Storage, prev_: Block) void {
                    self.header.used.prev = prev_;
                }

                fn free_next(self: *const Storage) Block {
                    std.debug.assert(self.is_free());
                    return self.body.free.next;
                }

                fn set_free_next(self: *Storage, next_: Block) void {
                    self.body.free.next = next_;
                }

                fn free_prev(self: *const Storage) Block {
                    std.debug.assert(self.is_free());
                    return self.body.free.prev;
                }

                fn set_free_prev(self: *Storage, prev_: Block) void {
                    self.body.free.prev = prev_;
                }

                inline fn split(self: *Storage, self_block: Block, umm: *Self, blocks: usize) Block {
                    const new_block = umm.get_block(@intCast(@intFromEnum(self_block) + blocks));
                    const new_block_storage = new_block.get_storage(umm);

                    new_block_storage.set_next(self.next(), true);
                    new_block_storage.set_prev(self_block);

                    self.next().get_storage(umm).set_prev(new_block);
                    self.set_next(new_block, true);

                    return new_block;
                }

                inline fn disonnect_from_freelist(self: *Storage, umm: *const Self) void {
                    const prev_block = self.free_prev();
                    const prev_storage = prev_block.get_storage(umm);

                    const next_block = self.free_next();
                    const next_storage = next_block.get_storage(umm);

                    prev_storage.set_free_next(next_block);
                    next_storage.set_free_prev(prev_block);

                    self.set_next(self.next(), true);
                }

                inline fn assimilate_up(self: *Storage, self_block: Block, umm: *const Self) void {
                    const next_block = self.next();
                    const next_block_storage = next_block.get_storage(umm);

                    if (next_block_storage.is_free()) {
                        if (config.debug_logging)
                            logger.debug("Assimilate up to next block, which is FREE", .{});

                        next_block_storage.disonnect_from_freelist(umm);

                        const next_next_block = next_block_storage.next();
                        const next_next_block_storage = next_next_block.get_storage(umm);
                        next_next_block_storage.set_prev(self_block);
                        self.set_next_raw(next_next_block);
                    }
                }

                fn assimilate_down(self: *Storage, umm: *const Self, as_free: bool) void {
                    const prev_block = self.prev();
                    const prev_block_storage = prev_block.get_storage(umm);

                    const next_block = self.next();
                    const next_block_storage = next_block.get_storage(umm);

                    prev_block_storage.set_next(self.next(), as_free);
                    next_block_storage.set_prev(self.prev());
                }

                pub fn format(value: Storage, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
                    _ = fmt;
                    _ = options;
                    try writer.print("Storage(prev: {} next: {}", .{
                        value.prev(),
                        value.next(),
                    });

                    if (value.is_free()) {
                        try writer.print(" free_prev: {} free_next: {})", .{
                            value.free_prev(),
                            value.free_next(),
                        });
                    }

                    try writer.print(")", .{});
                }
            };

            fn get_storage(self: Block, umm: *const Self) *Storage {
                return &umm.heap[@intFromEnum(self)];
            }

            fn calculate_number_of_blocks(size: usize) BlockIndexType {
                if (size <= @sizeOf(Storage.Body))
                    return 1;

                const temp = size - @sizeOf(Storage.Body);
                const blocks = (2 + ((temp)) / @sizeOf(Storage));

                if (blocks > std.math.maxInt(BlockIndexType))
                    return std.math.maxInt(BlockIndexType);

                return @truncate(blocks);
            }

            fn next(self: Block, umm: *const Self) Block {
                return self.get_storage(umm).next();
            }

            fn prev(self: Block, umm: *const Self) Block {
                return self.get_storage(umm).header.used.prev & BlockNumberMask;
            }

            fn free_next(self: Block, umm: *const Self) Block {
                const storage = self.get_storage(umm);
                return storage.free_next();
            }

            fn free_prev(self: Block, umm: *const Self) Block {
                const storage = self.get_storage(umm);
                return storage.free_prev();
            }

            fn get_marked_as_free(self: Block) Block {
                return @enumFromInt(@as(BlockIndexType, @intCast(@intFromEnum(self) | Block.FreeListMask)));
            }

            fn get_marked_as_used(self: Block) Block {
                return @enumFromInt(@as(BlockIndexType, @intCast(@intFromEnum(self) & Block.BlockNumberMask)));
            }

            pub fn format(value: Block, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
                _ = fmt;
                _ = options;
                try writer.print("Block({})", .{@intFromEnum(value)});
            }
        };
    };
}
const FreeOrder = enum {
    normal,
    reversed,
    random,
};
fn umm_test_type(comptime T: type, comptime free_order: FreeOrder) !void {
    const Umm = UmmAllocator(.{});
    var buf: [std.math.maxInt(u15) * 8]u8 align(16) = undefined;
    var umm = try Umm.init(&buf);
    defer std.testing.expect(umm.deinit() == .ok) catch @panic("leak");
    const allocator = umm.allocator();

    var list = std.ArrayList(*T).init(if (@import("builtin").is_test) testing.allocator else std.heap.page_allocator);
    defer list.deinit();

    var i: usize = 0;
    while (i < 1024) : (i += 1) {
        const ptr = try allocator.create(T);
        @memset(std.mem.asBytes(ptr), 0x41);
        try list.append(ptr);
    }

    switch (free_order) {
        .normal => {
            for (list.items) |ptr| {
                try testing.expect(std.mem.allEqual(u8, std.mem.asBytes(ptr), 0x41));
                allocator.destroy(ptr);
            }
        },
        .reversed => {
            while (list.popOrNull()) |ptr| {
                try testing.expect(std.mem.allEqual(u8, std.mem.asBytes(ptr), 0x41));
                allocator.destroy(ptr);
            }
        },
        .random => {
            var ascon = std.rand.Ascon.init([_]u8{0x42} ** 32);
            const rand = ascon.random();

            while (list.getLastOrNull()) |_| {
                const ptr = list.swapRemove(rand.intRangeAtMost(usize, 0, list.items.len - 1));
                try testing.expect(std.mem.allEqual(u8, std.mem.asBytes(ptr), 0x41));
                allocator.destroy(ptr);
            }
        },
    }
}

test "u16 allocations - free in same order" {
    try umm_test_type(u16, .normal);
}
test "u16 allocations - free in reverse order" {
    try umm_test_type(u16, .reversed);
}
test "u16 allocations - free in random order" {
    try umm_test_type(u16, .random);
}

test "u32 allocations - free in same order" {
    try umm_test_type(u32, .normal);
}
test "u32 allocations - free in reverse order" {
    try umm_test_type(u32, .reversed);
}
test "u32 allocations - free in random order" {
    try umm_test_type(u32, .random);
}

test "u64 allocations - free in same order" {
    try umm_test_type(u64, .normal);
}
test "u64 allocations - free in reverse order" {
    try umm_test_type(u64, .reversed);
}
test "u64 allocations - free in random order" {
    try umm_test_type(u64, .random);
}

const Foo = struct {
    a: []u8,
    b: u32,
    c: u64,
};
test "Foo allocations - free in same order" {
    try umm_test_type(Foo, .normal);
}
test "Foo allocations - free in reverse order" {
    try umm_test_type(Foo, .reversed);
}
test "Foo allocations - free in random order" {
    try umm_test_type(Foo, .random);
}

fn umm_test_random_size(comptime free_order: FreeOrder) !void {
    const Umm = UmmAllocator(.{});
    var buf: [std.math.maxInt(u15) * 8]u8 align(16) = undefined;
    var umm = try Umm.init(&buf);
    defer std.testing.expect(umm.deinit() == .ok) catch @panic("leak");
    const allocator = umm.allocator();

    var list = std.ArrayList([]u8).init(if (@import("builtin").is_test) testing.allocator else std.heap.page_allocator);
    defer list.deinit();

    var ascon = std.rand.Ascon.init([_]u8{0x42} ** 32);
    const rand = ascon.random();

    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const size = rand.intRangeLessThanBiased(usize, 0, 1024);
        const ptr = try allocator.alloc(u8, size);
        @memset(ptr, 0x41);
        try list.append(ptr);
    }

    switch (free_order) {
        .normal => {
            for (list.items) |ptr| {
                try testing.expect(std.mem.allEqual(u8, ptr, 0x41));
                allocator.free(ptr);
            }
        },
        .reversed => {
            while (list.popOrNull()) |ptr| {
                try testing.expect(std.mem.allEqual(u8, ptr, 0x41));
                allocator.free(ptr);
            }
        },
        .random => {
            while (list.getLastOrNull()) |_| {
                const ptr = list.swapRemove(rand.intRangeAtMost(usize, 0, list.items.len - 1));
                try testing.expect(std.mem.allEqual(u8, ptr, 0x41));
                allocator.free(ptr);
            }
        },
    }
}

test "random size allocations - free in same order" {
    try umm_test_random_size(.normal);
}
test "random size allocations - free in reverse order" {
    try umm_test_random_size(.reversed);
}
test "random size allocations - free in random order" {
    try umm_test_random_size(.random);
}

// fn umm_test_random_size_and_random_alignment(comptime free_order: FreeOrder) !void {
//     const Umm = UmmAllocator(.{});
//     var buf: [std.math.maxInt(u15) * 8]u8 align(16) = undefined;
//     var umm = try Umm.init(&buf);
//     defer std.testing.expect(umm.deinit() == .ok) catch @panic("leak");
//     const allocator = umm.allocator();

//     var list = std.ArrayList([]u8).init(if (@import("builtin").is_test) testing.allocator else std.heap.page_allocator);
//     defer list.deinit();

//     var ascon = std.rand.Ascon.init([_]u8{0x42} ** 32);
//     const rand = ascon.random();

//     var i: usize = 0;
//     while (i < 256) : (i += 1) {
//         const size = rand.intRangeLessThanBiased(usize, 0, 1024);
//         const alignment = std.math.pow(u20, 2, rand.intRangeAtMostBiased(u20, 0, 5));
//         const ptr = try allocator.allocWithOptions(u8, size, alignment, null);
//         @memset(ptr, 0x41);
//         try list.append(ptr);
//     }

//     switch (free_order) {
//         .normal => {
//             for (list.items) |ptr| {
//                 try testing.expect(std.mem.allEqual(u8, ptr, 0x41));
//                 allocator.free(ptr);
//             }
//         },
//         .reversed => {
//             while (list.popOrNull()) |ptr| {
//                 try testing.expect(std.mem.allEqual(u8, ptr, 0x41));
//                 allocator.free(ptr);
//             }
//         },
//         .random => {
//             while (list.getLastOrNull()) |_| {
//                 const ptr = list.swapRemove(rand.intRangeAtMost(usize, 0, list.items.len - 1));
//                 try testing.expect(std.mem.allEqual(u8, ptr, 0x41));
//                 allocator.free(ptr);
//             }
//         },
//     }
// }
// test "random size allocations with random alignment - free in same order" {
//     try umm_test_random_size_and_random_alignment(.normal);
// }
// test "random size allocations with random alignment - free in reverse order" {
//     try umm_test_random_size_and_random_alignment(.reversed);
// }
// test "random size allocations with random alignment - free in random order" {
//     try umm_test_random_size_and_random_alignment(.random);
// }
