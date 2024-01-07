const std = @import("std");
const c = @import("../lib/ch583.zig");
const config = @import("../config.zig");
const UUID = @import("../lib/uuid.zig").UUID;
const tmos = @import("tmos.zig");

const systick = @import("../hal/systick.zig");
const rtc = @import("../hal/rtc.zig");
const pmu = @import("../hal/pmu.zig");
const interrupts = @import("../hal/interrupts.zig");

const isp = @cImport(@cInclude("ISP583.h"));
const n = @import("assigned_numbers.zig");

var memBuf: [config.ble.mem_heap_size / 4]u32 align(4) = undefined;
var cfg = std.mem.zeroes(c.bleConfig_t);

const WAKE_UP_RTC_MAX_TIME = 45; // ~1.4ms in 32KHz RTC cycles

// Are these sleep min, max values just by choice or is it the chip's limitations?
const SLEEP_RTC_MIN_TIME = 33; // ~1ms
const SLEEP_RTC_MAX_TIME = 2715440914; // RTC max 32K cycle (idk how long this is yet) minus 1hr

pub fn init() !void {
    try initBleModule();
    rtc.init();
    try tmos.init();

    pmu.setWakeUpEvent(.rtc, true);
    rtc.setTriggerMode(true);
    interrupts.set(.rtc, true);
}

pub fn process() void {
    c.TMOS_SystemProcess();
}

fn initBleModule() !void {
    cfg.MEMAddr = @intFromPtr(&memBuf);
    cfg.MEMLen = config.ble.mem_heap_size;
    cfg.BufMaxLen = config.ble.buf_max_len;
    cfg.BufNumber = config.ble.buf_number;
    cfg.TxNumEvent = config.ble.tx_num_event;
    cfg.TxPower = config.ble.tx_power;

    cfg.SNVAddr = 0x77E00 - 0x070000; // TODO: Why?
    cfg.readFlashCB = libReadFlash;
    cfg.writeFlashCB = libWriteFlash;

    cfg.SelRTCClock = 1; // 32KHz LSI

    cfg.ConnectNumber =
        (config.ble.peripheral_max_connections & 3) | (config.ble.central_max_connections << 2);

    cfg.srandCB = getSysTickCount;
    cfg.rcCB = c.Lib_Calibration_LSI;
    cfg.MacAddr = config.ble.mac_addr;

    cfg.WakeUpTime = WAKE_UP_RTC_MAX_TIME;
    cfg.sleepCB = enterSleep;

    const result = c.BLE_LibInit(&cfg);

    return switch (result) {
        c.SUCCESS => {},
        c.ERR_LLE_IRQ_HANDLE => error.LleIrqHandle,
        c.ERR_MEM_ALLOCATE_SIZE => error.MemAllocateSize,
        c.ERR_SET_MAC_ADDR => error.SetMacAddr,
        c.ERR_GAP_ROLE_CONFIG => error.GapRoleConfig,
        c.ERR_CONNECT_NUMBER_CONFIG => error.ConnectNumberConfig,
        c.ERR_SNV_ADDR_CONFIG => error.SnvAddrConfig,
        c.ERR_CLOCK_SELECT_CONFIG => error.ClockSelectConfig,
        else => unreachable,
    };
}

fn cu32(num: u32) c_long {
    return @intCast(num);
}

fn libReadFlash(addr: u32, num: u32, pBuf: [*c]u32) callconv(.C) u32 {
    _ = isp.EEPROM_READ(cu32(addr), pBuf, cu32(num * 4));
    return 0;
}

fn libWriteFlash(addr: u32, num: u32, pBuf: [*c]u32) callconv(.C) u32 {
    _ = isp.EEPROM_ERASE(cu32(addr), cu32(num * 4));
    _ = isp.EEPROM_WRITE(cu32(addr), pBuf, cu32(num * 4));
    return 0;
}

fn getSysTickCount() callconv(.C) u32 {
    return @truncate(systick.count());
}

fn enterSleep(time: u32) callconv(.C) u32 {
    {
        interrupts.globalSet(false);
        defer interrupts.globalSet(true);

        // TODO: This is so C. Let's represent time units like `Duration` in Rust.
        const time_curr = rtc.getTime();
        const sleep_dur = if (time < time_curr)
            time + (rtc.MAX_CYCLE_32K - time_curr)
        else
            time - time_curr;

        if (sleep_dur < SLEEP_RTC_MIN_TIME or sleep_dur > SLEEP_RTC_MAX_TIME) {
            return 2;
        }

        rtc.setTriggerTime(time);
    }

    // There's a possibility that, right here, RTC interrupt may have just been triggered.
    // In that case, there's no more need to sleep. We return early to prevent sleeping.
    if (rtc.isTriggerTimeActivated() and false) {
        return 3; // No documentation on what 3 means.
    }

    pmu.sleepDeep(.{
        .ram_2k = true,
        .ram_30k = true,
        .extend = true,
    });

    if (!rtc.isTriggerTimeActivated()) {
        // We're woken up by something *other than* the RTC interrupt.
        // In this case, the 32MHz oscillator is not stable right now.
        // We need to sleep idle (non-deep) for a bit and let it stabilize.
        rtc.setTriggerTime(time +% WAKE_UP_RTC_MAX_TIME);
        pmu.sleepIdle();
    }

    // TODO: Something about HSE current for stability? Not sure.
    // HSECFG_Current(HSE_RCur_100);

    config.sys.led_1.toggle();
    return 0;
}

pub fn initPeripheralRole() !void {
    const err = c.GAPRole_PeripheralInit();
    if (err != c.SUCCESS) {
        return error.Failure;
    }
}

pub const GattUuid = extern struct {
    len: u8,
    uuid: [*]const u8,

    const Self = @This();

    pub fn init(comptime uuid: anytype) Self {
        return switch (@TypeOf(uuid)) {
            u16 => .{
                .len = @sizeOf(u16),
                .uuid = &std.mem.toBytes(uuid),
            },
            else => switch (uuid.len) {
                4 => .{
                    .len = @sizeOf(u16),
                    .uuid = &std.mem.toBytes(std.fmt.parseUnsigned(u16, uuid, 16) catch unreachable),
                },
                else => .{
                    .len = @sizeOf(u128),
                    .uuid = &(UUID.parse(uuid) catch unreachable).bytes,
                },
            },
        };
    }
};

pub const GattPermissions = packed struct(u8) {
    read: bool = false,
    write: bool = false,
    authenticated_read: bool = false,
    authenticated_write: bool = false,
    authorized_read: bool = false,
    authorized_write: bool = false,
    encrypted_read: bool = false,
    encrypted_write: bool = false,

    const Self = @This();

    pub fn isReadonly(comptime self: Self) bool {
        return !self.write and !self.authenticated_write and !self.authorized_write and !self.encrypted_write;
    }
};

pub const GattProperties = packed struct(u8) {
    broadcast: bool = false,
    read: bool = false,
    write_no_rsp: bool = false,
    write: bool = false,
    notify: bool = false,
    indicate: bool = false,
    authenticate: bool = false,
    extended: bool = false,
};

pub const GattAttribute = extern struct {
    type: GattUuid,
    permissions: GattPermissions,
    handle: u16 = 0,
    value: *anyopaque,

    const Self = @This();
};

pub fn gattAttrPrimaryService(comptime service_uuid: GattUuid) GattAttribute {
    return GattAttribute{
        .type = GattUuid.init(n.DECL_PRIMARY_SERVICE),
        .permissions = .{ .read = true },
        .value = @constCast(@ptrCast(&service_uuid)),
    };
}

pub fn gattAttrCharacteristicDecl(comptime properties: GattProperties) GattAttribute {
    return GattAttribute{
        .type = GattUuid.init(n.DECL_CHARACTERISTIC),
        .permissions = .{ .read = true },
        .value = @constCast(&@as(u8, @bitCast(properties))),
    };
}

pub fn gattAttrClientCharCfg(comptime ccc: *ClientCharCfg, comptime permissions: GattPermissions) GattAttribute {
    return GattAttribute{
        .type = GattUuid.init(n.DESC_CLIENT_CHAR_CONFIG),
        .permissions = permissions,
        .value = ccc,
    };
}

pub fn gattAttrReportRef(comptime ref: *const HidReportReference, comptime permissions: GattPermissions) GattAttribute {
    return GattAttribute{
        .type = GattUuid.init(n.DESC_REPORT_REF),
        .permissions = permissions,
        .value = @constCast(ref),
    };
}

pub const HidReportReference = packed struct {
    report_id: u8,
    report_type: enum(u8) {
        input = 1,
        output = 2,
        feature = 3,
    },
};

pub const ClientCharCfg = struct {
    ccc: [config.ble.total_max_connections]c.gattCharCfg_t = undefined,

    pub const uuid = GattUuid.init(n.DESC_CLIENT_CHAR_CONFIG);

    const Self = @This();

    pub fn register(self: *Self, conn_handle: ?u16) void {
        c.GATTServApp_InitCharCfg(conn_handle orelse c.INVALID_CONNHANDLE, @ptrCast(&self.ccc));
    }

    pub fn write(conn_handle: u16, p_attr: [*c]c.gattAttribute_t, p_value: [*c]u8, len: u16, offset: u16) void {
        _ = c.GATTServApp_ProcessCCCWriteReq(conn_handle, p_attr, p_value, len, offset, c.GATT_CLIENT_CFG_NOTIFY);
    }

    pub fn notify(self: *Self, comptime T: type, conn_handle: u16, handle: u16, value: *T) void {
        const char_cfg = c.GATTServApp_ReadCharCfg(conn_handle, @ptrCast(&self.ccc));
        const null_ptr = @as(*allowzero u16, @ptrFromInt(0));

        if ((char_cfg & c.GATT_CLIENT_CFG_NOTIFY) == 0)
            return;

        var noti: c.attHandleValueNoti_t = undefined;
        noti.pValue = @ptrCast(c.GATT_bm_alloc(conn_handle, c.ATT_HANDLE_VALUE_NOTI, @sizeOf(T), null_ptr, 0));

        if (@intFromPtr(noti.pValue) == 0)
            return;

        noti.handle = handle;
        noti.len = @sizeOf(T);
        c.tmos_memcpy(noti.pValue, value, noti.len);

        if (c.GATT_Notification(conn_handle, &noti, 0) != c.SUCCESS) {
            c.GATT_bm_free(@ptrCast(&noti), c.ATT_HANDLE_VALUE_NOTI);
        } else {
            config.sys.led_1.toggle();
        }
    }
};
