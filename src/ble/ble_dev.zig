const c = @import("../lib/ch583.zig");

const DeviceInfoService = @import("dev_info_service.zig");
const BatteryService = @import("battery_service.zig");
const HidService = @import("hid_service.zig");

const START_DEVICE_EVT: u16 = 1;
const START_REPORT_EVT: u16 = 2;
const START_PARAM_UPDATE_EVT: u16 = 4;

var task_id: u8 = c.INVALID_TASK;
var gap_state: c.gapRole_States_t = c.GAPROLE_INIT;
var gap_conn_handle: u16 = c.GAP_CONNHANDLE_INIT;
var conn_secure = false;

const pass_key: u32 = 0;
const pair_mode: u8 = c.GAPBOND_PAIRING_MODE_WAIT_FOR_REQ;
const mitm: u8 = c.TRUE;
const io_cap: u8 = c.GAPBOND_IO_CAP_NO_INPUT_NO_OUTPUT;
const bonding: u8 = c.TRUE;

fn Data(comptime T: type) type {
    return packed struct {
        length: u8 = @sizeOf(u8) + @sizeOf(T),
        data_type: u8,
        value: T,
    };
}

const name: packed struct {
    a: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
} = .{
    .a = 'A',
    .b = 'b',
    .c = 'n',
    .d = 'o',
    .e = '.',
};

const advert_data: packed struct {
    flags: Data(u8),
    appearance: Data(u16),
} = .{
    .flags = .{
        .data_type = c.GAP_ADTYPE_FLAGS,
        .value = c.GAP_ADTYPE_FLAGS_LIMITED | c.GAP_ADTYPE_FLAGS_BREDR_NOT_SUPPORTED,
    },
    .appearance = .{
        .data_type = c.GAP_ADTYPE_APPEARANCE,
        .value = c.GAP_APPEARE_HID_KEYBOARD,
    },
};

const scan_rsp_data: packed struct {
    name: Data(@TypeOf(name)), // TODO: Actual strings
    conn_interval_range: Data(packed struct { min: u16, max: u16 }),
    services: Data(packed struct { a: u16, b: u16 }),
    power_level: Data(u8),
} = .{
    .name = .{
        .data_type = c.GAP_ADTYPE_LOCAL_NAME_COMPLETE,
        .value = name,
    },
    .conn_interval_range = .{
        .data_type = c.GAP_ADTYPE_SLAVE_CONN_INTERVAL_RANGE,
        .value = .{ .min = 8, .max = 8 },
    },
    .services = .{
        .data_type = c.GAP_ADTYPE_16BIT_MORE,
        .value = .{ .a = 0x1812, .b = 0x180F },
    },
    .power_level = .{
        .data_type = c.GAP_ADTYPE_POWER_LEVEL,
        .value = 0,
    },
};

pub fn init() void {
    task_id = c.TMOS_ProcessEventRegister(onTmosEvent);

    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_AUTO_SYNC_WL, @sizeOf(u8), @constCast(&c.TRUE));

    _ = c.GGS_AddService(c.GATT_ALL_SERVICES);
    _ = c.GATTServApp_AddService(c.GATT_ALL_SERVICES);

    DeviceInfoService.register();
    BatteryService.register();
    HidService.register();

    _ = c.tmos_set_event(task_id, START_DEVICE_EVT);

    // HidEmu_Init
    _ = c.GAPRole_SetParameter(c.GAPROLE_ADVERT_ENABLED, @sizeOf(u8), @constCast(&c.TRUE));
    _ = c.GAPRole_SetParameter(c.GAPROLE_ADVERT_DATA, @sizeOf(@TypeOf(advert_data)), @constCast(&advert_data));
    _ = c.GAPRole_SetParameter(c.GAPROLE_SCAN_RSP_DATA, @sizeOf(@TypeOf(scan_rsp_data)), @constCast(&scan_rsp_data));

    _ = c.GGS_SetParameter(c.GGS_DEVICE_NAME_ATT, 5, @constCast(@ptrCast("Abno.")));

    // GAP Bond Manager
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_DEFAULT_PASSCODE, @sizeOf(u32), @constCast(&pass_key));
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_PAIRING_MODE, @sizeOf(u8), @constCast(&pair_mode));
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_MITM_PROTECTION, @sizeOf(u8), @constCast(&mitm));
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_IO_CAPABILITIES, @sizeOf(u8), @constCast(&io_cap));
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_BONDING_ENABLED, @sizeOf(u8), @constCast(&bonding));
}

fn onTmosEvent(_: u8, events: u16) callconv(.C) u16 {
    if (events & c.SYS_EVENT_MSG != 0) {
        const msg = c.tmos_msg_receive(task_id);

        if (@intFromPtr(msg) != 0) {
            _ = c.tmos_msg_deallocate(msg);
        }

        return @intCast(events ^ c.SYS_EVENT_MSG);
    }

    if (events & START_DEVICE_EVT != 0) {
        _ = c.GAPRole_PeripheralStartDevice(
            task_id,
            @constCast(&c.gapBondCBs_t{
                .passcodeCB = null,
                .pairStateCB = onGapPairStateChange,
            }),
            @constCast(&c.gapRolesCBs_t{
                .pfnStateChange = onGapStateChange,
                .pfnRssiRead = null,
                .pfnParamUpdate = null,
            }),
        );

        return @intCast(events ^ START_DEVICE_EVT);
    }

    if (events & START_PARAM_UPDATE_EVT != 0) {
        _ = c.GAPRole_PeripheralConnParamUpdateReq(
            gap_conn_handle,
            8,
            8,
            0,
            500,
            task_id,
        );

        return @intCast(events ^ START_PARAM_UPDATE_EVT);
    }

    return 0;
}

pub fn notify(code: u8) void {
    if (conn_secure) {
        HidService.notify(gap_conn_handle, code);
    }
}

fn onGapStateChange(new_state: c.gapRole_States_t, event: [*c]c.gapRoleEvent_t) callconv(.C) void {
    defer gap_state = new_state;

    if (new_state == c.GAPROLE_CONNECTED) {
        const link_req_event: *c.gapEstLinkReqEvent_t = @ptrCast(event);

        gap_conn_handle = link_req_event.connectionHandle;
        conn_secure = false;

        _ = c.GAPRole_SetParameter(c.GAPROLE_ADVERT_ENABLED, @sizeOf(u8), @constCast(&c.FALSE));

        _ = c.tmos_start_task(task_id, START_PARAM_UPDATE_EVT, 2800);
    } else if (gap_state == c.GAPROLE_CONNECTED and new_state != c.GAPROLE_CONNECTED) {
        // TODO: Disconnected
    }
}

fn onGapPairStateChange(conn_handle: u16, state: u8, status: u8) callconv(.C) void {
    _ = conn_handle;

    if (state == c.GAPBOND_PAIRING_STATE_COMPLETE) {
        if (status == c.SUCCESS) {
            conn_secure = true;
        }
        // pairing_status = status;
    } else if (state == c.GAPBOND_PAIRING_STATE_BONDED) {
        if (status == c.SUCCESS) {
            conn_secure = true;
        }
    }
}
