const std = @import("std");
const rp2040 = @import("rp2040");

pub fn build(b: *std.Build) void {
    const umm = b.createModule(.{ .source_file = .{ .path = "src/lib/umm/umm.zig" } });
    const uuid = b.createModule(.{ .source_file = .{ .path = "src/lib/uuid/uuid.zig" } });
    const s2s = b.createModule(.{ .source_file = .{ .path = "src/lib/s2s/s2s.zig" } });
    _ = s2s;

    const microzig = @import("microzig").init(b, "microzig");

    // step: keymap
    const nickel = b.addSystemCommand(&.{ "nickel", "export", "--format", "raw", "-f", "src/keymap.ncl" });
    nickel.extra_file_dependencies = &.{
        "src/kirei/ncl/keymap.ncl",
        "src/kirei/ncl/lib.ncl",
        "src/kirei/ncl/zig.ncl",
        "src/keymap.ncl",
    };

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

    const embedded_key_map = platform != .testing;

    const options = b.addOptions();
    options.addOption(bool, "embedded_key_map", embedded_key_map);

    const keymap = b.createModule(.{
        .source_file = nickel.captureStdOut(),
        .dependencies = &.{},
    });

    if (platform == .testing) {
        const nickel_test = b.addSystemCommand(&.{ "nickel", "export", "--format", "raw", "-f", "src/platforms/testing/tests/_gen.ncl" });
        nickel_test.extra_file_dependencies = &.{
            "src/kirei/ncl/keymap.ncl",
            "src/kirei/ncl/lib.ncl",
            "src/kirei/ncl/zig.ncl",
            "src/platforms/testing/tests/key_press.ncl",
        };

        exe.addModule("test", b.createModule(.{
            .source_file = nickel_test.captureStdOut(),
            .dependencies = &.{},
        }));
    }

    const kirei = b.createModule(.{
        .source_file = .{ .path = "src/kirei/engine.zig" },
        .dependencies = &.{
            .{ .name = "keymap", .module = keymap },
            .{ .name = "config", .module = options.createModule() },
        },
    });

    const common = b.createModule(.{
        .source_file = .{ .path = "src/common/common.zig" },
        .dependencies = &.{
            .{ .name = "kirei", .module = kirei },
        },
    });

    if (microzig_fw) |fw| {
        fw.addAppDependency("kirei", kirei, .{});
        fw.addAppDependency("common", common, .{});
        fw.addAppDependency("umm", umm, .{});
        fw.addAppDependency("uuid", uuid, .{});
    }

    exe.addModule("kirei", kirei);
    exe.addModule("common", common);
    exe.addModule("umm", umm);
    exe.addModule("uuid", uuid);

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
