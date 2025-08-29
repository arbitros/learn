const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "learn",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const glfw_mod = b.addModule("glfw", .{
        .root_source_file = b.path("src/glfw.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.1",
        .profile = .core,
        .extensions = &.{ .ARB_clip_control, .NV_scissor_exclusive },
    });

    const zig_matrix_dep = b.dependency("zig_matrix", .{
        .target = target,
        .optimize = optimize,
    });

    if (builtin.os.tag == .windows) {
        glfw_mod.addLibraryPath(b.path("glfw/lib-vc2022"));
        glfw_mod.addIncludePath(b.path("glfw/include"));
        glfw_mod.linkSystemLibrary("glfw3", .{});
    }

    exe.root_module.addImport("zig_matrix", zig_matrix_dep.module("zig_matrix"));
    exe.root_module.addImport("glfw", glfw_mod);
    exe.root_module.addImport("gl", gl_bindings);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    run_cmd.cwd = b.path(".");

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    unit_tests.root_module.addImport("zig_matrix", zig_matrix_dep.module("zig_matrix"));
    unit_tests.root_module.addImport("glfw", glfw_mod);
    unit_tests.root_module.addImport("gl", gl_bindings);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
