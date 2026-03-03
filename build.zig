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

/// Build and run the test case
fn buildAndRunSuite(
    b: *Build,
    suite: []const u8,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: Options,
    za_mod: *Build.Module,
    linker_exe: *Build.Step.Compile,
    platform: []const u8,
) *Build.Step.Run {
    // Create the test module
    const test_mod = b.createModule(.{
        .root_source_file = b.path("tests/runner.zig"),
        .target = target,
        .optimize = optimize,
        .omit_frame_pointer = options.omit_frame_pointer,
    });
    const suite_mod = b.createModule(.{
        .root_source_file = b.path(b.pathJoin(&.{ "tests/suites", suite, "main.zig" })),
        .target = target,
        .optimize = optimize,
        .omit_frame_pointer = options.omit_frame_pointer,
    });
    const cases_mod = b.createModule(.{
        .root_source_file = b.path(b.pathJoin(&.{ "tests/suites", suite, "cases.zon" })),
    });
    suite_mod.addImport("za", za_mod);
    test_mod.addImport("za", za_mod);
    test_mod.addImport("suite", suite_mod);
    test_mod.addImport("cases", cases_mod);

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

    // Build the variables file
    const native_target = b.resolveTargetQuery(.{});
    const variables_mod = b.createModule(.{
        .root_source_file = b.path("tools/variables.zig"),
        .target = native_target,
        .optimize = .ReleaseSafe,
    });
    variables_mod.addImport("suite", suite_mod);
    variables_mod.addImport("cases", cases_mod);
    const variables_exe = b.addExecutable(.{
        .name = "za-variables-gen",
        .root_module = variables_mod,
    });
    const variables_run = b.addRunArtifact(variables_exe);
    const variables_file = variables_run.addOutputFileArg("test_cases.resource");

    // Run the test runner
    const test_run = b.addSystemCommand(&.{"python3"});
    test_run.addFileArg(b.path("tools/run_tests.py"));
    test_run.addArgs(&.{
        "--platform",
        platform,
        "--suite",
        suite,
        "--timeout",
        b.fmt("{}", .{options.test_case_timeout}),
    });
    test_run.addArg("--variables");
    test_run.addFileArg(variables_file);
    test_run.addArg("--bin");
    test_run.addFileArg(test_exe.getEmittedBin());
    test_run.addArg("--output");
    _ = test_run.addOutputDirectoryArg("test_results");
    test_run.addArg("--tests_dir");
    test_run.addDirectoryArg(b.path("tests/"));
    test_run.has_side_effects = true;
    return test_run;
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
    var tests_depend_step = tests_step;
    for (test_queries) |test_query| {
        const test_target = test_query.resolvedTarget(b);
        for (test_suites) |test_suite| {
            // Build the test and run it
            const test_run = buildAndRunSuite(
                b,
                test_suite,
                test_target,
                .Debug,
                options,
                za_mod,
                linker_exe,
                test_query.platform,
            );
            tests_depend_step.dependOn(&test_run.step);
            tests_depend_step = &test_run.step;
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
    const example_step = b.step("example", "Build the example");

    var example_check_depend: *Build.Step = example_step;
    for (test_queries) |test_query| {
        const example_check = b.addSystemCommand(&.{ "zig", "build" });
        example_check.addArg(b.fmt("-Dtarget={s}", .{test_query.target}));
        example_check.addArg(b.fmt("-Dcpu={s}", .{test_query.cpu}));
        example_check.setCwd(b.path("example/"));
        example_check.step.dependOn(&example_fetch_deps.step);
        example_check_depend.dependOn(&example_check.step);
        example_check_depend = &example_check.step;
    }

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
