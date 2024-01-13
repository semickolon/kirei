const ble = @import("ble.zig");
const c = @import("../lib/ch583.zig");
const n = @import("assigned_numbers.zig");

var batt_level: u8 = 100;
var batt_level_ccc = ble.ClientCharCfg{};

var attributes = [_]ble.GattAttribute{
    ble.gattAttrPrimaryService(ble.GattUuid.init(n.SERVICE_BATTERY)),
    ble.gattAttrCharacteristicDecl(.{ .read = true, .notify = true }),
    .{
        .type = ble.GattUuid.init(n.CHAR_BATTERY_LEVEL),
        .permissions = .{ .read = true },
        .value = @constCast(&0),
    },
    ble.gattAttrClientCharCfg(
        &batt_level_ccc,
        .{ .read = true, .write = true },
    ),
    ble.gattAttrReportRef(
        &ble.HidReportReference{ .report_id = 4, .report_type = .input },
        .{ .read = true },
    ),
};

pub fn register() void {
    batt_level_ccc.register(null);

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

pub fn setBattLevel(conn_handle: u16, level: u8) !void {
    batt_level = level;

    try batt_level_ccc.notify(
        @TypeOf(batt_level),
        conn_handle,
        attributes[3].handle,
        batt_level,
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
    _ = maxLen;
    _ = offset;
    _ = connHandle;
    pLen.* = 0;

    const handle = pAttr.*.handle;

    if (handle == attributes[2].handle) {
        pLen.* = 1;
        pValue[0] = batt_level; // TODO: Measure battery
    }

    if (handle == attributes[4].handle) {
        pLen.* = 2;
        c.tmos_memcpy(pValue, pAttr.*.pValue, 2);
    }

    return if (pLen.* == 0) c.ATT_ERR_ATTR_NOT_FOUND else c.SUCCESS;
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

    if (pAttr.*.handle == attributes[3].handle) {
        ble.ClientCharCfg.write(connHandle, pAttr, pValue, len, offset);
        return c.SUCCESS;
    }

    return c.ATT_ERR_ATTR_NOT_FOUND;
}
