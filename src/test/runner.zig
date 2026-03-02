const za = @import("za");
const test_case = @import("test_case");

pub export const vectors linksection(".vectors") = za.Exception.vectortable(
    @ptrFromInt(0x2000_0000 + 0x4000),
    onreset,
    test_case.handlers,
);

pub export var __test_passed: u32 = 0;

fn onreset() callconv(.c) noreturn {
    var test_failed = false;
    test_case.main() catch {
        test_failed = true;
    };
    __test_passed = @intFromBool(!test_failed);

    // TODO: Use debug system to cause breakpoint
    while (true) {}
}
