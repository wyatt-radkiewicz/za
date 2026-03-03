const za = @import("za");
const suite = @import("suite");
const cases: []const Case = @import("cases");

const MainReturn = @typeInfo(@TypeOf(suite.main)).@"fn".return_type.?;
const MainError = @typeInfo(MainReturn).error_union.error_set;
const Case = struct {
    name: []const u8,
    input: suite.Input,
};

pub export const vectors linksection(".vectors") = za.Exception.vectortable(
    @ptrFromInt(0x2000_0000 + 0x4000),
    onreset,
    suite.handlers,
);

pub export var test_case = @as(u32, 0);
pub export var test_pass = @as(u32, 0);

pub export fn test_complete() callconv(.c) noreturn {
    while (true) {}
}

fn onreset() callconv(.c) noreturn {
    suite.main(cases[test_case].input) catch test_complete();
    test_pass = 1;
    test_complete();
}
