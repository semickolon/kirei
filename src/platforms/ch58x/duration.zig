pub const Duration = struct {
    micros: u32,

    pub const Millis = u23;
    pub const Secs = u13;

    pub fn fromMicros(micros: u16) Duration {
        return .{ .micros = micros };
    }

    pub fn fromMillis(millis: Millis) Duration {
        return .{ .micros = @as(u32, millis) * 1000 };
    }

    pub fn fromSecs(secs: Secs) Duration {
        return .{ .micros = @as(u32, secs) * 1000 * 1000 };
    }

    pub fn asMillis(self: Duration) Millis {
        return self.micros / 1000;
    }

    pub fn asSecs(self: Duration) Secs {
        return self.micros / 1000 / 1000;
    }

    pub fn add(self: Duration, other: Duration) Duration {
        return .{ .micros = self.micros + other.micros };
    }

    pub fn sub(self: Duration, other: Duration) Duration {
        return .{ .micros = self.micros - other.micros };
    }
};
