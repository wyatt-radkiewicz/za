# ZA - Zig Embedded Arm HAL
## Table of Contents
- [Purpose](#purpose)
- [How to Use](#how-to-use)
  - [Adding to Your Project](#adding-to-your-project)
    - [Fetching the Dependency](#fetching-the-dependency)
    - [Importing the Module](#importing-the-module)
    - [Using the Linker Script Generator](#using-the-linker-script-generator)
    - [Generating README.md](#generating-readmemd)
- [Testing the HAL](#testing-the-hal)

## Purpose
- This library is meant to help write bare metal code for *ARM Cortex-M* cpus and
  possibly other ARM cpus in the future.

## How to Use
### Adding to Your Project
#### Fetching the Dependency
To add the HAL to your Zig project, run this in your project directory:
```bash
zig fetch --save git+<TODO URL>
```
#### Importing the Module
In your `build.zig` use `std.Build.dependency(b, name, args)` to access the hal dependency.
Here's an example:
```zig
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
    my_exe.setLinkerScript(za.linker_script.gen(b, .{
        .script = .{
            .code_segment = .code,
            .data_segment = .sram,
        },
        .output = "linker.ld",
    }).?);

    // Add install step
    const install_step = b.getInstallStep();
    const my_exe_artifact = b.addInstallArtifact(my_exe, .{});
    install_step.dependOn(&my_exe_artifact.step);
}

```
Here are the dependency options:
```zig
omit_frame_pointer: bool, // Omit frame pointer setup (default: false)
```
#### Using the Linker Script Generator
Here's the options for the linker script generator (as the type `za.Linker.Args`):
```zig
main_script: ?Build.LazyPath, // What is the main script used for the linker?
script: Linker, // Linker script config
    code_segment: ?Linker.Region, // Where are the text+rodata segments automatically put?
    data_segment: ?Linker.Region, // Where are the data+bss segments automatically put?
output: []const u8, // Name of the output
```

#### Generating README.md
To generate this README.md run this in the "za" working directory:
```bash
zig build readme -p .
```
* Note: `-p .` tells zig to put the output prefix
  directory in the current working directory for this invocation

### Testing the HAL
*TODO*
