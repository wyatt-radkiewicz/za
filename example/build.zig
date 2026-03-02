//!
//! "za" example build script
//!
const std = @import("std");
//
// *Import "za" build.zig*
//
const za = @import("za");

pub fn build(b: *std.Build) void {
    // Build options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //
    // *Get the "za" dependency*
    //
    const za_dep = b.dependencyFromBuildZig(za, .{
        // Standard options
        .target = target,
        .optimize = optimize,

        //
        // *"za" specific options*
        //
        .omit_frame_pointer = false,
    });

    // Your code/module
    const my_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    //
    // *Add the HAL module to imports*
    //
    my_mod.addImport("za", za_dep.module("za"));

    // Build your exe
    const my_exe = b.addExecutable(.{
        .name = "my_exe",
        .root_module = my_mod,
    });

    //
    // Use the embedded linker script generator
    //
    my_exe.setLinkerScript(za.linker_script.gen(za_dep, .{
        .script = .{
            .code_segment = .code,
            .data_segment = .sram,
        },
        .output = "linker.ld",
    }));

    // Add install step
    const install_step = b.getInstallStep();
    const my_exe_artifact = b.addInstallArtifact(my_exe, .{});
    install_step.dependOn(&my_exe_artifact.step);
}
