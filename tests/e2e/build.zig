const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const e2e_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const pg = b.dependency("pg", .{
        .target = target,
        .optimize = optimize,
    });
    e2e_mod.addImport("pg", pg.module("pg"));

    const e2e_tests = b.addTest(.{
        .root_module = e2e_mod,
        .test_runner = b.path("test_runner.zig"),
    });
    const run_e2e_tests = b.addRunArtifact(e2e_tests);
    const test_step = b.step("test", "Run e2e tests");
    test_step.dependOn(&run_e2e_tests.step);
}
