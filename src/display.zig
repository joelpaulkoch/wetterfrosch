const std = @import("std");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;
const time = rp2040.time;
const GlobalConfiguration = rp2040.pins.GlobalConfiguration;
const Pins = rp2040.pins.Pins;
const SPI = rp2040.spi.SPI;

pub const Display = struct {
    epd_config: EpdConfiguration,
    pin_config: GlobalConfiguration,
    spi: SPI,

    pub const EpdConfiguration = struct {
        width: comptime_int,
        height: comptime_int,
        init_sequence: []const InitBlock,
    };
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

    pub const Command = enum(u8) {
        clear = 0x00,
        display_update_sequence_option = 0x22,
        activate_display_update_sequence = 0x20,
        gate_voltage = 0x03,
        source_voltage = 0x04,
        vcom = 0x2C,
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
        set_EOPT = 0x3F, // 0x3f
        write_LUT_register = 0x32, // 0x32
        write_image_to_ram = 0x24, // 0x24 write image to ram
        write_image_to_ram_color = 0x26, // 0x26 write image to ram
        // 0x37
        enter_deep_sleep = 0x10,
        set_analog_block_control = 0x74,
        set_digital_block_control = 0x7E,
        dummy_line = 0x3A,
        gate_time = 0x3B,
    };
    pub const InitBlock = struct {
        command: Command,
        data: []const u8,
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

        for (display.epd_config.init_sequence[0..]) |init_block| {
            display.send_command(pins, init_block.command);
            for (init_block.data[0..]) |data| {
                display.send_data(pins, data);
            }
            time.sleep_ms(100);
            if (init_block.command == Command.write_LUT_register) {
                display.wait_while_busy(pins);
            }
        }

        display.wait_while_busy(pins);
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
            time.sleep_ms(50);
        }
        std.log.debug("sleep for {}ms", .{10});
        time.sleep_ms(50);
    }

    pub fn turn_on(comptime display: Display, pins: Pins(display.pin_config)) void {
        display.send_command(pins, Command.display_update_sequence_option);
        display.send_data(pins, 0xc7);
        display.send_command(pins, Command.activate_display_update_sequence);
        display.wait_while_busy(pins);
    }

    pub fn clear(comptime display: Display, pins: Pins(display.pin_config)) void {
        std.log.debug("\n--------------------", .{});
        std.log.debug("Clear:\n", .{});
        const screenWidth = std.math.divCeil(u16, display.epd_config.width, 8) catch unreachable;
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
        const screenWidth = std.math.divCeil(u16, display.epd_config.width, 8) catch unreachable;
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

pub const epd_2in13_V2_config = Display.EpdConfiguration{
    .width = 122,
    .height = 250,
    .init_sequence = &[_]Display.InitBlock{
        .{ .command = Display.Command.set_analog_block_control, .data = &[_]u8{0x54} },
        .{ .command = Display.Command.set_digital_block_control, .data = &[_]u8{0x3B} },
        .{ .command = Display.Command.driver_output_control, .data = &[_]u8{ 0xf9, 0x00, 0x00 } },
        .{ .command = Display.Command.data_entry_mode, .data = &[_]u8{0x03} },
        .{ .command = Display.Command.set_ram_x_address_start_end_position, .data = &[_]u8{ 0x00, 0x0F } },
        .{ .command = Display.Command.set_ram_y_address_start_end_position, .data = &[_]u8{ 0x00, 0x00, 0xF9, 0x00 } },
        .{ .command = Display.Command.border_waveform, .data = &[_]u8{0x03} },
        .{ .command = Display.Command.vcom, .data = &[_]u8{0x55} },
        .{ .command = Display.Command.gate_voltage, .data = &[_]u8{0x15} },
        .{ .command = Display.Command.source_voltage, .data = &[_]u8{ 0x41, 0xA8, 0x32 } },
        .{ .command = Display.Command.dummy_line, .data = &[_]u8{0x30} },
        .{ .command = Display.Command.gate_time, .data = &[_]u8{0x0A} },
        .{
            .command = Display.Command.write_LUT_register,
            .data = &[70]u8{
                //keep format
                0x80, 0x60, 0x40, 0x00, 0x00, 0x00, 0x00, //LUT0: BB:     VS 0 ~7
                0x10, 0x60, 0x20, 0x00, 0x00, 0x00, 0x00, //LUT1: BW:     VS 0 ~7
                0x80, 0x60, 0x40, 0x00, 0x00, 0x00, 0x00, //LUT2: WB:     VS 0 ~7
                0x10, 0x60, 0x20, 0x00, 0x00, 0x00, 0x00, //LUT3: WW:     VS 0 ~7
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //LUT4: VCOM:   VS 0 ~7
                0x03, 0x03, 0x00, 0x00, 0x02, // TP0 A~D RP0
                0x09, 0x09, 0x00, 0x00, 0x02, // TP1 A~D RP1
                0x03, 0x03, 0x00, 0x00, 0x02, // TP2 A~D RP2
                0x00, 0x00, 0x00, 0x00, 0x00, // TP3 A~D RP3
                0x00, 0x00, 0x00, 0x00, 0x00, // TP4 A~D RP4
                0x00, 0x00, 0x00, 0x00, 0x00, // TP5 A~D RP5
                0x00, 0x00, 0x00, 0x00, 0x00, // TP6 A~D RP6
            },
        },
        .{ .command = Display.Command.set_ram_x_address_counter, .data = &[_]u8{0x00} },
        .{ .command = Display.Command.set_ram_y_address_counter, .data = &[_]u8{ 0x00, 0x00 } },
    },
};

pub const epd_2in9_V2_config = Display.EpdConfiguration{
    .width = 128,
    .height = 296,
    .init_sequence = &[_]Display.InitBlock{
        .{ .command = Display.Command.driver_output_control, .data = &[_]u8{ 0x27, 0x01, 0x00 } },
        .{ .command = Display.Command.data_entry_mode, .data = &[_]u8{0x03} },
        .{ .command = Display.Command.set_ram_x_address_start_end_position, .data = &[_]u8{ 0x00, (127 >> 3) & 0xFF } },
        .{ .command = Display.Command.set_ram_y_address_start_end_position, .data = &[_]u8{ 0x00, 0x00, 295 & 0xFF, (295 >> 8) & 0xFF } },
        .{ .command = Display.Command.display_update_control, .data = &[_]u8{ 0x00, 0x80 } },
        .{ .command = Display.Command.set_ram_x_address_counter, .data = &[_]u8{0x00} },
        .{ .command = Display.Command.set_ram_y_address_counter, .data = &[_]u8{ 0x00, 0x00 } },
        .{
            .command = Display.Command.write_LUT_register,
            .data = &[153]u8{
                //keep format
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
            },
        },
        .{ .command = Display.Command.set_EOPT, .data = &[_]u8{0x22} },
        .{ .command = Display.Command.gate_voltage, .data = &[_]u8{0x17} },
        .{ .command = Display.Command.source_voltage, .data = &[_]u8{ 0x41, 0x00, 0x32 } },
        .{ .command = Display.Command.vcom, .data = &[_]u8{0x36} },
    },
};
