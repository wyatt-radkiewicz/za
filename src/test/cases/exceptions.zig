const za = @import("za");

pub fn handlers(e: za.Exception) ?za.Exception.Handler {
    return switch (e) {
        .external_interrupt => |n| switch (n) {
            0 => struct {
                fn isr() callconv(.{ .arm_interrupt = .{} }) void {
                    test_flag = true;
                }
            }.isr,
            else => null,
        },
        else => null,
    };
}

var test_flag: bool = false;

pub fn main() !void {
    const irq0 = za.Exception{ .external_interrupt = 0 };
    try irq0.seten(false);
    try irq0.setpend(true);
    if (test_flag) {
        return error.TestFailed;
    }
    try irq0.setpend(false);
}
