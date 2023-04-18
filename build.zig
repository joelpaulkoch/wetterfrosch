const std = @import("std");
const Builder = std.build.Builder;
const Step = std.build.Step;
const LibExeObjStep = std.build.LibExeObjStep;

const builtin = @import("builtin");
const uf2 = @import("deps/uf2/src/main.zig");
const rp2040 = @import("deps/rp2040/build.zig");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    // const target = b.standardTargetOptions(.{});

    var exe = rp2040.addPiPicoExecutable(b, "wetterfrosch", "src/main.zig", .{}
    // .target = target,
    );
    exe.setBuildMode(mode);

    const uf2_step = uf2.Uf2Step.create(exe.inner, .{
        .family_id = .RP2040,
    });
    uf2_step.install();
    exe.install();

    // const exe_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    // });

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&exe_tests.step);
}