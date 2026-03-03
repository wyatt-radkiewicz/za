const std = @import("std");

pub const Linker = @import("tools/Linker.zig");
const Options = @import("tools/Options.zig");
const Build = std.Build;
const test_suites: []const []const u8 = @import("tests/suites.zon");
const test_queries: []const TestTarget = @import("tests/targets.zon");

/// Testing targets
const TestTarget = struct {
    platform: []const u8,
    target: []const u8,
    cpu: []const u8,

    /// Gets a resolved target from this test target
    fn resolvedTarget(this: @This(), b: *Build) std.Build.ResolvedTarget {
        const query = std.Target.Query.parse(.{
            .arch_os_abi = this.target,
            .cpu_features = this.cpu,
        }) catch @panic("Invalid test target query string!");
        return b.resolveTargetQuery(query);
    }
};

/// Build the test case
fn buildSuite(
    b: *Build,
    suite: []const u8,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: Options,
    za_mod: *Build.Module,
    linker_exe: *Build.Step.Compile,
) *Build.Step.Compile {
    // Create the test module
    const test_mod = b.createModule(.{
        .root_source_file = b.path("tests/runner.zig"),
        .target = target,
        .optimize = optimize,
        .omit_frame_pointer = options.omit_frame_pointer,
    });
    test_mod.addImport("za", za_mod);
    test_mod.addAnonymousImport("suite", .{
        .root_source_file = b.path(b.pathJoin(&.{ "tests/suites", suite, "main.zig" })),
        .target = target,
        .optimize = optimize,
        .omit_frame_pointer = options.omit_frame_pointer,
        .imports = &.{.{ .name = "za", .module = za_mod }},
    });
    test_mod.addAnonymousImport("input", .{
        .root_source_file = b.path(b.pathJoin(&.{ "tests/suites", suite, "cases.zon" })),
    });

    // Build the test module and executable
    const target_triple = target.result.zigTriple(b.allocator) catch @panic("OOM");
    const test_name = b.fmt("test-{s}-{s}-{s}", .{
        suite,
        target_triple,
        target.result.cpu.model.name,
    });
    const test_exe = b.addExecutable(.{
        .name = test_name,
        .root_module = test_mod,
    });
    const linker_run = b.addRunArtifact(linker_exe);
    test_exe.setLinkerScript(Linker.Args.add(.{
        .script = .{
            .code_section = .code,
            .data_section = .sram,
        },
        .output = b.fmt("{s}.ld", .{test_name}),
    }, linker_run));
    return test_exe;
}

/// Linker script namespace
pub const linker_script = struct {
    /// Generate a linker script
    pub fn gen(za: *Build.Dependency, args: Linker.Args) Build.LazyPath {
        const linker_exe = za.artifact("za-linker-util");
        const linker_run = za.builder.addRunArtifact(linker_exe);
        return args.add(linker_run);
    }

    /// Create the linker script generator
    /// Returns the linker executable
    fn init(
        b: *Build,
        target: Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    ) *Build.Step.Compile {
        // Create the module
        const linker_mod = b.createModule(.{
            .root_source_file = b.path("tools/Linker.zig"),
            .target = target,
            .optimize = optimize,
        });

        // Create the executable
        const linker_exe = b.addExecutable(.{
            .name = "za-linker-util",
            .root_module = linker_mod,
        });
        const linker_install = b.addInstallArtifact(linker_exe, .{
            .dest_dir = .disabled,
            .pdb_dir = .disabled,
            .h_dir = .disabled,
            .implib_dir = .disabled,
        });
        b.getInstallStep().dependOn(&linker_install.step);
        return linker_exe;
    }
};

/// Build setup function
pub fn build(b: *Build) !void {
    // Standard options
    const native_target = b.resolveTargetQuery(.{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options = Options.init(b);

    // Main hal module
    const za_mod = b.addModule("za", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .omit_frame_pointer = options.omit_frame_pointer,
    });

    // Linker script generator
    const linker_exe = linker_script.init(b, native_target, .ReleaseSafe);

    // Add tests step and get the test targets
    const tests_step = b.step("tests", "Run tests (check README.md)");

    // Build each test as seperate executable
    for (test_queries) |test_query| {
        const test_target = test_query.resolvedTarget(b);
        for (test_suites) |test_suite| {
            // Build the test
            const test_exe = buildSuite(
                b,
                test_suite,
                test_target,
                .Debug,
                options,
                za_mod,
                linker_exe,
            );

            // Add it to the test step
            tests_step.dependOn(&b.addInstallArtifact(test_exe, .{}).step);
        }
    }

    // Add cleanup step
    const clean_step = b.step("clean", "Remove build files");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache/")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out/")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("example/.zig-cache/")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("example/zig-out/")).step);

    // Add format step
    const fmt_step = b.step("fmt", "Check code formatting");
    fmt_step.dependOn(&b.addFmt(.{
        .check = true,
        .paths = &.{ "src/", "tests/", "tools/", "example/", "build.zig", "build.zig.zon" },
    }).step);

    // Add documentation step
    const docs_lib_step = b.addLibrary(.{
        .name = "za",
        .root_module = za_mod,
        .linkage = .static,
    });
    const docs_install_step = b.addInstallDirectory(.{
        .source_dir = docs_lib_step.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&docs_install_step.step);

    // Create readme generator
    const readme_mod = b.createModule(.{
        .root_source_file = b.path("tools/readme.zig"),
        .target = native_target,
        .optimize = .ReleaseSafe,
    });
    readme_mod.addImport("za", za_mod);
    const readme_exe = b.addExecutable(.{
        .name = "za-readme-gen",
        .root_module = readme_mod,
    });

    // Create step to build example code (to see if it works)
    const example_fetch_deps = b.addSystemCommand(&.{ "zig", "fetch", "--save" });
    example_fetch_deps.setCwd(b.path("example/"));
    example_fetch_deps.addArg("../");
    const example_cleanup = b.addRemoveDirTree(b.path("example/zig-out/"));
    for (test_queries) |test_query| {
        const example_check = b.addSystemCommand(&.{ "zig", "build" });
        example_check.addArg(b.fmt("-Dtarget={s}", .{test_query.target}));
        example_check.addArg(b.fmt("-Dcpu={s}", .{test_query.cpu}));
        example_check.setCwd(b.path("example/"));
        example_check.step.dependOn(&example_fetch_deps.step);
        example_cleanup.step.dependOn(&example_check.step);
    }
    const example_step = b.step("example", "Build the example");
    example_step.dependOn(&example_cleanup.step);

    // Create readme generator step
    const readme_run = b.addRunArtifact(readme_exe);
    readme_run.addFileArg(b.path("example/build.zig"));
    const readme_path = readme_run.addOutputFileArg("README.md");
    const readme_install = b.addInstallFile(readme_path, "README.md");
    const readme_step = b.step("readme", "Generate README.md in prefix path");
    readme_step.dependOn(&readme_install.step);

    // Throw error if target does not match one of the supported targets
    if (!target.result.cpu.hasAny(.arm, &.{ .has_v6, .has_v7 })) {
        const fail = b.addFail("Unsupported target! Use cpu model with armv6 or armv7!");
        b.getInstallStep().dependOn(&fail.step);
    }
}
