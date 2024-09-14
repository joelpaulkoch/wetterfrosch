const std = @import("std");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;
const time = rp2040.time;
const Pins = rp2040.pins.Pins;
const SPI = rp2040.spi.SPI;

const images = @import("images.zig");
const display = @import("display.zig");
const weather = @import("weather.zig");
const font = @import("font.zig");

const pin_config = rp2040.pins.GlobalConfiguration{
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

const spi = rp2040.spi.instance.SPI1;

const uart = rp2040.uart.num(0);
const baud_rate = 115200;
const uart_tx_pin = gpio.num(0);
const uart_rx_pin = gpio.num(1);

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub const microzig_options = .{
    .log_level = .debug,
    .logFn = rp2040.uart.log,
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

    try spi.apply(.{ .clock_config = rp2040.clock_config, .baud_rate = 4000 * 1000 });

    const epd_config = display.epd_2in13_V2_config;
    const epaper = display.Display{ .epd_config = epd_config, .pin_config = pin_config, .spi = spi };

    pins.led.put(1);
    time.sleep_ms(200);
    pins.led.put(0);

    epaper.init(pins);
    epaper.clear(pins);
    pins.led.put(0);
    time.sleep_ms(500);
    pins.led.put(1);

    const text =
        \\ hallohallohallohalloha
    ;
    const image_layout: images.ImageLayout = .{
        .width = epd_config.width,
        .height = epd_config.height,
        .horizontal = true,
    };

    const font_size: font.FontSize = .{ .width = 5, .height = 8 };
    const bytes_per_image_line = comptime std.math.divCeil(u16, epd_config.width, 8) catch unreachable;
    const bytes_in_image = comptime epd_config.height * bytes_per_image_line;

    var bytes = [_]u8{0} ** bytes_in_image;
    if (images.text_to_image(image_layout, font_size, text)) |image| {
        _ = images.image_to_bytes_negated(image_layout, image, &bytes);
    } else |err| {
        const err_image =
            switch (err) {
            images.TextError.TextTooLong => images.text_to_image(image_layout, font_size, "Error: too long") catch unreachable,
            images.TextError.TooManyTextLines => images.text_to_image(image_layout, font_size, "Error: too many lines") catch unreachable,
        };
        _ = images.image_to_bytes_negated(image_layout, err_image, &bytes);
    }

    epaper.show_image(pins, &bytes);
    time.sleep_ms(10000);
    // epaper.init(pins);
    // epaper.clear(pins);
    time.sleep_ms(2000);
    epaper.sleep(pins);

    var count: u2 = 0;
    while (count < 3) : (count += 1) {
        pins.led.put(1);
        time.sleep_ms(250);
        pins.led.put(0);
        time.sleep_ms(250);
    }
}

test {
    _ = images;
    // _ = display;
    _ = weather;
    _ = font;
}
