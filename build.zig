const std = @import("std");
const rp2040 = @import("rp2040");

const all_test_names = [_][]const u8{
    "key_press/simple",
    "key_press/mods",
    "key_press/weak_mods",
    "key_press/anti_mods",
    "key_toggle/simple",
    "conditionals/layers",
    "conditionals/is_key_pressed",
    "conditionals/mod_morph",
    "conditionals/is_pressed",
};

pub fn build(b: *std.Build) void {
    const umm = b.createModule(.{ .source_file = .{ .path = "src/lib/umm/umm.zig" } });
    const uuid = b.createModule(.{ .source_file = .{ .path = "src/lib/uuid/uuid.zig" } });
    const s2s = b.createModule(.{ .source_file = .{ .path = "src/lib/s2s/s2s.zig" } });
    _ = s2s;

    const microzig = @import("microzig").init(b, "microzig");

    // step: keymap
    const nickel = b.addSystemCommand(&.{ "nickel", "export", "--format", "raw", "src/keymap.ncl" });
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
        "The platform to build for",
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

    const embedded_key_map = platform != .testing;

    const options = b.addOptions();
    options.addOption(bool, "embedded_key_map", embedded_key_map);

    const keymap = b.createModule(.{
        .source_file = nickel.captureStdOut(),
        .dependencies = &.{},
    });

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

    const common_module_names = [_][]const u8{ "kirei", "common", "umm", "uuid" };
    const common_modules = [_]*std.build.Module{ kirei, common, umm, uuid };

    if (platform == .testing) {
        const test_suites = b.option([]const []const u8, "test_suites", "Name of test suites to run") orelse &all_test_names;

        for (test_suites) |ts_name| {
            const temp_ncl_contents = std.fmt.allocPrint(b.allocator, "import \"{s}.ncl\"", .{ts_name}) catch unreachable;
            defer b.allocator.free(temp_ncl_contents);

            const temp_ncl = b.addWriteFile("_test_suite.ncl", temp_ncl_contents);

            const nickel_test = b.addSystemCommand(&.{ "nickel", "export", "--format", "raw", "gen_test_suite.ncl", "-I", ".", "-I", b.pathFromRoot("src") });
            nickel_test.cwd = "src/platforms/testing/tests";

            const echo_tname = b.addSystemCommand(&.{ "echo", "TEST SUITE:", ts_name });
            echo_tname.has_side_effects = true;

            // TODO: Following commented line is not working (https://github.com/ziglang/zig/issues/17715)
            //    nickel_test.has_side_effects = true;
            // Oh well, for now:
            nickel_test.extra_file_dependencies = &.{
                "src/kirei/ncl/keymap.ncl",
                "src/kirei/ncl/lib.ncl",
                "src/kirei/ncl/zig.ncl",
            };

            nickel_test.addArg("-I");
            nickel_test.addDirectoryArg(temp_ncl.getDirectory());
            nickel_test.step.dependOn(&temp_ncl.step);

            const exe = b.addExecutable(.{
                .name = name,
                .target = target,
                .optimize = optimize,
                .root_source_file = .{ .path = root_path },
            });

            exe.addModule("test", b.createModule(.{
                .source_file = nickel_test.captureStdOut(),
                .dependencies = &.{},
            }));

            addModules(exe, &common_module_names, &common_modules);

            const run_test = b.addRunArtifact(exe);
            run_test.step.dependOn(&echo_tname.step);
            b.default_step.dependOn(&run_test.step);
        }
    } else {
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
        }

        addModules(exe, &common_module_names, &common_modules);

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
}

fn addModules(cs: *std.build.Step.Compile, names: []const []const u8, modules: []const *std.build.Module) void {
    std.debug.assert(names.len == modules.len);

    for (names, modules) |name, module| {
        cs.addModule(name, module);
    }
}
