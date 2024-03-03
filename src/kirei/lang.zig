const Engine = @import("engine.zig").Engine;
const KeyCode = @import("keymap.zig").KeyCode;

pub fn Expression(comptime T: type) type {
    return union(enum) {
        literal: T,
        swt: Switch(T),

        const Self = @This();

        pub fn resolve(self: Self, engine: *const Engine) T {
            return switch (self) {
                .literal => |v| v,
                .swt => |swt| swt.resolve(engine),
            };
        }
    };
}

pub fn Switch(comptime T: type) type {
    return struct {
        branches: []const Branch,
        fallback: T,

        const Self = @This();

        const Branch = struct {
            condition: Condition,
            value: Expression(T),
        };

        pub fn resolve(self: Self, engine: *const Engine) T {
            for (self.branches) |branch| {
                if (branch.condition.resolve(engine))
                    return branch.value.resolve(engine);
            }
            return self.fallback;
        }
    };
}

pub const Condition = union(enum) {
    literal: bool,
    query: Query,
    // logical_not: Condition,
    logical_and: []const Condition,
    logical_or: []const Condition,

    pub fn resolve(self: Condition, engine: *const Engine) bool {
        switch (self) {
            .literal => |b| return b,
            .query => |query| {
                return query.resolve(engine);
            },
            // .logical_not => |cond| {
            //     return !cond.resolve(engine);
            // },
            .logical_and => |conditions| {
                for (conditions) |cond| {
                    if (!cond.resolve(engine))
                        return false;
                }
                return true;
            },
            .logical_or => |conditions| {
                for (conditions) |cond| {
                    if (cond.resolve(engine))
                        return true;
                }
                return false;
            },
        }
    }
};

pub const Query = union(enum) {
    is_pressed: KeyCode,

    pub fn resolve(self: Query, engine: *const Engine) bool {
        switch (self) {
            .is_pressed => |key_code| {
                return engine.output_hid.isPressed(key_code);
            },
        }
    }
};
