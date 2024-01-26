const std = @import("std");

pub fn build(b: *std.Build) void {
    const use_testing = b.option(bool, "testing", "testing time?") orelse false;

    const target = if (use_testing)
        b.standardTargetOptions(.{})
    else
        std.zig.CrossTarget{
            .cpu_arch = std.Target.Cpu.Arch.riscv32,
            .os_tag = std.Target.Os.Tag.freestanding,
            .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
            .cpu_features_add = std.Target.riscv.featureSet(&.{ .c, .m, .a }),
        };

    const optimize = if (use_testing) b.standardOptimizeOption(.{}) else std.builtin.OptimizeMode.ReleaseFast;

    const modules = .{
        .kirei = b.createModule(.{ .source_file = .{ .path = "src/kirei/engine.zig" } }),
        .umm = b.createModule(.{ .source_file = .{ .path = "src/lib/umm/umm.zig" } }),
        .uuid = b.createModule(.{ .source_file = .{ .path = "src/lib/uuid/uuid.zig" } }),
    };

    const root_path = if (use_testing)
        "src/platforms/testing/main.zig"
    else
        "src/platforms/ch58x/main.zig";

    const exe = b.addExecutable(.{
        .name = if (use_testing) "kirei" else "kirei-ch58x",
        .root_source_file = .{ .path = root_path },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("kirei", modules.kirei);
    exe.addModule("umm", modules.umm);
    exe.addModule("uuid", modules.uuid);

    if (!use_testing) {
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
