//! Small program to generate README.md
//! Program takes in a single argument - where to write the README.md file
const std = @import("std");

const Options = @import("Options.zig");
const Linker = @import("Linker.zig");

/// Assets file
const assets = struct {
    const readme_fmt = @embedFile("README.fmt.md");
};

/// Prints usage message
fn usage(writer: *std.io.Writer, args: []const []const u8) void {
    writer.print(
        \\usage:
        \\\t{s} <example_build_zig> <readme>
        \\\texample_build_zig -- example zig project directory "build.zig"
        \\\treadme -- Path for ouput README.md
    , .{args[0]}) catch return;
}

/// Build README.md
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

    // Get arguments
    if (args.len < 3) {
        return error.NotEnoughArguments;
    }
    const build_zig_path = args[1];
    const output_path = args[2];

    // Load in the example "build.zig"
    const build_zig_file = std.fs.cwd().openFile(build_zig_path, .{ .mode = .read_only }) catch {
        try stdout.print("ERROR: Couldn't open file \"{s}\"\n", .{build_zig_path});
        return error.InvalidPath;
    };
    defer build_zig_file.close();
    const build_zig_data = try build_zig_file.readToEndAlloc(gpa, 1024 * 16);
    defer gpa.free(build_zig_data);

    // Open the output script
    var output_file = std.fs.cwd().createFile(output_path, .{}) catch {
        try stdout.print("ERROR: Couldn't create file \"{s}\"\n", .{output_path});
        return error.InvalidPath;
    };
    defer output_file.close();

    var output_buffer: [1024 * 4]u8 = undefined;
    var output_writer = output_file.writer(&output_buffer);
    const output = &output_writer.interface;
    defer output.flush() catch {};

    // Generate the output script
    try output.print(assets.readme_fmt, .{
        .example_build_zig = build_zig_data,
        .dep_options = ListFields(Options){},
        .linker_args = ListFields(Linker.Args){},
    });
}

/// Prints out a list of fields
fn ListFields(comptime T: type) type {
    return struct {
        pub fn format(_: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
            const fields = std.meta.fields(T);
            inline for (fields, 0..) |field, field_idx| {
                try writer.print("{s}: {s}, // ", .{ field.name, @typeName(field.type) });
                const field_entry = std.meta.stringToEnum(std.meta.FieldEnum(T), field.name).?;
                if (@typeInfo(@TypeOf(T.fieldDesc)).@"fn".params.len == 2) {
                    try T.fieldDesc(field_entry, writer);
                } else {
                    try writer.print("{s}", .{T.fieldDesc(field_entry)});
                }
                try writer.print("{s}", .{if (field_idx + 1 == fields.len) "" else "\n"});
            }
        }
    };
}
