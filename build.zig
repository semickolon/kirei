const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = std.zig.CrossTarget{
        .cpu_arch = std.Target.Cpu.Arch.riscv32,
        .os_tag = std.Target.Os.Tag.freestanding,
        .abi = std.Target.Abi.eabi,
        .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
        .cpu_features_add = std.Target.riscv.featureSet(&[_]std.Target.riscv.Feature{ .c, .m, .a }),
    };

    const optimize = std.builtin.OptimizeMode.ReleaseSmall;

    const exe = b.addExecutable(.{
        .name = "fak-kiwi",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const link_file_path = comptime root() ++ "src/link.ld";
    exe.setLinkerScriptPath(std.build.FileSource{ .path = link_file_path });
    exe.strip = false; // set to false to keep debug symbols for llvm-objdump
    exe.addAssemblyFile(.{ .path = "./src/startup.S" });

    const f = [_][]const u8{};

    exe.addCSourceFile(.{
        .file = .{ .path = "src/lib/ch583/libISP583.a" },
        .flags = f[0..],
    });
    exe.addCSourceFile(.{
        .file = .{ .path = "src/lib/ch583/LIBCH58xBLE.a" },
        .flags = f[0..],
    });
    exe.addCSourceFile(.{
        .file = .{ .path = "src/lib/ch583/calibration_lsi.c" },
        .flags = f[0..],
    });

    exe.addIncludePath(.{ .path = "src/lib/ch583" });

    b.installArtifact(exe);
}

fn root() []const u8 {
    return comptime (std.fs.path.dirname(@src().file) orelse ".") ++ "/";
}
