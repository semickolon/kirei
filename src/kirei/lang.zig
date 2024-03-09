const eng = @import("engine.zig");
const keymap = @import("keymap.zig");
const output_hid = @import("output_hid.zig");

const Engine = eng.Engine;
const KeyIndex = eng.KeyIndex;
const KeyCode = keymap.KeyCode;
const KeyPattern = output_hid.KeyPattern;

// TODO: Fix duplication of resolution code. Unify runtime and compile-time.

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

        pub fn resolveFn(comptime self: Self) @TypeOf(&Comptime(self).resolve) {
            return &Comptime(self).resolve;
        }

        fn Comptime(comptime self: Self) type {
            return struct {
                fn resolve(engine: *const Engine) T {
                    return switch (self) {
                        .literal => |v| v,
                        .swt => |swt| (comptime swt.resolveFn())(engine),
                    };
                }
            };
        }
    };
}

pub fn Switch(comptime T: type) type {
    return struct {
        branches: []const Branch,
        fallback: T,

        const Self = @This();

        pub const Branch = struct {
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

        pub fn resolveFn(comptime self: Self) @TypeOf(&Comptime(self).resolve) {
            return &Comptime(self).resolve;
        }

        fn Comptime(comptime self: Self) type {
            return struct {
                fn resolve(engine: *const Engine) T {
                    inline for (self.branches) |branch| {
                        if ((comptime branch.condition.resolveFn())(engine))
                            return (comptime branch.value.resolveFn())(engine);
                    }
                    return self.fallback;
                }
            };
        }
    };
}

pub const Condition = union(enum) {
    literal: bool,
    query: Query,
    logical_not: *const Condition,
    logical_and: []const Condition,
    logical_or: []const Condition,

    pub fn resolve(self: Condition, engine: *const Engine) bool {
        switch (self) {
            .literal => |b| return b,
            .query => |query| {
                return query.resolve(engine);
            },
            .logical_not => |cond| {
                return !cond.resolve(engine);
            },
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

    pub fn resolveFn(comptime self: Condition) @TypeOf(&Comptime(self).resolve) {
        return &Comptime(self).resolve;
    }

    fn Comptime(comptime self: Condition) type {
        return struct {
            fn resolve(engine: *const Engine) bool {
                switch (self) {
                    .literal => |b| return b,
                    .query => |query| {
                        return (comptime query.resolveFn())(engine);
                    },
                    .logical_not => |cond| {
                        return !(comptime cond.resolveFn())(engine);
                    },
                    .logical_and => |conditions| {
                        // TODO: Is there a way to do this like `if (x and y and z and ...)`?
                        // Or does the compiler know how to optimize this?
                        inline for (conditions) |cond| {
                            if (!(comptime cond.resolveFn())(engine))
                                return false;
                        }
                        return true;
                    },
                    .logical_or => |conditions| {
                        // TODO: Is there a way to do this like `if (x or y or z or ...)`?
                        // Or does the compiler know how to optimize this?
                        inline for (conditions) |cond| {
                            if ((comptime cond.resolveFn())(engine))
                                return true;
                        }
                        return false;
                    },
                }
            }
        };
    }
};

pub const Query = union(enum) {
    is_pressed: KeyPattern,
    is_key_pressed: KeyIndex,

    pub fn resolve(self: Query, engine: *const Engine) bool {
        switch (self) {
            .is_pressed => |pattern| return engine.output_hid.matches(pattern),
            .is_key_pressed => |key_idx| return engine.isKeyPressed(key_idx),
        }
    }

    pub fn resolveFn(comptime self: Query) @TypeOf(&Comptime(self).resolve) {
        return &Comptime(self).resolve;
    }

    fn Comptime(comptime self: Query) type {
        return struct {
            fn resolve(engine: *const Engine) bool {
                switch (self) {
                    .is_pressed => |pattern| return engine.output_hid.matches(pattern),
                    .is_key_pressed => |key_idx| return engine.isKeyPressed(key_idx),
                }
            }
        };
    }
};
