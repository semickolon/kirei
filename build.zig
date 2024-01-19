const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = std.zig.CrossTarget{
        .cpu_arch = std.Target.Cpu.Arch.riscv32,
        .os_tag = std.Target.Os.Tag.freestanding,
        .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
        .cpu_features_add = std.Target.riscv.featureSet(&.{ .c, .m, .a }),
    };

    const optimize = std.builtin.OptimizeMode.ReleaseSmall;

    const modules = .{
        .kirei = b.createModule(.{ .source_file = .{ .path = "src/kirei/engine.zig" } }),
    };

    const exe = b.addExecutable(.{
        .name = "fak-kiwi",
        .root_source_file = .{ .path = "src/platforms/ch58x/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("kirei", modules.kirei);

    const link_file_path = "src/platforms/ch58x/link.ld";
    exe.setLinkerScriptPath(.{ .path = link_file_path });
    exe.addAssemblyFile(.{ .path = "src/platforms/ch58x/startup.S" });

    exe.addCSourceFiles(&.{
        "src/platforms/ch58x/lib/libISP583.a",
        "src/platforms/ch58x/lib/LIBCH58xBLE.a",
        "src/platforms/ch58x/lib/calibration_lsi.c",
    }, &.{});

    exe.addIncludePath(.{ .path = "src/platforms/ch58x/lib" });

    b.installArtifact(exe);
}
