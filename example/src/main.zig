const std = @import("std");
const za = @import("za");

pub export const vectors linksection(".vectors") = za.Exception.vectortable(
    @ptrFromInt(0x2000_0000 + 0x4000),
    main,
    handlers,
);

fn handlers(_: za.Exception) ?za.Exception.Handler {
    return null;
}

fn main() callconv(.c) noreturn {
    while (true) {}
}
