const std = @import("std");
const assert = std.debug.assert;

pub const CollectionIndex = struct {
    T: type = void,
    Index: type = void,
};

pub fn Hana(comptime T: type, comptime col_indices: []const CollectionIndex) type {
    return struct {
        value: *align(4) const T,
        collections: [col_indices.len][]align(4) const u8,

        const Self = @This();

        pub const Indices = blk: {
            var types: [32]type = undefined;
            for (col_indices, 0..) |col_index, i| {
                if (col_index.Index == void) {
                    types[i] = @TypeOf(null);
                } else {
                    types[i] = struct {
                        pub const Single = LazyIndexed(i, col_index.T, col_index.Index, Self);
                        pub const Slice = LazySlice(i, col_index.T, col_index.Index, Self);
                    };
                }
            }
            break :blk types;
        };

        pub fn deserialize(bytes: []align(4) const u8) Self {
            var byte_offset: usize = @sizeOf(T);
            var collections: [col_indices.len][]align(4) const u8 = undefined;

            inline for (col_indices, 0..) |col_index, i| {
                if (col_index.Index == void) {
                    collections[i] = bytes[0..0];
                } else {
                    var len_bytes: [@sizeOf(col_index.Index)]u8 = undefined;
                    @memcpy(&len_bytes, bytes[byte_offset .. byte_offset + @sizeOf(col_index.Index)]);

                    const len = std.mem.readInt(col_index.Index, &len_bytes, .Little);
                    const byte_count: usize = len * @sizeOf(col_index.T);
                    byte_offset += @sizeOf(col_index.Index);

                    while (byte_offset % 4 != 0) {
                        byte_offset += 1;
                    }

                    collections[i] = @alignCast(bytes[byte_offset .. byte_offset + byte_count]);
                    byte_offset += byte_count;
                }
            }

            return .{
                .value = @ptrCast(&bytes[0]),
                .collections = collections,
            };
        }

        fn CollectionList(comptime tag: u5) type {
            return std.ArrayList(col_indices[tag].T);
        }

        pub fn serialize(stream: anytype, obj: anytype, child_allocator: std.mem.Allocator) !void {
            var arena = std.heap.ArenaAllocator.init(child_allocator);
            defer arena.deinit();

            var allocator = arena.allocator();

            var collections: [col_indices.len]*anyopaque = undefined;
            inline for (&collections, 0..) |*col, i| {
                const list = try allocator.create(CollectionList(i));
                list.* = CollectionList(i).init(allocator);
                col.* = list;
            }

            const writer = struct {
                var byte_offset: usize = 0;

                fn write(s: anytype, bytes: []const u8) !void {
                    try s.writeAll(bytes);
                    byte_offset += bytes.len;
                }

                fn alignTo(s: anytype, bytes: usize) !void {
                    while (byte_offset % bytes != 0) {
                        try write(s, &.{0});
                    }
                }
            };

            const u = serializeInner(T, obj, &collections);
            try writer.write(stream, &std.mem.toBytes(u));

            inline for (&collections, 0..) |col, i| {
                const Index = col_indices[i].Index;

                if (Index != void) {
                    const list: *CollectionList(i) = @alignCast(@ptrCast(col));
                    try writer.write(stream, &std.mem.toBytes(.{@as(Index, @intCast(list.items.len))}));
                    try writer.alignTo(stream, 4);

                    for (list.items) |e| {
                        try writer.write(stream, &std.mem.toBytes(e));
                    }
                }
            }
        }

        fn serializeInner(comptime U: type, obj: anytype, collections: *[col_indices.len]*anyopaque) U {
            if (comptime isContainerType(U)) {
                if (@hasDecl(U, "HanaInnerType")) {
                    const tag = U.HanaInnerType.collection_tag;
                    const col: *CollectionList(tag) = @alignCast(@ptrCast(collections[tag]));

                    switch (@typeInfo(U.HanaInnerType.Inner)) {
                        .Pointer => |p| {
                            assert(p.size == .Slice);
                            const len = obj.value.len;
                            var yes: [len]p.child = undefined;

                            inline for (obj.value, 0..) |e, i| {
                                yes[i] = serializeInner(p.child, e, collections);
                            }

                            const idx = blk: {
                                // Compression
                                if (col.items.len >= len) {
                                    outer: for (0..col.items.len - len + 1) |i| {
                                        for (0..len) |j| {
                                            if (!std.meta.eql(yes[j], col.items[i + j]))
                                                continue :outer;
                                        }
                                        // std.debug.print("saved {any}B\n", .{len * @sizeOf(p.child)});
                                        break :blk i;
                                    }
                                }

                                defer col.appendSlice(&yes) catch unreachable;
                                break :blk col.items.len;
                            };

                            return U{
                                .len = @intCast(obj.value.len),
                                .idx = @intCast(idx),
                            };
                        },
                        else => {
                            const u = serializeInner(U.HanaInnerType.Inner, obj.value, collections);

                            const idx = blk: for (col.items, 0..) |e, i| {
                                // Compression
                                if (std.meta.eql(e, u))
                                    break :blk i;
                            } else {
                                defer col.append(u) catch unreachable;
                                break :blk col.items.len;
                            };

                            return U{ .idx = @intCast(idx) };
                        },
                    }
                } else {
                    var u = std.mem.zeroes(U);

                    inline for (std.meta.fields(U)) |field| {
                        @field(u, field.name) = serializeInner(field.type, @field(obj, field.name), collections);
                    }

                    return u;
                }
            }

            switch (@typeInfo(U)) {
                .Array => |a| {
                    var u = std.mem.zeroes(U);

                    for (0..a.len) |i| {
                        u[i] = serializeInner(a.child, obj[i], collections);
                    }

                    return u;
                },
                .Union => {
                    inline for (std.meta.fields(U)) |field| {
                        if (@hasField(@TypeOf(obj), field.name)) {
                            return @unionInit(
                                U,
                                field.name,
                                serializeInner(field.type, @field(obj, field.name), collections),
                            );
                        }
                    }
                    unreachable;
                },
                else => return obj,
            }
        }
    };
}

fn HanaInner(comptime tag: u5, comptime T: type) type {
    return struct {
        value: T,
        pub const Inner = T;
        pub const collection_tag = tag;
    };
}

fn LazyIndexed(comptime tag: u5, comptime T: type, comptime Index: type, comptime Root: type) type {
    assert(Index == u8 or Index == u16 or Index == u32);

    return packed struct(Index) {
        idx: Index,

        pub const Self = @This();
        pub const HanaInnerType = HanaInner(tag, T);

        pub fn get(self: Self, root: *const Root) T {
            const col: [*]align(4) const T = @ptrCast(root.collections[tag]);
            const col_slice = col[0..(root.collections[tag].len / @sizeOf(T))];
            return col_slice[self.idx];
        }
    };
}

fn LazySlice(comptime tag: u5, comptime T: type, comptime Index: type, comptime Root: type) type {
    assert(Index == u8 or Index == u16 or Index == u32);

    return packed struct {
        len: Index,
        idx: Index,

        pub const Self = @This();
        pub const HanaInnerType = HanaInner(tag, []T);

        pub fn slice(self: Self, root: *const Root) []align(1) const T {
            const col: [*]align(4) const T = @ptrCast(root.collections[tag]);
            const col_slice = col[0..(root.collections[tag].len / @sizeOf(T))];
            return col_slice[self.idx .. self.idx + self.len];
        }

        pub fn at(self: Self, root: *const Root, i: Index) T {
            return self.slice(root)[i];
        }
    };
}

fn isContainerType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Struct => true,
        else => false,
    };
}

// TODO: Add tests
