const std = @import("std");
const assert = std.debug.assert;

pub fn Hana(comptime T: type, comptime col_indices: [32]CollectionIndex) type {
    return struct {
        value: *align(1) const T,
        collections: [32][]const u8,

        const Self = @This();

        pub const Indices = blk: {
            var types: [32]type = undefined;
            for (col_indices, 0..) |col_index, i| {
                if (col_index.Index == void) {
                    types[i] = @TypeOf(null);
                } else {
                    types[i] = LazyIndexed(i, col_index.T, col_index.Index, Self);
                }
            }
            break :blk types;
        };

        fn EncodingType(comptime U: type) type {
            switch (@typeInfo(U)) {
                .Struct => |s| {
                    if (@hasDecl(U, "HanaInnerType")) {
                        return EncodingType(U.HanaInnerType);
                    }

                    return @Type(std.builtin.Type{ .Struct = .{
                        .decls = &.{},
                        .is_tuple = false,
                        .layout = .Auto,
                        .fields = comptime blk: {
                            var new_fields: [s.fields.len]std.builtin.Type.StructField = undefined;

                            inline for (s.fields, 0..) |f, i| {
                                new_fields[i] = .{
                                    .name = f.name,
                                    .type = EncodingType(f.type),
                                    .default_value = f.default_value,
                                    .is_comptime = f.is_comptime,
                                    .alignment = f.alignment,
                                };
                            }

                            break :blk &new_fields;
                        },
                    } });
                },
                .Union => |s| {
                    return @Type(std.builtin.Type{ .Union = .{
                        .decls = &.{},
                        .tag_type = s.tag_type,
                        .layout = .Auto,
                        .fields = comptime blk: {
                            var new_fields: [s.fields.len]std.builtin.Type.UnionField = undefined;

                            inline for (s.fields, 0..) |f, i| {
                                new_fields[i] = .{
                                    .name = f.name,
                                    .type = EncodingType(f.type),
                                    .alignment = f.alignment,
                                };
                            }

                            break :blk &new_fields;
                        },
                    } });
                },
                .Array => |a| {
                    return @Type(std.builtin.Type{ .Array = .{
                        .child = EncodingType(a.child),
                        .len = a.len,
                        .sentinel = a.sentinel,
                    } });
                },
                else => return U,
            }
        }

        pub fn deserialize(bytes: []const u8) Self {
            var byte_offset: usize = @sizeOf(T);
            var collections: [32][]const u8 = undefined;

            inline for (col_indices, 0..) |col_index, i| {
                if (col_index.Index == void) {
                    collections[i] = bytes[byte_offset..byte_offset];
                } else {
                    var len_bytes: [@sizeOf(col_index.Index)]u8 = undefined;
                    @memcpy(&len_bytes, bytes[byte_offset .. byte_offset + @sizeOf(col_index.Index)]);

                    const len = std.mem.readInt(col_index.Index, &len_bytes, .Little);
                    const byte_count: usize = len * @sizeOf(col_index.T);
                    byte_offset += @sizeOf(col_index.Index);

                    std.debug.print("{}: {}-{}\n", .{ i, byte_offset, len });

                    collections[i] = bytes[byte_offset .. byte_offset + byte_count];
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

        pub fn serialize(stream: anytype, obj: EncodingType(T), child_allocator: std.mem.Allocator) !void {
            var arena = std.heap.ArenaAllocator.init(child_allocator);
            defer arena.deinit();

            var allocator = arena.allocator();

            var collections: [32]*anyopaque = undefined;
            inline for (&collections, 0..) |*col, i| {
                const list = try allocator.create(CollectionList(i));
                list.* = CollectionList(i).init(allocator);
                col.* = list;
            }

            const u = serializeInner(T, obj, &collections);
            std.debug.print("{any}\n", .{u});

            try stream.writeAll(&std.mem.toBytes(u));

            inline for (&collections, 0..) |col, i| {
                const Index = col_indices[i].Index;

                if (Index != void) {
                    const list: *CollectionList(i) = @alignCast(@ptrCast(col));
                    try stream.writeAll(&std.mem.toBytes(.{@as(Index, @intCast(list.items.len))}));

                    for (list.items) |e| {
                        try stream.writeAll(&std.mem.toBytes(e));
                    }
                }
            }
        }

        fn serializeInner(comptime U: type, obj: EncodingType(U), collections: *[32]*anyopaque) U {
            if (comptime isContainerType(U)) {
                if (@hasDecl(U, "HanaInnerType")) {
                    const u = serializeInner(U.HanaInnerType.Inner, obj.value, collections);
                    const tag = U.HanaInnerType.CollectionTag;

                    const col: *CollectionList(tag) = @alignCast(@ptrCast(collections[tag]));
                    col.append(u) catch unreachable;

                    return U{ .idx = @intCast(col.items.len - 1) };
                } else {
                    var u: U = undefined;

                    inline for (std.meta.fields(U)) |field| {
                        @field(u, field.name) = serializeInner(field.type, @field(obj, field.name), collections);
                    }

                    return u;
                }
            }

            switch (@typeInfo(U)) {
                .Array => |a| {
                    var u: U = undefined;

                    for (0..a.len) |i| {
                        u[i] = serializeInner(a.child, obj[i], collections);
                    }

                    return u;
                },
                .Union => {
                    inline for (std.meta.fields(U)) |field| {
                        if (std.mem.eql(u8, @tagName(obj), field.name)) {
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

fn LazyIndexed(comptime tag: u5, comptime T: type, comptime Index: type, comptime Root: type) type {
    assert(Index == u8 or Index == u16 or Index == u32);

    return packed struct(Index) {
        idx: Index,

        pub const HanaInnerType = struct {
            value: T,

            pub const Inner = T;
            pub const CollectionTag = tag;
        };

        pub const Self = @This();

        fn get(self: Self, root: *const Root) T {
            const col: [*]align(1) const T = @ptrCast(root.collections[tag]);
            const col_slice = col[0..(root.collections[tag].len / @sizeOf(T))];
            return col_slice[self.idx];
        }
    };
}

pub const CollectionIndex = struct {
    T: type = void,
    Index: type = void,
};

const c = blk: {
    var cc = [_]CollectionIndex{.{}} ** 32;
    cc[0] = .{ .T = Keymap.Keycode, .Index = u16 };
    cc[1] = .{ .T = Keymap.Behavior, .Index = u16 };
    cc[2] = .{ .T = Keymap.HoldTapProps, .Index = u8 };
    // cc[1] = .{ .T = u16, .Index = u16 };
    // cc[2] = .{ .T = Keymap.Header, .Index = u8 };
    break :blk cc;
};
const R = Hana(Keymap, c);

fn isContainerType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Struct => true,
        else => false,
    };
}

const Keymap = struct {
    header: Header,
    key_defs: R.Indices[1],

    pub const Header = packed struct(u32) {
        magic: u16,
        version: u16,
    };

    pub const Keycode = u16;

    pub const Behavior = union(enum) {
        key_press: R.Indices[0],
        hold_tap: packed struct {
            hold: R.Indices[1],
            props: R.Indices[2],
        },
    };

    pub const HoldTapProps = packed struct {
        timeout_ms: u16,
    };
};

test {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    R.serialize(
        buf.writer(),
        .{
            .header = .{
                .magic = 6969,
                .version = 43,
            },
            .key_defs = .{ .value = .{ .key_press = .{ .value = 4 } } },
        },
        std.testing.allocator,
    ) catch unreachable;

    std.debug.print("y{any}\n", .{buf.items});

    const r = R.deserialize(buf.items);
    std.debug.print("yo: {any}\n", .{r.value.key_defs.get(&r).key_press.get(&r)});
}
