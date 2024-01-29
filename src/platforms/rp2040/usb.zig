const std = @import("std");
const microzig = @import("microzig");

const rp2040 = microzig.hal;
const usb = rp2040.usb;

const report_descriptor_keyboard = [_]u8{ 0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, 0x05, 0x07, 0x19, 0xE0, 0x29, 0xE7, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01, 0x95, 0x08, 0x81, 0x02, 0x95, 0x01, 0x75, 0x08, 0x81, 0x01, 0x95, 0x06, 0x75, 0x08, 0x15, 0x00, 0x25, 0x65, 0x05, 0x07, 0x19, 0x00, 0x29, 0x65, 0x81, 0x00, 0xC0 };

// First we define two callbacks that will be used by the endpoints we define next...
fn ep1_in_callback(dc: *usb.DeviceConfiguration, data: []const u8) void {
    _ = dc;
    _ = data;
}

fn ep1_out_callback(dc: *usb.DeviceConfiguration, data: []const u8) void {
    _ = data;
    _ = dc;
}

// The endpoints EP0_IN and EP0_OUT are already defined but you can
// add your own endpoints to...
pub var EP1_OUT_CFG: usb.EndpointConfiguration = .{
    .descriptor = &usb.EndpointDescriptor{
        .length = @as(u8, @intCast(@sizeOf(usb.EndpointDescriptor))),
        .descriptor_type = usb.DescType.Endpoint,
        .endpoint_address = usb.Dir.Out.endpoint(1),
        .attributes = @intFromEnum(usb.TransferType.Interrupt),
        .max_packet_size = 64,
        .interval = 0,
    },
    .endpoint_control_index = 2,
    .buffer_control_index = 3,
    .data_buffer_index = 2,
    .next_pid_1 = false,
    // The callback will be executed if we got an interrupt on EP1_OUT
    .callback = ep1_out_callback,
};

pub var EP1_IN_CFG: usb.EndpointConfiguration = .{
    .descriptor = &usb.EndpointDescriptor{
        .length = @as(u8, @intCast(@sizeOf(usb.EndpointDescriptor))),
        .descriptor_type = usb.DescType.Endpoint,
        .endpoint_address = usb.Dir.In.endpoint(1),
        .attributes = @intFromEnum(usb.TransferType.Interrupt),
        .max_packet_size = 64,
        .interval = 0,
    },
    .endpoint_control_index = 1,
    .buffer_control_index = 2,
    .data_buffer_index = 3,
    .next_pid_1 = false,
    // The callback will be executed if we got an interrupt on EP1_IN
    .callback = ep1_in_callback,
};

// This is our device configuration
pub var DEVICE_CONFIGURATION: usb.DeviceConfiguration = .{
    .device_descriptor = &.{
        .length = @as(u8, @intCast(@sizeOf(usb.DeviceDescriptor))),
        .descriptor_type = usb.DescType.Device,
        .bcd_usb = 0x0200,
        .device_class = 0,
        .device_subclass = 0,
        .device_protocol = 0,
        .max_packet_size0 = 64,
        .vendor = 0xCafe,
        .product = 1,
        .bcd_device = 0x0100,
        // Those are indices to the descriptor strings
        // Make sure to provide enough string descriptors!
        .manufacturer_s = 1,
        .product_s = 2,
        .serial_s = 3,
        .num_configurations = 1,
    },
    .interface_descriptor = &.{
        .length = @as(u8, @intCast(@sizeOf(usb.InterfaceDescriptor))),
        .descriptor_type = usb.DescType.Interface,
        .interface_number = 0,
        .alternate_setting = 0,
        // We have two endpoints (EP0 IN/OUT don't count)
        .num_endpoints = 2,
        .interface_class = 3,
        .interface_subclass = 0,
        .interface_protocol = 0,
        .interface_s = 0,
    },
    .config_descriptor = &.{
        .length = @as(u8, @intCast(@sizeOf(usb.ConfigurationDescriptor))),
        .descriptor_type = usb.DescType.Config,
        .total_length = @as(u8, @intCast(@sizeOf(usb.ConfigurationDescriptor) + @sizeOf(usb.InterfaceDescriptor) + @sizeOf(usb.EndpointDescriptor) + @sizeOf(usb.EndpointDescriptor))),
        .num_interfaces = 1,
        .configuration_value = 1,
        .configuration_s = 0,
        .attributes = 0xc0,
        .max_power = 0x32,
    },
    .lang_descriptor = "\x04\x03\x09\x04", // length || string descriptor (0x03) || Engl (0x0409)
    .descriptor_strings = &.{
        // ugly unicode :|
        &usb.utf8ToUtf16Le("Raspberry Pi"),
        &usb.utf8ToUtf16Le("Pico Test Device"),
        &usb.utf8ToUtf16Le("cafebabe"),
    },
    .hid = .{
        .hid_descriptor = &.{
            .bcd_hid = 0x0111,
            .country_code = 0,
            .num_descriptors = 1,
            .report_length = report_descriptor_keyboard.len,
        },
        .report_descriptor = &report_descriptor_keyboard,
    },
    // Here we pass all endpoints to the config
    // Dont forget to pass EP0_[IN|OUT] in the order seen below!
    .endpoints = .{
        &usb.EP0_OUT_CFG,
        &usb.EP0_IN_CFG,
        &EP1_OUT_CFG,
        &EP1_IN_CFG,
    },
};

pub fn init() !void {
    rp2040.usb.Usb.init_clk();
    try rp2040.usb.Usb.init_device(&DEVICE_CONFIGURATION);
}

pub fn process() !void {
    // You can now poll for USB events
    try rp2040.usb.Usb.task(
        true, // debug output over UART [Y/n]
    );
}

pub fn sendReport(report: *const [8]u8) void {
    usb.Usb.callbacks.usb_start_tx(
        &EP1_IN_CFG,
        report,
    );
}
