//! Helper script to load in test cases and generate a variables file for robot framework
const std = @import("std");

const suite = @import("suite");
const cases = @import("cases");

/// Prints usage message
fn usage(writer: *std.io.Writer, args: []const []const u8) void {
    writer.print(
        \\usage:
        \\\t{s} <variables_file>
        \\\tvariables_file -- Path for output variables file
    , .{args[0]}) catch return;
}

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
    if (args.len < 2) {
        return error.NotEnoughArguments;
    }
    const output_path = args[1];

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

    // Generate the output variables file
    try output.print("*** Variables ***\n", .{});
    inline for (cases, 0..) |case, idx| {
        var name = std.ArrayList(u8).empty;
        defer name.deinit(gpa);
        for (case.name) |c| {
            switch (c) {
                'a'...'z', 'A'...'Z' => try name.append(gpa, std.ascii.toUpper(c)),
                '0'...'9' => try name.append(gpa, c),
                '_', ' ' => try name.append(gpa, ' '),
                else => {},
            }
        }
        try output.print("${{{s}}}  {}\n", .{ name.items, idx });
    }
}
