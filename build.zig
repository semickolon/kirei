const std = @import("std");

pub fn build(b: *std.Build) void {
    const hana = b.createModule(.{ .source_file = .{ .path = "src/hana/hana.zig" } });
    const kirei = b.createModule(.{
        .source_file = .{ .path = "src/kirei/engine.zig" },
        .dependencies = &.{
            .{ .name = "hana", .module = hana },
        },
    });
    const umm = b.createModule(.{ .source_file = .{ .path = "src/lib/umm/umm.zig" } });
    const uuid = b.createModule(.{ .source_file = .{ .path = "src/lib/uuid/uuid.zig" } });

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
        enum { testing, ch58x },
        "platform",
        "Platform to build for",
    ) orelse .testing;

    const target = switch (platform) {
        .testing => b.standardTargetOptions(.{}),
        .ch58x => std.zig.CrossTarget{
            .cpu_arch = std.Target.Cpu.Arch.riscv32,
            .os_tag = std.Target.Os.Tag.freestanding,
            .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
            .cpu_features_add = std.Target.riscv.featureSet(&.{ .c, .m, .a }),
        },
    };

    const optimize = b.standardOptimizeOption(.{});

    const root_path = switch (platform) {
        .testing => "src/platforms/testing/main.zig",
        .ch58x => "src/platforms/ch58x/main.zig",
    };

    const exe = b.addExecutable(.{
        .name = switch (platform) {
            .testing => "kirei-testing",
            .ch58x => "kirei-ch58x",
        },
        .root_source_file = .{ .path = root_path },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("kirei", kirei);
    exe.addModule("umm", umm);
    exe.addModule("uuid", uuid);

    if (platform == .testing) {
        exe.addAnonymousModule("keymap", .{ .source_file = keymap_gen_run.captureStdOut() });
    }

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

    b.installArtifact(exe);
}
