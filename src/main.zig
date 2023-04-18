const std = @import("std");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;
const time = rp2040.time;

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
};

pub fn main() !void {
    const pins = pin_config.apply();
    pins.cs.put(1);

    const spi = rp2040.spi.SPI.init(1, .{ .clock_config = rp2040.clock_config, .baud_rate = 4000 * 1000 });
    _ = spi;

    while (true) {
        pins.led.toggle();
        time.sleepMs(250);
    }
}
