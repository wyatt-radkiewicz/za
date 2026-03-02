//! This test makes sure that setting registers work
const za = @import("za");

pub const Input = za.Register;

pub fn handlers(e: za.Exception) ?za.Exception.Handler {
    return switch (e) {
        else => null,
    };
}

pub fn main(input: Input) !void {
    try za.Register.set(input);
}
