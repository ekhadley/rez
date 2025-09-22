const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/rez.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "rez",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);
    const tests_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests_mod.addImport("rez", lib_mod);
    const lib_unit_tests = b.addTest(.{
        .root_module = tests_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
