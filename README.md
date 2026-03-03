# ZA - Zig Embedded Arm HAL
## Table of Contents
- [Purpose](#purpose)
- [How to Use](#how-to-use)
  - [Adding to Your Project](#adding-to-your-project)
    - [Fetching the Dependency](#fetching-the-dependency)
    - [Importing the Module](#importing-the-module)
    - [Using the Linker Script Generator](#using-the-linker-script-generator)
    - [Accessing the Docs](#accessing-the-docs)
  - [Choosing a Target Triple](#choosing-a-target-triple)
- [Testing the HAL](#testing-the-hal)
  - [Dependencies](#dependencies)
  - [Running Tests](#running-tests)
- [Other Build Steps](#other-build-steps)
  - [Generating the Documentation](#generating-the-documentation)
  - [Generating README.md](#generating-readmemd)
  - [Cleaning Up](#cleaning-up)
  - [Checking Formatting](#checking-formatting)
  - [Testing the Example](#testing-the-example)

---
## Purpose
- This library is meant to help write bare metal code for *ARM Cortex-M* cpus and
  possibly other ARM cpus in the future.

---
## How to Use
### Adding to Your Project
#### Fetching the Dependency
To add the HAL to your Zig project, run this in your project directory:
```bash
zig fetch --save git+https://github.com/wyatt-radkiewicz/za.git
```
#### Importing the Module
In your [build.zig](example/build.zig) use `std.Build.dependency(b, name, args)` to access the hal dependency.
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
    my_exe.setLinkerScript(za.linker_script.gen(za_dep, .{
        .script = .{
            .code_section = .code,
            .data_section = .sram,
        },
        .output = "linker.ld",
    }));

    // Add install step
    const install_step = b.getInstallStep();
    const my_exe_artifact = b.addInstallArtifact(my_exe, .{});
    install_step.dependOn(&my_exe_artifact.step);
}

```
Here are the dependency options:
```zig
omit_frame_pointer: bool, // Omit frame pointer setup (default: false)
test_case_timeout: f32, // How many seconds to let a test case run (default: 10.0)
```
#### Using the Linker Script Generator
Here's the options for the linker script generator
(as the type [za.Linker.Args](tools/Linker.zig#L124-L175) when including the [build.zig](build.zig) dependency):
```zig
main_script: ?Build.LazyPath, // What is the main script used for the linker?
script: Linker, // Linker script config
    code_section: ?Linker.Region, // Where are the text+rodata sections automatically put?
    data_section: ?Linker.Region, // Where are the data+bss sections automatically put?
output: []const u8, // Name of the output
```

#### Accessing the Docs
The docs can be found at [wyatt-radkiewicz.github.io/za](https://wyatt-radkiewicz.github.io/za/) or
locally at [docs/](docs/).

### Choosing a Target Triple
When using the HAL, a suitable target architecture must be chosen. The hal currently supports
ARMv6 and ARMv7 compatible CPUs. In the case of zig you can pick a target triple like this:
```
thumb[eb]-freestanding-eabi[hf]
```
Where:
 - `[hf]` is for hardware floating point support
 - `[eb]` is for big endian targets? *not quite sure...*
---
When using core processor registers in the HAL, you need to specify a cpu model to compile for
to zig. Cpu models for your architecture can be found by running:
```bash
zig build -Dtarget=<your target here> -Dcpu=
```
It will list supported cpu models that can then be use for `-Dcpu` when compiling.

---
## Testing the HAL
### Dependencies
To run the tests (building them doesn't require this step), you must first install
renode along with renode-test. Renode installation instructions can be found
at their [GitHub](https://github.com/renode/renode/blob/master/README.md#installation).

### Running Tests
Tests can be built and run with the following command:
```bash
zig build tests
```
Renode with the Robot Framework will automatically run after the tests are built
and output the test results to stdout.

---
## Other Build Steps
### Generating the Documentation
To generate the docs run this in the "za" working directory:
```bash
zig build docs -p .
```
* Note: `-p .` tells zig to put the output prefix
  directory in the current working directory for this invocation
### Generating README.md
To generate this README.md run this in the "za" working directory:
```bash
zig build readme -p .
```
* Note: `-p .` tells zig to put the output prefix
  directory in the current working directory for this invocation
### Cleaning Up
Run this command to delete `.zig-cache` and `zig-out` in project root and [examples](examples/) directory:
```bash
zig build clean
```
### Checking Formatting
This will only check the formatting of files in the project (not correct them):
```bash
zig build fmt
```
### Testing the Example
To build the example and make sure it works on the supported targets, run:
```bash
zig build example
```
