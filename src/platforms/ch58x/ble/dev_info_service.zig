const ble = @import("ble.zig");
const c = @import("../lib/ch583.zig");
const n = @import("assigned_numbers.zig");

pub const PnpId = packed struct {
    vendor_id_source: u8,
    vendor_id: u16,
    product_id: u16,
    product_ver: u16,
};

var attributes = [_]ble.GattAttribute{
    ble.gattAttrPrimaryService(ble.GattUuid.init(n.SERVICE_DEVICE_INFO)),
    ble.gattAttrCharacteristicDecl(.{ .read = true }),
    .{
        .type = ble.GattUuid.init(n.CHAR_SYSTEM_ID),
        .permissions = .{ .read = true },
        .value = @constCast(&0),
    },
};

pub fn register() void {
    _ = c.GATTServApp_RegisterService(
        @ptrCast(&attributes),
        attributes.len,
        c.GATT_MAX_ENCRYPT_KEY_SIZE,
        @constCast(&[_]c.gattServiceCBs_t{
            .{
                .pfnReadAttrCB = readAttrCallback,
                .pfnWriteAttrCB = null,
                .pfnAuthorizeAttrCB = null,
            },
        }),
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
    _ = maxLen;
    _ = offset;
    _ = method;
    _ = connHandle;

    const attr: *ble.GattAttribute = @ptrCast(pAttr);

    if (attr.*.type.len == 2) {
        pLen.* = 6;
        c.tmos_memcpy(pValue, "woah!!".ptr, pLen.*);
        return c.SUCCESS;
    }

    return c.ATT_ERR_ATTR_NOT_FOUND;
}
