const za = @import("za");
const suite = @import("suite");
const input_data: []const Input = @import("input");

const MainReturn = @typeInfo(@TypeOf(suite.main)).@"fn".return_type.?;
const MainError = @typeInfo(MainReturn).error_union.error_set;
const Input = struct {
    name: []const u8,
    input: suite.Input,
};

pub export const vectors linksection(".vectors") = za.Exception.vectortable(
    @ptrFromInt(0x2000_0000 + 0x4000),
    onreset,
    suite.handlers,
);

pub export var test_input = @as(u32, 0);
pub export var test_input_name = [1]u8{0} ** 256;
pub export var test_error_name = [1]u8{0} ** 256;

pub export fn test_threw_error() callconv(.c) noreturn {
    while (true) {}
}

pub export fn test_complete() callconv(.c) noreturn {
    while (true) {}
}

fn memcpyClamp(dest: []u8, src: []const u8) void {
    const len = @min(dest.len, src.len);
    @memcpy(dest[0..len], src[0..len]);
}

fn onreset() callconv(.c) noreturn {
    var thrown_error: ?MainError = null;
    memcpyClamp(&test_input_name, input_data[test_input].name);
    if (suite.Input == void) {
        suite.main({}) catch |err| {
            thrown_error = err;
        };
    } else {
        suite.main(input_data[test_input].input) catch |err| {
            thrown_error = err;
        };
    }
    if (thrown_error) |err| {
        switch (err) {
            inline else => |val| memcpyClamp(&test_error_name, @errorName(val)),
        }
        test_threw_error();
    } else {
        test_complete();
    }
}
