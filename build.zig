const std = @import("std");

pub const Linker = @import("src/build/Linker.zig");
const Options = @import("src/build/Options.zig");
const Build = std.Build;

/// Linker script namespace
pub const linker_script = struct {
    var exe: ?*Build.Step.Compile = null;
    var exe_lock: std.Thread.Mutex = .{};

    /// Generate a linker script
    pub fn gen(b: *Build, args: Linker.Args) ?Build.LazyPath {
        exe_lock.lock();
        defer exe_lock.unlock();
        const linker_run = b.addRunArtifact(exe orelse return null);
        return args.add(linker_run);
    }

    /// Create the linker script generator
    fn init(b: *Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
        // If we already are initialized, return
        exe_lock.lock();
        defer exe_lock.unlock();
        if (exe != null) {
            return;
        }

        // Create the module
        const linker_mod = b.createModule(.{
            .root_source_file = b.path("src/build/Linker.zig"),
            .target = target,
            .optimize = optimize,
        });

        // Create the executable
        exe = b.addExecutable(.{
            .name = "za-linker-util",
            .root_module = linker_mod,
        });
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
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
        .optimize = optimize,
        .omit_frame_pointer = options.omit_frame_pointer,
    });

    // Linker script generator
    linker_script.init(b, native_target, .ReleaseSafe);

    // Add tests step
    const tests_step = b.step("test", "Run tests (check README.md)");

    // Build each test as seperate executable
    var tests_dir = try std.fs.cwd().openDir(b.pathFromRoot("src/test/cases/"), .{ .iterate = true });
    defer tests_dir.close();
    var tests_dir_iter = tests_dir.iterate();
    while (try tests_dir_iter.next()) |entry| {
        if (entry.kind != .file or !std.mem.eql(u8, ".zig", std.fs.path.extension(entry.name))) {
            continue;
        }

        // Create the test module
        const test_mod = b.createModule(.{
            .root_source_file = b.path("src/test/runner.zig"),
            .target = target,
            .optimize = optimize,
            .omit_frame_pointer = options.omit_frame_pointer,
        });
        test_mod.addImport("za", za_mod);
        test_mod.addAnonymousImport("test_case", .{
            .root_source_file = b.path(b.pathJoin(&.{ "src/test/cases/", entry.name })),
            .target = target,
            .optimize = optimize,
            .omit_frame_pointer = options.omit_frame_pointer,
            .imports = &.{.{ .name = "za", .module = za_mod }},
        });

        // Build the test module and executable
        const test_exe = b.addExecutable(.{
            .name = b.fmt("test-{s}", .{std.fs.path.stem(entry.name)}),
            .root_module = test_mod,
        });
        if (linker_script.gen(b, .{
            .script = .{
                .code_segment = .code,
                .data_segment = .sram,
            },
            .output = b.fmt("test-{s}.ld", .{std.fs.path.stem(entry.name)}),
        })) |path| {
            test_exe.setLinkerScript(path);
        } else {
            test_exe.step.dependOn(&b.addFail("Linker script not generated").step);
        }

        // Add it to the test step
        tests_step.dependOn(&b.addInstallArtifact(test_exe, .{}).step);
    }

    // Add cleanup step
    const clean_step = b.step("clean", "Remove build files");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache/")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out/")).step);

    // Add format step
    const fmt_step = b.step("fmt", "Check code formatting");
    fmt_step.dependOn(&b.addFmt(.{
        .check = true,
        .paths = &.{ "src/", "build.zig", "build.zig.zon" },
        .exclude_paths = &.{"src/linker/"},
    }).step);

    // Create readme generator
    const readme_mod = b.createModule(.{
        .root_source_file = b.path("src/build/readme.zig"),
        .target = native_target,
        .optimize = .ReleaseSafe,
    });
    readme_mod.addImport("za", za_mod);
    const readme_exe = b.addExecutable(.{
        .name = "za-readme-gen",
        .root_module = readme_mod,
    });

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
        tests_step.dependOn(&fail.step);
    }
}
