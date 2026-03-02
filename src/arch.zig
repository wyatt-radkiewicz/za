//! Architecture version
const builtin = @import("builtin");

pub const Arch = enum {
    v6,
    v7,

    /// Current architecture
    pub const target: @This() = blk: {
        if (builtin.target.cpu.has(.arm, .has_v7)) {
            break :blk .v7;
        } else if (builtin.target.cpu.has(.arm, .has_v6)) {
            break :blk .v6;
        } else {
            @compileError("Use armzhal only on ARMv6 or ARMv7");
        }
    };
};
