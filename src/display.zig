const std = @import("std");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;
const time = rp2040.time;
const GlobalConfiguration = rp2040.pins.GlobalConfiguration;
const Pins = rp2040.pins.Pins;
const SPI = rp2040.spi.SPI;

const EpdConfiguration = struct {
    width: comptime_int,
    height: comptime_int,
    lut: [159]u8,
    init_sequence: [3]u8,
};

pub const Display = struct {
    epd_config: EpdConfiguration,
    pin_config: GlobalConfiguration,
    spi: SPI,

    const DisplayMode = enum(u8) {
        display_mode_1 = 0xC7, // full update
        display_mode_2 = 0x0C, // 0x0F, 0xCF // partial update (2in13, 2in9, 2in9_4grey) fast:0x0c, quality:0x0f, 0xcf
    };

    const FrameRates = enum(u8) {
        @"0x22" = 0x22,
        @"0x44" = 0x44,
    };

    const GateScanSelection = enum(u8) { XON = 0 };

    const EOPT = enum(u8) {
        normal = 0x22,
    };

    const VGH = enum(u8) {
        @"20V" = 0x17,
    };

    const VSH = enum(u8) {
        @"15V" = 0x41,
        @"5.8V" = 0xB0,
        unknown = 0x00,
    };

    const VSL = enum(u8) {
        @"-15V" = 0x32,
    };

    const VCOM = enum(u8) {
        @"-1.3_to_-1.4" = 0x36,
    };

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
        @"0x3f" = 0x3f, // 0x3f
        write_LUT_register = 0x32, // 0x32
        write_image_to_ram = 0x24, // 0x24 write image to ram
        write_image_to_ram_color = 0x26, // 0x26 write image to ram
        // 0x37
        enter_deep_sleep = 0x10,
    };

    pub fn init(comptime display: Display, pins: Pins(display.pin_config)) void {
        std.log.debug("Writing pin: {}, value: {}", .{ 9, 1 });
        pins.cs.put(1);

        std.log.debug("\n--------------------", .{});
        std.log.debug("Init:\n", .{});

        display.reset(pins);
        std.log.debug("sleep for {}ms", .{100});
        time.sleep_ms(100);

        display.wait_while_busy(pins);
        display.send_command(pins, Command.swreset);
        display.wait_while_busy(pins);

        display.send_command(pins, Command.driver_output_control);

        display.send_data(pins, display.epd_config.init_sequence[0]);
        display.send_data(pins, display.epd_config.init_sequence[1]);
        display.send_data(pins, display.epd_config.init_sequence[2]);

        display.send_command(pins, Command.data_entry_mode);
        display.send_data(pins, 0x03);

        display.set_windows(pins, 0, 0, (display.epd_config.width - 1), (display.epd_config.height - 1));
        display.set_cursor(pins, 0, 0);

        display.send_command(pins, Command.border_waveform);
        display.send_data(pins, 0x05);

        display.send_command(pins, Command.display_update_control);
        display.send_data(pins, 0x00);
        display.send_data(pins, 0x80);

        display.send_command(pins, Command.read_built_in_temperature_sensor);
        display.send_data(pins, 0x80);

        display.wait_while_busy(pins);

        display.lut_by_host(pins, display.epd_config.lut);
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

    fn send_command(comptime display: Display, pins: Pins(display.pin_config), command: Command) void {
        std.log.debug("Writing pin: {}, value: {}", .{ 8, 0 });
        pins.dc.put(0);
        std.log.debug("Writing pin: {}, value: {}", .{ 9, 0 });
        pins.cs.put(0);
        std.log.debug("Write byte to SPI: {x}", .{@enumToInt(command)});
        _ = display.spi.write(&[_]u8{@enumToInt(command)});
        std.log.debug("Writing pin: {}, value: {}", .{ 9, 1 });
        pins.cs.put(1);
    }

    fn send_data(comptime display: Display, pins: Pins(display.pin_config), data: u8) void {
        std.log.debug("Writing pin: {}, value: {}", .{ 8, 1 });
        pins.dc.put(1);
        std.log.debug("Writing pin: {}, value: {}", .{ 9, 0 });
        pins.cs.put(0);
        std.log.debug("Write byte to SPI: {x}", .{data});
        _ = display.spi.write(&[_]u8{data});
        std.log.debug("Writing pin: {}, value: {}", .{ 9, 1 });
        pins.cs.put(1);
    }

    pub fn wait_while_busy(comptime display: Display, pins: Pins(display.pin_config)) void {
        while (true) {
            std.log.debug("Reading pin: {}, returning: {}", .{ 13, 0 });
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
        display.send_command(pins, Command.display_update_sequence_option);
        display.send_data(pins, 0xc7);
        display.send_command(pins, Command.activate_display_update_sequence);
        display.wait_while_busy(pins);
    }

    pub fn set_windows(comptime display: Display, pins: Pins(display.pin_config), xStart: u16, yStart: u16, xEnd: u16, yEnd: u16) void {
        display.send_command(pins, Command.set_ram_x_address_start_end_position);
        display.send_data(pins, @truncate(u8, (xStart >> 3)));
        display.send_data(pins, @truncate(u8, (xEnd >> 3)));

        display.send_command(pins, Command.set_ram_y_address_start_end_position);
        display.send_data(pins, @truncate(u8, yStart));
        display.send_data(pins, @truncate(u8, (yStart >> 8)));
        display.send_data(pins, @truncate(u8, yEnd));
        display.send_data(pins, @truncate(u8, (yEnd >> 8)));
    }

    pub fn set_cursor(comptime display: Display, pins: Pins(display.pin_config), xStart: u16, yStart: u16) void {
        display.send_command(pins, Command.set_ram_x_address_counter);
        display.send_data(pins, @truncate(u8, xStart));

        display.send_command(pins, Command.set_ram_y_address_counter);
        display.send_data(pins, @truncate(u8, yStart));
        display.send_data(pins, @truncate(u8, (yStart >> 8)));
    }

    pub fn set_lut(comptime display: Display, pins: Pins(display.pin_config), lut: [159]u8) void {
        display.send_command(pins, Command.write_LUT_register);

        for (lut[0..153]) |byte| {
            display.send_data(pins, byte);
        }

        display.wait_while_busy(pins);
    }

    pub fn lut_by_host(comptime display: Display, pins: Pins(display.pin_config), lut: [159]u8) void {
        display.set_lut(pins, lut);

        display.send_command(pins, Command.@"0x3f");
        display.send_data(pins, @enumToInt(EOPT.normal));

        display.send_command(pins, Command.gate_voltage);
        display.send_data(pins, @enumToInt(VGH.@"20V"));

        display.send_command(pins, Command.source_voltage);
        display.send_data(pins, @enumToInt(VSH.@"15V"));
        display.send_data(pins, @enumToInt(VSH.unknown));
        display.send_data(pins, @enumToInt(VSL.@"-15V"));

        display.send_command(pins, Command.vcom);
        display.send_data(pins, @enumToInt(VCOM.@"-1.3_to_-1.4"));
    }
    pub fn clear(comptime display: Display, pins: Pins(display.pin_config)) void {
        std.log.debug("\n--------------------", .{});
        std.log.debug("Clear:\n", .{});
        const screenWidth = if (display.epd_config.width % 8 == 0) (display.epd_config.width / 8) else (display.epd_config.width / 8 + 1);
        const screenHeight = display.epd_config.height;

        display.send_command(pins, Command.write_image_to_ram);

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
        display.send_command(pins, Command.enter_deep_sleep);
        display.send_data(pins, 0x01);
        time.sleep_ms(100);
    }

    pub fn show_image(comptime display: Display, pins: Pins(display.pin_config), image: []const u8) void {
        std.log.debug("\n--------------------", .{});
        std.log.debug("Display:\n", .{});
        const screenWidth = if (display.epd_config.width % 8 == 0) (display.epd_config.width / 8) else (display.epd_config.width / 8 + 1);
        const screenHeight = display.epd_config.height;

        display.send_command(pins, Command.write_image_to_ram);
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

// predefined configurations

pub const epd_2in13_V3_config = EpdConfiguration{
    .width = 122,
    .height = 250,
    .lut = [159]u8{ 0x80, 0x4A, 0x40, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x40, 0x4A, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x80, 0x4A, 0x40, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x40, 0x4A, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xF, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xF, 0x0, 0x0, 0xF, 0x0, 0x0, 0x2, 0xF, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x0, 0x0, 0x0, 0x22, 0x17, 0x41, 0x0, 0x32, 0x36 },
    .init_sequence = [_]u8{ 0xf9, 0x00, 0x00 },
};

pub const epd_2in9_config = EpdConfiguration{
    .width = 128,
    .height = 296,
    .lut = [159]u8{
        //   0           1      2  3  4  5  6  7       8      9 10 11
        0b10000000, 0b01100110, 0, 0, 0, 0, 0, 0, 0b01000000, 0, 0, 0, // LUT 0 (black to black)
        0b00010000, 0b01100110, 0, 0, 0, 0, 0, 0, 0b00100000, 0, 0, 0, // LUT 1 (black to white)
        0b10000000, 0b01100110, 0, 0, 0, 0, 0, 0, 0b01000000, 0, 0, 0, // LUT 2 (white to black)
        0b00010000, 0b01100110, 0, 0, 0, 0, 0, 0, 0b00100000, 0, 0, 0, // LUT 3 (white to white)
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // LUT 4
        //TP[A]
        //  TP[B]
        //      SR[AB]
        //          TB[C]
        //              TB[D]
        //                  SR[CD]
        //                      RP
        20, 8, 0, 0, 0, 0, 1, // Group 0
        10, 10, 0, 10, 10, 0, 1, // Group 1
        0, 0, 0, 0, 0, 0, 0, // Group 2
        0, 0, 0, 0, 0, 0, 0, // Group 3
        0, 0, 0, 0, 0, 0, 0, // Group 4
        0, 0, 0, 0, 0, 0, 0, // Group 5
        0, 0, 0, 0, 0, 0, 0, // Group 6
        0, 0, 0, 0, 0, 0, 0, // Group 7
        20, 8, 0, 1, 0, 0, 1, // Group 8
        0, 0, 0, 0, 0, 0, 1, // Group 9
        0, 0, 0, 0, 0, 0, 0, // Group 11
        0, 0, 0, 0, 0, 0, 0, // Group 12
        0x44, 0x44, 0x44, 0x44, 0x44, 0x44, // Framerates (FR[0] to FR[11])
        0, 0, 0, // Gate scan selection (XON)
        0x22, // EOPT = Normal 153
        0x17, // VGH  = 20V 154
        0x41, // VSH1 = 15 V 155
        0, // VSH2 = Unknown 156
        0x32, // VSL  = -15 V 157
        0x36, // VCOM = -1.3 to -1.4 (not shown on datasheet) 158
    },
    .init_sequence = [_]u8{ 0x27, 0x01, 0x00 },
};
