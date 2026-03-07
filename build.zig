const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const window_demo_flag = b.option(bool, "window_demo", "Run SDL window demo in main") orelse false;
    const window_demo = window_demo_flag;

    const build_options = b.addOptions();
    build_options.addOption(bool, "window_demo", window_demo);

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("analog_ui", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    mod.addIncludePath(b.path("src/c"));
    mod.addIncludePath(sdl_dep.path("include"));
    mod.addCSourceFiles(.{
        .root = b.path("src/c"),
        .files = &.{ "clay_impl.c", "stb_truetype_impl.c" },
        .flags = &.{},
    });

    const exe = b.addExecutable(.{
        .name = "analog_ui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "analog_ui", .module = mod },
            },
        }),
    });

    exe.root_module.addOptions("build_options", build_options);
    exe.root_module.addIncludePath(sdl_dep.path("include"));

    if (window_demo) {
        exe.linkLibrary(sdl_dep.artifact("SDL3"));
    }

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    // Test steps
    const test_unit_step = b.step("test-unit", "Run unit tests");
    test_unit_step.dependOn(&run_mod_tests.step);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
