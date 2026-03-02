# ZA - Zig Embedded Arm HAL
## Table of Contents
- [Purpose](#purpose)
- [How to Use](#how-to-use)
  - [Adding to Your Project](#adding-to-your-project)
    - [Fetching the Dependency](#fetching-the-dependency)
    - [Importing the Module](#importing-the-module)
    - [Using the Linker Script Generator](#using-the-linker-script-generator)
  - [Choosing a Target Triple](#choosing-a-target-triple)
- [Testing the HAL](#testing-the-hal)
- [Generating README.md](#generating-readmemd)

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

### Choosing a Target Triple
When using the HAL, a suitable target architecture must be chosen. The hal currently supports
ARMv6 and ARMv7 compatible CPUs. In the case of zig you can pick a target triple like this:
```
thumbeb-freestanding-eabi[hf]
```
Where `[hf]` is optional, to allow hardware floating point support if your target machine supports it.
Also sometimes specifying a specific cpu might be needed, to find their names for zig `-Dcpu` you can
run `zig build -Dcpu=` and it will autocomplete a list for you.

## Testing the HAL
Test case executables are generated currently, but work still needs to be done to verify their
correctness with renode. For now *tests can be built with*:
```bash
zig build test -Dtarget=<your target triple here> -Dcpu=<your cpu model here>
```

## Generating README.md
To generate this README.md run this in the "za" working directory:
```bash
zig build readme -p .
```
* Note: `-p .` tells zig to put the output prefix
  directory in the current working directory for this invocation
