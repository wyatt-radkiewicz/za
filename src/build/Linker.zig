//! Configuration for generating a linker script
const std = @import("std");

/// Where are the text+rodata sections automatically put?
code_section: ?Region = null,

/// Where are the data+bss sections automatically put?
data_section: ?Region = null,

/// Linker script
const Linker = @This();

/// Assets for linker generator
const assets = struct {
    const code_sections = @embedFile("assets/code_sections.fmt.ld");
    const data_sections = @embedFile("assets/data_sections.fmt.ld");
};

/// Different memory regions in armv6/armv7
pub const Region = enum {
    code,
    sram,
    peripheral,
    ram_wbwa,
    ram_wt,
    device_shareable,
    device_non_shareable,
    system,

    /// Format this as a MEMORY entry
    pub fn format(this: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        try writer.print("{s} ({s}) : org = 0x{x:0>8}, len = 512M\n", .{
            this.name(),
            switch (this) {
                .code => "rx",
                .sram, .ram_wbwa, .ram_wt => "!r",
                .peripheral, .device_shareable, .device_non_shareable, .system => "!x",
            },
            @as(u32, @intFromEnum(this)) * 0x2000_0000,
        });
    }

    /// Get the name of the memory region
    pub fn name(this: @This()) []const u8 {
        return switch (this) {
            inline else => |tag| std.fmt.comptimePrint("za_{s}", .{@tagName(tag)}),
        };
    }
};

/// Write the full setup script (not including the main script)
pub fn format(this: Linker, writer: *std.io.Writer) std.io.Writer.Error!void {
    // Write a simple comment
    try writer.print(
        \\/*
        \\ * Automatically generated linker script for zig "za" arm hal
        \\ */
        \\
    , .{});

    // Write in the memory regions
    try writer.print("MEMORY {{\n", .{});
    for (std.meta.tags(Region)) |tag| {
        try writer.print("\t{f}", .{tag});
    }
    try writer.print("}}\n", .{});

    // Write in the code region (if needed)
    if (this.code_section) |region| {
        try writer.print(assets.code_sections, .{ .region = region.name() });
    }

    // Write in the data region (if needed)
    if (this.data_section) |region| {
        try writer.print(assets.data_sections, .{ .region = region.name() });
    }
}

/// Gets the description for a linker field
pub fn fieldDesc(field: std.meta.FieldEnum(Linker)) []const u8 {
    return switch (field) {
        .code_section => "Where are the text+rodata sections automatically put?",
        .data_section => "Where are the data+bss sections automatically put?",
    };
}

/// Command line arguments to be passed in or taken from command line
pub const Args = struct {
    /// What is the main script used for the linker?
    main_script: ?std.Build.LazyPath = null,

    /// Linker script config
    script: Linker,

    /// Name of the output
    output: []const u8,

    /// Generate command line arguments from the script
    /// Pass in the name of the generated linker script
    /// Returns the generated linker script path
    pub fn add(this: @This(), step: *std.Build.Step.Run) std.Build.LazyPath {
        if (this.main_script) |path| {
            step.addArg("--main_script");
            step.addFileArg(path);
        }
        if (this.script.code_section) |region| {
            step.addArg("--code_section");
            step.addArg(@tagName(region));
        }
        if (this.script.data_section) |region| {
            step.addArg("--data_section");
            step.addArg(@tagName(region));
        }
        return step.addOutputFileArg(this.output);
    }

    /// Gets the description for a args field
    pub fn fieldDesc(field: std.meta.FieldEnum(@This()), writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (field) {
            .main_script => try writer.print("What is the main script used for the linker?", .{}),
            .output => try writer.print("Name of the output", .{}),
            .script => {
                try writer.print("Linker script config\n", .{});
                const LinkerField = std.meta.FieldEnum(Linker);
                const fields = std.meta.fields(Linker);
                inline for (fields, 0..) |linker_field, field_idx| {
                    try writer.print("    {s}: {s}, // {s}{s}", .{
                        linker_field.name,
                        @typeName(linker_field.type),
                        Linker.fieldDesc(
                            std.meta.stringToEnum(LinkerField, linker_field.name).?,
                        ),
                        if (field_idx == fields.len - 1) "" else "\n",
                    });
                }
            },
        }
    }
};

/// Prints the usage message
fn usage(stdout: *std.io.Writer, args: []const []const u8) void {
    stdout.print(
        \\usage:
        \\\t{s} [options] <output>
        \\
        \\where:
        \\
        \\output: <path>
        \\
        \\options:
        \\\t--main_script <path>
        \\\t--code_section <region>
        \\\t--data_section <region>
        \\
        \\region:
    , .{args[0]}) catch return;
    for (std.meta.fieldNames(Region)) |name| {
        stdout.print("\t{s}\n", .{name}) catch return;
    }
    stdout.print("\n", .{}) catch return;
}

/// Command line utility to produce the linker script for the HAL
pub fn main() !void {
    // Initialize stdout writer
    var stdout_buffer: [1024 * 4]u8 = undefined;
    const stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    // Initialize arguments
    const gpa = std.heap.smp_allocator;
    const args = std.process.argsAlloc(gpa) catch @panic("OOM");
    defer std.process.argsFree(gpa, args);
    errdefer usage(stdout, args);

    // Parse command line arguments
    var main_script: ?[]u8 = null;
    var output_path: ?[]u8 = null;
    var linker: Linker = .{};
    var arg: usize = 1;
    while (arg < args.len) : (arg += 1) {
        if (std.mem.eql(u8, "--main_script", args[arg])) {
            if (arg + 1 == args.len) {
                return error.ExpectedArgument;
            } else if (main_script != null) {
                return error.RepeatedArgument;
            } else {
                arg += 1;
                main_script = args[arg];
            }
        } else if (std.mem.eql(u8, "--code_section", args[arg])) {
            if (arg + 1 == args.len) {
                return error.ExpectedArgument;
            } else if (linker.code_section != null) {
                return error.RepeatedArgument;
            } else {
                arg += 1;
                linker.code_section = std.meta.stringToEnum(Region, args[arg]) orelse
                    return error.InvalidRegion;
            }
        } else if (std.mem.eql(u8, "--data_section", args[arg])) {
            if (arg + 1 == args.len) {
                return error.ExpectedArgument;
            } else if (linker.data_section != null) {
                return error.RepeatedArgument;
            } else {
                arg += 1;
                linker.data_section = std.meta.stringToEnum(Region, args[arg]) orelse
                    return error.InvalidRegion;
            }
        } else {
            if (output_path != null) {
                return error.RepeatedArgument;
            } else {
                output_path = args[arg];
            }
        }
    }

    // Make sure we have all needed parameters
    if (output_path == null) {
        return error.ExpectedArgument;
    }

    // Open the output script
    var output_file = std.fs.cwd().createFile(output_path.?, .{}) catch {
        try stdout.print("ERROR: Couldn't create file \"{s}\"\n", .{output_path.?});
        return error.InvalidPath;
    };
    defer output_file.close();

    var output_buffer: [1024 * 4]u8 = undefined;
    var output_writer = output_file.writer(&output_buffer);
    const output = &output_writer.interface;
    defer output.flush() catch {};

    // Generate the output script
    try output.print("{f}", .{linker});
    if (main_script) |main_path| {
        var input_file = std.fs.cwd().openFile(main_path, .{ .mode = .read_only }) catch {
            try stdout.print("ERROR: Couldn't load main script \"{s}\"", .{main_path});
            return error.InvalidPath;
        };
        defer input_file.close();

        var input_buffer: [1024 * 4]u8 = undefined;
        var reader = input_file.readerStreaming(&input_buffer);
        _ = try reader.interface.stream(output, .unlimited);
    }
}
