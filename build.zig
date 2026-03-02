const std = @import("std");

pub const Linker = @import("tools/Linker.zig");
const Options = @import("tools/Options.zig");
const Build = std.Build;
const test_cases: []const TestCase = @import("tests/cases.zon");

/// Data pertaining to a test case
const TestCase = struct {
    path: []const u8,

    /// Build the test case
    fn build(
        this: @This(),
        b: *Build,
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
        test_mod.addAnonymousImport("test_case", .{
            .root_source_file = b.path(b.pathJoin(&.{ "tests/cases/", this.path })),
            .target = target,
            .optimize = optimize,
            .omit_frame_pointer = options.omit_frame_pointer,
            .imports = &.{.{ .name = "za", .module = za_mod }},
        });

        // Build the test module and executable
        const test_exe = b.addExecutable(.{
            .name = b.fmt("test-{s}", .{std.fs.path.stem(this.path)}),
            .root_module = test_mod,
        });
        const linker_run = b.addRunArtifact(linker_exe);
        test_exe.setLinkerScript(Linker.Args.add(.{
            .script = .{
                .code_section = .code,
                .data_section = .sram,
            },
            .output = b.fmt("test-{s}.ld", .{std.fs.path.stem(this.path)}),
        }, linker_run));
        return test_exe;
    }
};

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

    // Add tests step
    const tests_step = b.step("test", "Run tests (check README.md)");

    // Build each test as seperate executable
    for (test_cases) |test_case| {
        // Build the test
        const test_exe = test_case.build(b, target, optimize, options, za_mod, linker_exe);

        // Add it to the test step
        tests_step.dependOn(&b.addInstallArtifact(test_exe, .{}).step);
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
    example_fetch_deps.addDirectoryArg(b.path(""));
    const example_check = b.addSystemCommand(&.{ "zig", "build", "-Dtarget=thumbeb-freestanding-eabi" });
    example_check.step.dependOn(&example_fetch_deps.step);
    example_check.setCwd(b.path("example/"));
    const example_cleanup = b.addRemoveDirTree(b.path("example/zig-out/"));
    example_cleanup.step.dependOn(&example_check.step);

    // Add example check to test step
    tests_step.dependOn(&example_cleanup.step);

    // Create readme generator step
    const readme_run = b.addRunArtifact(readme_exe);
    readme_run.step.dependOn(&example_cleanup.step);
    readme_run.addFileArg(b.path("example/build.zig"));
    const readme_path = readme_run.addOutputFileArg("README.md");
    const readme_install = b.addInstallFile(readme_path, "README.md");
    const readme_step = b.step("readme", "Generate README.md in prefix path");
    readme_step.dependOn(&readme_install.step);

    // Throw error if target does not match one of the supported targets
    if (!target.result.cpu.hasAny(.arm, &.{ .has_v6, .has_v7 })) {
        const fail = b.addFail("Unsupported target! Use cpu model with armv6 or armv7!");
        tests_step.dependOn(&fail.step);
    }
}
