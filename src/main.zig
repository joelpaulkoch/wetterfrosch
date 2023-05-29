const std = @import("std");

const microzig = @import("microzig");
const display = @import("display.zig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;
const time = rp2040.time;
const GlobalConfiguration = rp2040.pins.GlobalConfiguration;
const Pins = rp2040.pins.Pins;
const SPI = rp2040.spi.SPI;

const images = @import("images.zig");

const pin_config = GlobalConfiguration{
    .GPIO8 = .{
        .name = "dc",
        .direction = .out,
    },
    .GPIO9 = .{
        .name = "cs",
        .direction = .out,
    },
    .GPIO10 = .{ .name = "clk", .direction = .out, .function = .SPI1_SCK },
    .GPIO11 = .{ .name = "mosi", .direction = .out, .function = .SPI1_TX },
    .GPIO12 = .{
        .name = "rst",
        .direction = .out,
    },
    .GPIO13 = .{
        .name = "busy",
        .direction = .in,
    },
    .GPIO25 = .{
        .name = "led",
        .direction = .out,
    },
};

const spi = rp2040.spi.num(1);

const uart = rp2040.uart.num(0);
const baud_rate = 115200;
const uart_tx_pin = gpio.num(0);
const uart_rx_pin = gpio.num(1);

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub const std_options = struct {
    pub const log_level = .info;
    pub const logFn = rp2040.uart.log;
};

pub fn main() !void {
    uart.apply(.{
        .baud_rate = baud_rate,
        .tx_pin = uart_tx_pin,
        .rx_pin = uart_rx_pin,
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.init_logger(uart);

    const pins = pin_config.apply();
    pins.cs.put(1);

    spi.apply(.{ .clock_config = rp2040.clock_config, .sck_pin = gpio.num(10), .csn_pin = gpio.num(9), .tx_pin = gpio.num(11), .baud_rate = 4000 * 1000 });

    const epaper = display.Display{ .epd_config = display.epd_2in13_V3_config, .pin_config = pin_config, .spi = spi };

    pins.led.put(1);
    time.sleep_ms(200);
    pins.led.put(0);

    epaper.init(pins);
    pins.led.put(1);
    time.sleep_ms(5000);
    epaper.clear(pins);
    pins.led.put(0);
    time.sleep_ms(5000);
    pins.led.put(1);

    epaper.show_image(pins, &images.image_2in13);
    time.sleep_ms(10000);

    epaper.init(pins);
    epaper.clear(pins);
    time.sleep_ms(10000);
    epaper.sleep(pins);
    time.sleep_ms(5000);

    var count: u2 = 0;
    while (count < 3) : (count += 1) {
        pins.led.put(1);
        time.sleep_ms(250);
        pins.led.put(0);
        time.sleep_ms(250);
    }
}
