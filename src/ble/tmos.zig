const c = @import("../lib/ch583.zig");

const TmosTaskId = c.tmosTaskID;

pub fn init() !void {
    const err = c.TMOS_TimerInit(null);
    if (err == c.FAILURE) {
        return error.Failure;
    }
}
