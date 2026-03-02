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
{[example_build_zig]s}
```
Here are the dependency options:
```zig
{[dep_options]f}
```
#### Using the Linker Script Generator
Here's the options for the linker script generator (as the type `za.Linker.Args`):
```zig
{[linker_args]f}
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
