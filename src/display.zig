const std = @import("std");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;
const time = rp2040.time;
const GlobalConfiguration = rp2040.pins.GlobalConfiguration;
const Pins = rp2040.pins.Pins;
const SPI = rp2040.spi.SPI;

pub const Display = struct {
    width: comptime_int,
    height: comptime_int,
    pin_config: GlobalConfiguration,
    spi: SPI,
    lut: [159]u8,

    const Command = enum(u8) {
        clear = 0x00,
        display_update_sequence_option = 0x22,
        activate_display_update_sequence = 0x20,
        gate_voltage = 0x03,
        source_voltage = 0x04,
        vcom = 0x2c,
        set_ram_x_address_start_end_position = 0x44,
        set_ram_y_address_start_end_position = 0x45,
        set_ram_x_address_counter = 0x4E,
        set_ram_y_address_counter = 0x4F,
        swreset = 0x12,
        driver_output_control = 0x01,
        data_entry_mode = 0x11,
        border_waveform = 0x3C,
        display_update_control = 0x21,
        read_built_in_temperature_sensor = 0x18,
        // 0x3f
        // 0x32
        // 0x24
        // 0x37
        enter_deep_sleep = 0x10,
    };

    pub fn init(comptime display: Display, pins: Pins(display.pin_config)) void {
        std.log.debug("\n--------------------", .{});
        std.log.debug("Init:\n", .{});

        display.reset(pins);
        std.log.debug("sleep for {}ms", .{100});
        time.sleep_ms(100);

        display.wait_while_busy(pins);
        display.send_command(pins, 0x12);
        display.wait_while_busy(pins);

        display.send_command(pins, 0x01);
        display.send_data(pins, 0xf9);
        display.send_data(pins, 0x00);
        display.send_data(pins, 0x00);

        display.send_command(pins, 0x11);
        display.send_data(pins, 0x03);

        display.set_windows(pins, 0, 0, (display.width - 1), (display.height - 1));
        display.set_cursor(pins, 0, 0);

        display.send_command(pins, 0x3C);
        display.send_data(pins, 0x05);

        display.send_command(pins, 0x21);
        display.send_data(pins, 0x00);
        display.send_data(pins, 0x80);

        display.send_command(pins, 0x18);
        display.send_data(pins, 0x80);

        display.wait_while_busy(pins);

        display.lut_by_host(pins, display.lut);
    }

    pub fn reset(comptime display: Display, pins: Pins(display.pin_config)) void {
        std.log.debug("Writing pin: {}, value: {}", .{ 12, 1 });
        pins.rst.put(1);
        std.log.debug("sleep for {}ms", .{20});
        time.sleep_ms(20);
        std.log.debug("Writing pin: {}, value: {}", .{ 12, 0 });
        pins.rst.put(0);
        std.log.debug("sleep for {}ms", .{2});
        time.sleep_ms(2);
        std.log.debug("Writing pin: {}, value: {}", .{ 12, 1 });
        pins.rst.put(1);
        std.log.debug("sleep for {}ms", .{20});
        time.sleep_ms(20);
    }

    pub fn send_command(comptime display: Display, pins: Pins(display.pin_config), command: u8) void {
        std.log.debug("Writing pin: {}, value: {}", .{ 8, 0 });
        pins.dc.put(0);
        std.log.debug("Writing pin: {}, value: {}", .{ 9, 0 });
        pins.cs.put(0);
        const c = [_]u8{command};
        std.log.debug("Write byte to SPI: {x}", .{c[0]});
        _ = display.spi.write(c[0..]);
        std.log.debug("Writing pin: {}, value: {}", .{ 9, 1 });
        pins.cs.put(1);
    }

    pub fn send_data(comptime display: Display, pins: Pins(display.pin_config), data: u8) void {
        std.log.debug("Writing pin: {}, value: {}", .{ 8, 1 });
        pins.dc.put(1);
        std.log.debug("Writing pin: {}, value: {}", .{ 9, 0 });
        pins.cs.put(0);
        const d = [_]u8{data};
        std.log.debug("Write byte to SPI: {x}", .{d[0]});
        _ = display.spi.write(d[0..]);
        std.log.debug("Writing pin: {}, value: {}", .{ 9, 1 });
        pins.cs.put(1);
    }

    pub fn wait_while_busy(comptime display: Display, pins: Pins(display.pin_config)) void {
        while (true) {
            std.log.debug("Reading pin: {}, returning {}", .{ 13, 0 });
            if (pins.busy.read() == 0) {
                break;
            }
            std.log.debug("sleep for {}ms", .{10});
            time.sleep_ms(10);
        }
        std.log.debug("sleep for {}ms", .{10});
        time.sleep_ms(10);
    }

    pub fn turn_on(comptime display: Display, pins: Pins(display.pin_config)) void {
        display.send_command(pins, 0x22);
        display.send_data(pins, 0xc7);
        display.send_command(pins, 0x20);
        display.wait_while_busy(pins);
    }

    pub fn set_windows(comptime display: Display, pins: Pins(display.pin_config), xStart: u16, yStart: u16, xEnd: u16, yEnd: u16) void {
        display.send_command(pins, 0x44);
        display.send_data(pins, @truncate(u8, (xStart >> 3)));
        display.send_data(pins, @truncate(u8, (xEnd >> 3)));
        // EPD_2in13_V3_SendCommand(0x44); // SET_RAM_X_ADDRESS_START_END_POSITION
        // EPD_2in13_V3_SendData((Xstart>>3) & 0xFF);
        // EPD_2in13_V3_SendData((Xend>>3) & 0xFF);

        display.send_command(pins, 0x45);
        display.send_data(pins, @truncate(u8, yStart));
        display.send_data(pins, @truncate(u8, (yStart >> 8)));
        display.send_data(pins, @truncate(u8, yEnd));
        display.send_data(pins, @truncate(u8, (yEnd >> 8)));
        // EPD_2in13_V3_SendCommand(0x45); // SET_RAM_Y_ADDRESS_START_END_POSITION
        // EPD_2in13_V3_SendData(Ystart & 0xFF);
        // EPD_2in13_V3_SendData((Ystart >> 8) & 0xFF);
        // EPD_2in13_V3_SendData(Yend & 0xFF);
        // EPD_2in13_V3_SendData((Yend >> 8) & 0xFF);
    }

    pub fn set_cursor(comptime display: Display, pins: Pins(display.pin_config), xStart: u16, yStart: u16) void {
        display.send_command(pins, 0x4E);
        display.send_data(pins, @truncate(u8, xStart));

        display.send_command(pins, 0x4F);
        display.send_data(pins, @truncate(u8, yStart));
        display.send_data(pins, @truncate(u8, (yStart >> 8)));
    }

    pub fn set_lut(comptime display: Display, pins: Pins(display.pin_config), lut: [159]u8) void {
        display.send_command(pins, 0x32);

        for (lut, 0..) |byte, index| {
            if (index >= 153) {
                break;
            }
            display.send_data(pins, byte);
        }

        display.wait_while_busy(pins);
    }

    pub fn lut_by_host(comptime display: Display, pins: Pins(display.pin_config), lut: [159]u8) void {
        display.set_lut(pins, lut);

        display.send_command(pins, 0x3f);
        display.send_data(pins, lut[153]);

        display.send_command(pins, 0x03);
        display.send_data(pins, lut[154]);

        display.send_command(pins, 0x04);
        display.send_data(pins, lut[155]);
        display.send_data(pins, lut[156]);
        display.send_data(pins, lut[157]);

        display.send_command(pins, 0x2c);
        display.send_data(pins, lut[158]);
    }
    pub fn clear(comptime display: Display, pins: Pins(display.pin_config)) void {
        std.log.debug("\n--------------------", .{});
        std.log.debug("Clear:\n", .{});
        const screenWidth = if (display.width % 8 == 0) (display.width / 8) else (display.width / 8 + 1);
        const screenHeight = display.height;

        display.send_command(pins, 0x24);

        var j: u8 = 0;
        while (j < screenHeight) : (j += 1) {
            var i: u8 = 0;
            while (i < screenWidth) : (i += 1) {
                display.send_data(pins, 0xFF);
            }
        }

        display.turn_on(pins);
    }

    pub fn sleep(comptime display: Display, pins: Pins(display.pin_config)) void {
        display.send_command(pins, 0x10);
        display.send_data(pins, 0x01);
        time.sleep_ms(100);
    }

    pub fn show_image(comptime display: Display, pins: Pins(display.pin_config), image: []const u8) void {
        std.log.debug("\n--------------------", .{});
        std.log.debug("Display image:\n", .{});
        const screenWidth = if (display.width % 8 == 0) (display.width / 8) else (display.width / 8 + 1);
        const screenHeight = display.height;

        display.send_command(pins, 0x24);
        var j: u16 = 0;
        while (j < screenHeight) : (j += 1) {
            var i: u16 = 0;
            while (i < screenWidth) : (i += 1) {
                const current_byte = i + j * screenWidth;
                if (current_byte >= image.len) {
                    display.send_data(pins, 0x00);
                } else {
                    display.send_data(pins, image[current_byte]);
                }
            }
        }

        display.turn_on(pins);
    }
};

test "display module compiles" {
    const display = Display{ .width = 0, .height = 0, .pin_config = GlobalConfiguration{} };
    _ = display;
}
