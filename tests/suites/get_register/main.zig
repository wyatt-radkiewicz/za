//! This test makes sure that getting registers work
const za = @import("za");

pub const Input = struct {
    tag: za.Register.Tag,
    expected: za.Register,
};

pub fn handlers(e: za.Exception) ?za.Exception.Handler {
    return switch (e) {
        else => null,
    };
}

pub fn main(input: Input) !void {
    const reg = try za.Register.get(input.tag);
    if (!switch (input.expected) {
        .primask => |val| reg.primask == val,
        else => false,
    }) {
        return error.ValuesUnequal;
    }
}
