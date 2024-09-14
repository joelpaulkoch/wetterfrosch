const std = @import("std");
const Builder = std.build.Builder;
const Step = std.build.Step;
const LibExeObjStep = std.build.LibExeObjStep;

const builtin = @import("builtin");
const MicroZig = @import("microzig/build");
const rp2040 = @import("microzig/bsp/raspberrypi/rp2040");
const uf2 = @import("microzig/tools/uf2");

pub fn build(b: *std.Build) void {
    const mz = MicroZig.init(b, .{});
    const optimize = b.standardOptimizeOption(.{});

    const firmware = mz.add_firmware(b, .{
        .name = "wetterfrosch",
        .target = rp2040.boards.raspberrypi.pico,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });

    // `install_firmware()` is the MicroZig pendant to `Build.installArtifact()`
    // and allows installing the firmware as a typical firmware file.
    //
    // This will also install into `$prefix/firmware` instead of `$prefix/bin`.
    mz.install_firmware(b, firmware, .{});

    // For debugging, we also always install the firmware as an ELF file
    mz.install_firmware(b, firmware, .{ .format = .elf });

    const test_step = b.step("test", "Run unit tests");
    const unit_tests = b.addTest(.{ .root_source_file = b.path("src/main.zig") });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    test_step.dependOn(&run_unit_tests.step);
}
