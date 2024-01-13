const std = @import("std");
const c = @import("../lib/ch583.zig");
const config = @import("../config.zig");

const n = @import("assigned_numbers.zig");
const bleDataBytes = @import("utils.zig").bleDataBytes;
const tmos = @import("tmos.zig");

const Duration = @import("../duration.zig").Duration;

const DeviceInfoService = @import("dev_info_service.zig");
const BatteryService = @import("battery_service.zig");
const HidService = @import("hid_service.zig");

const blueprint = tmos.TaskBlueprint{
    .Event = enum(u4) {
        start_device,
        start_param_update,
    },
    .events_callback = &.{
        tmosEvtStartDevice,
        tmosEvtStartParamUpdate,
    },
};
var tmos_task: tmos.Task(blueprint.Event) = undefined;

var gap_state: c.gapRole_States_t = c.GAPROLE_INIT;
var gap_conn_handle: u16 = c.GAP_CONNHANDLE_INIT;
var conn_secure = false;

const pass_key: u32 = 0;
const pair_mode: u8 = c.GAPBOND_PAIRING_MODE_WAIT_FOR_REQ;
const mitm: u8 = c.TRUE;
const io_cap: u8 = c.GAPBOND_IO_CAP_NO_INPUT_NO_OUTPUT;
const bonding: u8 = c.TRUE;

const scan_rsp_data = bleDataBytes(.{
    c.GAP_ADTYPE_LOCAL_NAME_COMPLETE,       config.ble.name,
    c.GAP_ADTYPE_SLAVE_CONN_INTERVAL_RANGE, &[2]u16{ config.ble.conn_interval_min, config.ble.conn_interval_max },
    c.GAP_ADTYPE_POWER_LEVEL,               &config.ble.tx_power.value(),
});

const advert_data = bleDataBytes(.{
    c.GAP_ADTYPE_FLAGS,      &(c.GAP_ADTYPE_FLAGS_LIMITED | c.GAP_ADTYPE_FLAGS_BREDR_NOT_SUPPORTED),
    c.GAP_ADTYPE_APPEARANCE, &c.GAP_APPEARE_HID_KEYBOARD,
    c.GAP_ADTYPE_16BIT_MORE, &[_]u16{ n.SERVICE_HID, n.SERVICE_BATTERY },
});

pub fn init() void {
    if (scan_rsp_data.len > 31) {
        @compileError("scan_rsp_data is longer than max of 31 bytes.");
    }
    if (advert_data.len > 31) {
        @compileError("advert_data is longer than max of 31 bytes.");
    }

    tmos_task = tmos.register(blueprint);

    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_AUTO_SYNC_WL, @sizeOf(u8), @constCast(&c.TRUE));

    _ = c.GGS_AddService(c.GATT_ALL_SERVICES);
    _ = c.GATTServApp_AddService(c.GATT_ALL_SERVICES);

    DeviceInfoService.register();
    BatteryService.register();
    HidService.register();

    tmos_task.setEvent(.start_device);

    // HidEmu_Init
    _ = c.GAPRole_SetParameter(c.GAPROLE_ADVERT_ENABLED, @sizeOf(u8), @constCast(&c.TRUE));
    _ = c.GAPRole_SetParameter(c.GAPROLE_ADVERT_DATA, advert_data.len, @constCast(&advert_data));
    _ = c.GAPRole_SetParameter(c.GAPROLE_SCAN_RSP_DATA, scan_rsp_data.len, @constCast(&scan_rsp_data));

    _ = c.GGS_SetParameter(c.GGS_DEVICE_NAME_ATT, config.ble.name.len, @constCast(@ptrCast(config.ble.name)));

    // GAP Bond Manager
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_DEFAULT_PASSCODE, @sizeOf(u32), @constCast(&pass_key));
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_PAIRING_MODE, @sizeOf(u8), @constCast(&pair_mode));
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_MITM_PROTECTION, @sizeOf(u8), @constCast(&mitm));
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_IO_CAPABILITIES, @sizeOf(u8), @constCast(&io_cap));
    _ = c.GAPBondMgr_SetParameter(c.GAPBOND_PERI_BONDING_ENABLED, @sizeOf(u8), @constCast(&bonding));
}

fn tmosEvtStartDevice() void {
    _ = c.GAPRole_PeripheralStartDevice(
        tmos_task.id,
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
}

fn tmosEvtStartParamUpdate() void {
    _ = c.GAPRole_PeripheralConnParamUpdateReq(
        gap_conn_handle,
        config.ble.conn_interval_min,
        config.ble.conn_interval_max,
        0,
        500,
        tmos_task.id,
    );
}

pub fn notifyHidReport(report: *[8]u8) void {
    if (conn_secure) {
        HidService.notify(gap_conn_handle, report);
    }
}

fn onGapStateChange(new_state: c.gapRole_States_t, event: [*c]c.gapRoleEvent_t) callconv(.C) void {
    defer gap_state = new_state;

    if (new_state == c.GAPROLE_CONNECTED) {
        const link_req_event: *c.gapEstLinkReqEvent_t = @ptrCast(event);

        gap_conn_handle = link_req_event.connectionHandle;
        conn_secure = false;

        setAdvertising(false);

        tmos_task.scheduleEvent(.start_param_update, Duration.fromSecs(2));
    } else if (gap_state == c.GAPROLE_CONNECTED and new_state != c.GAPROLE_CONNECTED) {
        conn_secure = false;
        gap_conn_handle = c.GAP_CONNHANDLE_INIT;

        setAdvertising(true);
    }
}

fn setAdvertising(enabled: bool) void {
    _ = c.GAPRole_SetParameter(c.GAPROLE_ADVERT_ENABLED, @sizeOf(u8), @constCast(&@intFromBool(enabled)));
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
