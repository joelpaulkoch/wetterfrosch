const std = @import("std");

const rp2040 = @import("rp2040");
const gpio = rp2040.gpio;
const time = rp2040.time;
const GlobalConfiguration = rp2040.pins.GlobalConfiguration;
const Pins = rp2040.pins.Pins;
const SPI = rp2040.spi.SPI;

const Display = struct {
    width: comptime_int,
    height: comptime_int,
    pin_config: GlobalConfiguration,

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
        data_entry_mode  = 0x11,
        border_waveform = 0x3C,
        display_update_control = 0x21,
        read_built_in_temperature_sensor = 0x18,
        // 0x3f
        // 0x32
        // 0x24
        // 0x37
        enter_deep_sleep = 0x10,
         };

    pub fn reset(pins: Pins(.pin_config)) void {
        pins.rst.put(1);
        time.sleep_ms(20);
        pins.rst.put(0);
        time.sleep_ms(2);
        pins.rst.put(1);
        time.sleep_ms(20);
    }

    pub fn send_command(self: Display, command: u8) void {
        self.pins.dc.put(0);
        self.pins.cs.put(0);
        const c = [_]u8{command};
        _ = self.spi.write(c[0..]);
        self.pins.cs.put(1);
    }

    pub fn send_data(self: Display, data: u8) void {
        self.pins.dc.put(1);
        self.pins.cs.put(0);
        const d = [_]u8{data};
        _ = self.spi.write(d[0..]);
        self.pins.cs.put(1);
    }

    pub fn wait_while_busy(
        self: Display,
    ) void {
        while (true) {
            if (self.pins.busy.read() == 0) {
                break;
            }
            time.sleep_ms(10);
        }
        time.sleep_ms(10);
    }

    pub fn turn_on(self: Display) void {
        self.send_command(0x22);
        self.send_data(0xc7);
        self.send_command(0x20);
        self.wait_while_busy();
    }

    pub fn set_windows(self: Display, xStart: u16, yStart: u16, xEnd: u16, yEnd: u16) void {
        self.send_command(0x44);
        self.send_data(@truncate(u8, (xStart >> 3)));
        self.send_data(@truncate(u8, (xEnd >> 3)));
        // EPD_2in13_V3_SendCommand(0x44); // SET_RAM_X_ADDRESS_START_END_POSITION
        // EPD_2in13_V3_SendData((Xstart>>3) & 0xFF);
        // EPD_2in13_V3_SendData((Xend>>3) & 0xFF);

        self.send_command(0x45);
        self.send_data(@truncate(u8, yStart));
        self.send_data(@truncate(u8, (yStart >> 8)));
        self.send_data(@truncate(u8, yEnd));
        self.send_data(@truncate(u8, (yEnd >> 8)));
        // EPD_2in13_V3_SendCommand(0x45); // SET_RAM_Y_ADDRESS_START_END_POSITION
        // EPD_2in13_V3_SendData(Ystart & 0xFF);
        // EPD_2in13_V3_SendData((Ystart >> 8) & 0xFF);
        // EPD_2in13_V3_SendData(Yend & 0xFF);
        // EPD_2in13_V3_SendData((Yend >> 8) & 0xFF);
    }

    pub fn set_cursor(self: Display, xStart: u16, yStart: u16) void {
        self.send_command(0x4E);
        self.send_data(@truncate(u8, xStart));

        self.send_command(0x4F);
        self.send_data(@truncate(u8, yStart));
        self.send_data(@truncate(u8, (yStart >> 8)));
    }

    pub fn set_lut(self: Display, lut: [159]u8) void {
        self.send_command(0x32);
        for (lut) |byte| {
            self.send_data(byte);
        }
        self.wait_while_busy();
    }

    pub fn lut_by_host(self: Display, lut: [159]u8) void {
        self.set_lut(lut);

        self.send_command(0x3f);
        self.send_data(lut[153]);

        self.send_command(0x03);
        self.send_data(lut[154]);

        self.send_command(0x04);
        self.send_data(lut[155]);
        self.send_data(lut[156]);
        self.send_data(lut[157]);

        self.send_command(0x2c);
        self.send_data(lut[158]);
    }

    pub fn init(self: Display, lut: [159]u8) void {
        self.reset();
        time.sleep_ms(100);

        self.wait_while_busy();
        self.send_command(0x12);
        self.wait_while_busy();

        self.send_command(0x01);
        self.send_data(0xf9);
        self.send_data(0x00);
        self.send_data(0x00);

        self.send_command(0x11);
        self.send_data(0x03);

        self.set_windows(0, 0, .width - 1, .height - 1);
        self.set_cursor(0, 0);

        self.send_command(0x3C);
        self.send_data(0x05);

        self.send_command(0x21);
        self.send_data(0x00);
        self.send_data(0x80);

        self.send_command(0x18);
        self.send_data(0x80);

        self.wait_while_busy();

        self.lut_by_host(lut);
    }

    pub fn clear(self: Display) void {
        const screenWidth = if (.width % 8 == 0) (.width / 8) else (.width / 8 + 1);
        const screenHeight = .height;

        self.send_command(0x24);

        var j: u8 = 0;
        while (j < screenHeight) : (j += 1) {
            var i: u8 = 0;
            while (i < screenWidth) : (i += 1) {
                self.send_data(0xFF);
            }
        }

        self.turn_on();
    }

    pub fn sleep(self: Display) void {
        _ = self;
        send_command(0x10);
        send_data(0x01);
        time.sleep_ms(100);
    }

    pub fn display_black(self: Display) void {
        _ = self;
        const screenWidth = if (.width % 8 == 0) (.width / 8) else (.width / 8 + 1);
        const screenHeight = .height;

        send_command(0x24);

        var j: u16 = 0;
        while (j < screenHeight) : (j += 1) {
            var i: u16 = 0;
            while (i < screenWidth) : (i += 1) {
                send_data(0x00);
            }
        }

        turn_on();
    }
};

test "display module compiles" {
    const display = Display{ .width = 0, .height = 0, .pin_config = GlobalConfiguration{} };
    _ = display;
}
