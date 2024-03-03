const std = @import("std");
const rp2040 = @import("rp2040");

pub fn build(b: *std.Build) void {
    const kirei = b.createModule(.{
        .source_file = .{ .path = "src/kirei/engine.zig" },
        .dependencies = &.{},
    });
    const common = b.createModule(.{
        .source_file = .{ .path = "src/common/common.zig" },
        .dependencies = &.{
            .{ .name = "kirei", .module = kirei },
        },
    });
    const umm = b.createModule(.{ .source_file = .{ .path = "src/lib/umm/umm.zig" } });
    const uuid = b.createModule(.{ .source_file = .{ .path = "src/lib/uuid/uuid.zig" } });

    const microzig = @import("microzig").init(b, "microzig");

    // step: keymap
    const nickel = b.addSystemCommand(&.{ "nickel", "export", "--format", "raw", "-f", "src/keymap.ncl" });
    nickel.extra_file_dependencies = &.{
        "src/kirei/ncl/keymap.ncl",
        "src/kirei/ncl/utils.ncl",
        "src/keymap.ncl",
    };

    const keymap_gen = b.addExecutable(.{
        .name = "keymap_gen",
        .root_source_file = .{ .path = "src/kirei/build/keymap_gen.zig" },
        .target = std.zig.CrossTarget.fromTarget(b.host.target),
    });

    keymap_gen.addModule("kirei", kirei);
    keymap_gen.addAnonymousModule("keymap_obj", .{ .source_file = nickel.captureStdOut() });

    const keymap_gen_run = b.addRunArtifact(keymap_gen);
    keymap_gen_run.step.dependOn(&nickel.step);

    const keymap_install = b.addInstallFile(keymap_gen_run.captureStdOut(), "keymap.kirei");
    keymap_install.step.dependOn(&keymap_gen_run.step);

    const step_keymap = b.step("keymap", "Build keymap.kirei");
    step_keymap.dependOn(&keymap_install.step);

    // step: default
    const platform = b.option(
        enum { testing, ch58x, rp2040 },
        "platform",
        "Platform to build for",
    ) orelse .testing;

    const target = switch (platform) {
        .ch58x => std.zig.CrossTarget{
            .cpu_arch = std.Target.Cpu.Arch.riscv32,
            .os_tag = std.Target.Os.Tag.freestanding,
            .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
            .cpu_features_add = std.Target.riscv.featureSet(&.{ .c, .m, .a }),
        },
        else => b.standardTargetOptions(.{}),
    };

    const optimize = b.standardOptimizeOption(.{});

    const root_path = switch (platform) {
        .testing => "src/platforms/testing/main.zig",
        .ch58x => "src/platforms/ch58x/main.zig",
        .rp2040 => "src/platforms/rp2040/main.zig",
    };

    const name = switch (platform) {
        .testing => "kirei-testing",
        .ch58x => "kirei-ch58x",
        .rp2040 => "kirei-rp2040",
    };

    const microzig_fw = if (platform == .rp2040)
        microzig.addFirmware(b, .{
            .name = name,
            .target = rp2040.boards.raspberry_pi.pico,
            .optimize = optimize,
            .source_file = .{ .path = root_path },
        })
    else
        null;

    const exe = if (microzig_fw) |fw|
        fw.artifact
    else
        b.addExecutable(.{
            .name = name,
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .path = root_path },
        });

    if (microzig_fw) |fw| {
        fw.addAppDependency("kirei", kirei, .{});
        fw.addAppDependency("common", common, .{});
        fw.addAppDependency("umm", umm, .{});
        fw.addAppDependency("uuid", uuid, .{});
    } else {
        exe.addModule("kirei", kirei);
        exe.addModule("common", common);
        exe.addModule("umm", umm);
        exe.addModule("uuid", uuid);
    }

    // if (microzig_fw == null) {
    //     exe.addAnonymousModule("keymap", .{ .source_file = keymap_gen_run.captureStdOut() });
    // }

    if (platform == .ch58x) {
        const link_file_path = "src/platforms/ch58x/link.ld";
        exe.setLinkerScriptPath(.{ .path = link_file_path });
        exe.addAssemblyFile(.{ .path = "src/platforms/ch58x/startup.S" });

        exe.addCSourceFiles(&.{
            "src/platforms/ch58x/lib/libISP583.a",
            "src/platforms/ch58x/lib/LIBCH58xBLE.a",
            "src/platforms/ch58x/lib/calibration_lsi.c",
        }, &.{});

        exe.addIncludePath(.{ .path = "src/platforms/ch58x/lib" });
    }

    if (microzig_fw) |fw| {
        microzig.installFirmware(b, fw, .{});
    }

    b.installArtifact(exe);
}
