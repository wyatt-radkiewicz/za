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
- [Other Build Steps](#other-build-steps)
  - [Generating the Documentation](#generating-the-documentation)
  - [Generating README.md](#generating-readmemd)
  - [Cleaning Up](#cleaning-up)
  - [Checking Formatting](#checking-formatting)
  - [Testing the Example](#testing-the-example)

## Purpose
- This library is meant to help write bare metal code for *ARM Cortex-M* cpus and
  possibly other ARM cpus in the future.

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
{[example_build_zig]s}
```
Here are the dependency options:
```zig
{[dep_options]f}
```
#### Using the Linker Script Generator
Here's the options for the linker script generator
(as the type [za.Linker.Args](tools/Linker.zig#L124-L175) when including the [build.zig](build.zig) dependency):
```zig
{[linker_args]f}
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

## Testing the HAL
Test case executables are generated currently, but work still needs to be done to verify their
correctness with renode. For now *tests can be built with*:
```bash
zig build tests
```

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
