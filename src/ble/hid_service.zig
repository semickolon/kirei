const ble = @import("ble.zig");
const c = @import("../lib/ch583.zig");
const n = @import("assigned_numbers.zig");

const HidProtocolMode = enum(u8) { boot, report };

const REPORT_ID_MAIN = 1;

var hid_protocol_mode: HidProtocolMode = .report;
var hid_report_ccc = ble.ClientCharCfg{};

const HidInfo = packed struct {
    bcd_hid: u16 = 0x0111, // 1.11
    country_code: u8 = 0,
    flags: u8 = 0,
};

const report_map = [_]u8{
    0x05, 0x01, // Usage Page (Generic Desktop Ctrls)
    0x09, 0x06, // Usage (Keyboard)
    0xA1, 0x01, // Collection (Application)
    0x05, 0x07, //   Usage Page (Kbrd/Keypad)
    0x85, REPORT_ID_MAIN, //   Report ID
    0x19, 0xE0, //   Usage Minimum (0xE0)
    0x29, 0xE7, //   Usage Maximum (0xE7)
    0x15, 0x00, //   Logical Minimum (0)
    0x25, 0x01, //   Logical Maximum (1)
    0x75, 0x01, //   Report Size (1)
    0x95, 0x08, //   Report Count (8)
    0x81, 0x02, //   Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
    0x95, 0x01, //   Report Count (1)
    0x75, 0x08, //   Report Size (8)
    0x81, 0x01, //   Input (Const,Array,Abs,No Wrap,Linear,Preferred State,No Null Position)
    0x95, 0x06, //   Report Count (6)
    0x75, 0x08, //   Report Size (8)
    0x15, 0x00, //   Logical Minimum (0)
    0x25, 0x65, //   Logical Maximum (101)
    0x05, 0x07, //   Usage Page (Kbrd/Keypad)
    0x19, 0x00, //   Usage Minimum (0x00)
    0x29, 0x65, //   Usage Maximum (0x65)
    0x81, 0x00, //   Input (Data,Array,Abs,No Wrap,Linear,Preferred State,No Null Position)
    0xC0, // End Collection
};

const hid_info = HidInfo{};
var k: u8 = 0;

var attributes = [_]ble.GattAttribute{
    ble.gattAttrPrimaryService(ble.GattUuid.init(n.SERVICE_HID)),
    // HID Information
    ble.gattAttrCharacteristicDecl(.{ .read = true }),
    .{
        .type = ble.GattUuid.init(n.CHAR_HID_INFORMATION),
        .permissions = .{ .encrypted_read = true },
        .value = @constCast(&hid_info),
    },
    // HID Control Point
    ble.gattAttrCharacteristicDecl(.{ .write_no_rsp = true }),
    .{
        .type = ble.GattUuid.init(n.CHAR_HID_CONTROL_POINT),
        .permissions = .{ .encrypted_write = true },
        .value = @constCast(&0),
    },
    // HID Protocol Mode
    ble.gattAttrCharacteristicDecl(.{ .read = true, .write_no_rsp = true }),
    .{
        .type = ble.GattUuid.init(n.CHAR_HID_PROTOCOL_MODE),
        .permissions = .{ .encrypted_read = true, .encrypted_write = true },
        .value = &hid_protocol_mode,
    },
    // HID Report Map
    ble.gattAttrCharacteristicDecl(.{ .read = true }),
    .{
        .type = ble.GattUuid.init(n.CHAR_HID_REPORT_MAP),
        .permissions = .{ .encrypted_read = true },
        .value = @constCast(&report_map),
    },
    // HID Report
    ble.gattAttrCharacteristicDecl(.{ .read = true, .notify = true }),
    .{
        .type = ble.GattUuid.init(n.CHAR_HID_REPORT),
        .permissions = .{ .encrypted_read = true },
        .value = &k,
    },
    ble.gattAttrClientCharCfg(
        &hid_report_ccc,
        .{ .read = true, .encrypted_write = true },
    ),
    ble.gattAttrReportRef(
        &ble.HidReportReference{ .report_id = REPORT_ID_MAIN, .report_type = .input },
        .{ .read = true },
    ),
};

pub fn register() void {
    hid_report_ccc.register(null);

    _ = c.GATTServApp_RegisterService(
        @ptrCast(&attributes),
        attributes.len,
        c.GATT_MAX_ENCRYPT_KEY_SIZE,
        @constCast(&[_]c.gattServiceCBs_t{
            .{
                .pfnReadAttrCB = readAttrCallback,
                .pfnWriteAttrCB = writeAttrCallback,
                .pfnAuthorizeAttrCB = null,
            },
        }),
    );
}

pub fn notify(conn_handle: u16, report: *[8]u8) void {
    hid_report_ccc.notify(
        @TypeOf(report.*),
        conn_handle,
        attributes[10].handle,
        report,
    );
}

fn readAttrCallback(
    connHandle: u16,
    pAttr: [*c]c.gattAttribute_t,
    pValue: [*c]u8,
    pLen: [*c]u16,
    offset: u16,
    maxLen: u16,
    method: u8,
) callconv(.C) u8 {
    _ = method;
    _ = connHandle;

    const uuid: u16 = (pAttr.*.type.uuid[0]) | (@as(u16, @intCast(pAttr.*.type.uuid[1])) << 8);

    if (offset > 0 and uuid != n.CHAR_HID_REPORT_MAP) {
        return c.ATT_ERR_ATTR_NOT_LONG;
    }

    switch (uuid) {
        n.CHAR_HID_REPORT_MAP => {
            if (offset >= report_map.len) {
                return c.ATT_ERR_INVALID_OFFSET;
            }

            pLen.* = @min(maxLen, report_map.len - offset);
            c.tmos_memcpy(pValue, pAttr.*.pValue + offset, pLen.*);
        },
        n.CHAR_HID_INFORMATION => {
            pLen.* = @sizeOf(HidInfo);
            c.tmos_memcpy(pValue, pAttr.*.pValue, pLen.*);
        },
        n.DESC_REPORT_REF => {
            pLen.* = @sizeOf(ble.HidReportReference);
            c.tmos_memcpy(pValue, pAttr.*.pValue, pLen.*);
        },
        n.CHAR_HID_PROTOCOL_MODE => {
            pLen.* = @sizeOf(HidProtocolMode);
            c.tmos_memcpy(pValue, pAttr.*.pValue, pLen.*);
        },
        else => {
            return c.ATT_ERR_ATTR_NOT_FOUND;
        },
    }

    return c.SUCCESS;
}

fn writeAttrCallback(
    connHandle: u16,
    pAttr: [*c]c.gattAttribute_t,
    pValue: [*c]u8,
    len: u16,
    offset: u16,
    method: u8,
) callconv(.C) u8 {
    _ = method;

    const uuid: u16 = (pAttr.*.type.uuid[0]) | (@as(u16, @intCast(pAttr.*.type.uuid[1])) << 8);

    if (offset > 0) {
        return c.ATT_ERR_ATTR_NOT_LONG;
    }

    switch (uuid) {
        n.CHAR_HID_CONTROL_POINT => {},
        n.CHAR_HID_PROTOCOL_MODE => {
            hid_protocol_mode = @enumFromInt(pValue.*);
        },
        n.DESC_CLIENT_CHAR_CONFIG => {
            ble.ClientCharCfg.write(connHandle, pAttr, pValue, len, offset);
            return c.SUCCESS;
        },
        else => {
            return c.ATT_ERR_ATTR_NOT_FOUND;
        },
    }

    return c.SUCCESS;
}
