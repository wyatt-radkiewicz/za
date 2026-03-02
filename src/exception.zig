//! Exceptions and interrupts
const std = @import("std");

const internal = @import("internal.zig");
const Arch = @import("arch.zig").Arch;

pub const Exception = union(enum) {
    reset: void,
    nmi: void,
    hard_fault: void,
    mem_manage: void,
    bus_fault: void,
    usage_fault: void,
    sv_call: void,
    debug_monitor: void,
    pend_sv: void,
    sys_tick: void,
    external_interrupt: Vector,

    /// Vector number
    pub const Vector = u9;

    /// Creates a new exception from a number
    pub fn fromvec(n: Vector) ?@This() {
        return switch (n) {
            1 => .reset,
            2 => .nmi,
            3 => .hard_fault,
            4 => .mem_manage,
            5 => .bus_fault,
            6 => .usage_fault,
            11 => .sv_call,
            12 => .debug_monitor,
            14 => .pend_sv,
            15 => .sys_tick,
            16...496 + 16 - 1 => |i| .{ .external_interrupt = i - 16 },
            else => null,
        };
    }

    /// Gets exception number
    pub fn tovec(this: @This()) Vector {
        return switch (this) {
            .reset => 1,
            .nmi => 2,
            .hard_fault => 3,
            .mem_manage => 4,
            .bus_fault => 5,
            .usage_fault => 6,
            .sv_call => 11,
            .debug_monitor => 12,
            .pend_sv => 14,
            .sys_tick => 15,
            .external_interrupt => |i| i + 16,
        };
    }

    /// Sets the specified exception as pending in software or clears it
    pub fn setpend(this: @This(), pend: bool) error{Forbidden}!void {
        switch (this) {
            .reset => internal.scs.aircr.sysresetreq = pend,
            .nmi => internal.scs.icsr.nmipendset = pend,
            .pend_sv => switch (pend) {
                true => internal.scs.icsr.pendsvset = true,
                false => internal.scs.icsr.pendsvclr = true,
            },
            .sys_tick => switch (pend) {
                true => internal.scs.icsr.pendstset = true,
                false => internal.scs.icsr.pendstclr = true,
            },
            .mem_manage, .bus_fault, .usage_fault => switch (Arch.target) {
                .v6 => return error.Forbidden,
                .v7 => switch (pend) {
                    inline else => |val| _ = @atomicRmw(
                        u32,
                        @as(*volatile u32, @ptrCast(internal.scs.shcsr)),
                        if (val) .Or else .And,
                        blk: {
                            const mask: u32 = @bitCast(switch (this) {
                                .mem_manage => internal.scs.Shcsr{ .memfaultpended = true },
                                .bus_fault => internal.scs.Shcsr{ .busfaultpended = true },
                                .usage_fault => internal.scs.Shcsr{ .usgfaultpended = true },
                                else => unreachable,
                            });
                            break :blk if (val) mask else ~mask;
                        },
                        .release,
                    ),
                },
            },
            .sv_call => if (pend) internal.core.svc(0) else {},
            .external_interrupt => |i| {
                const word = i / 32;
                const mask = @as(u32, 1) << @as(u5, @truncate(i));
                if (pend) {
                    internal.nvic.ispr[word] |= mask;
                } else {
                    internal.nvic.icpr[word] |= mask;
                }
            },
            else => return error.Forbidden,
        }
    }

    /// Checks to see if the exception is pending
    pub fn getpend(this: @This()) error{Forbidden}!bool {
        return switch (this) {
            .nmi => internal.scs.icsr.nmipendset,
            .pend_sv => internal.scs.icsr.pendsvset,
            .sys_tick => internal.scs.icsr.pendstset,
            .mem_manage => if (Arch.target == .v6) error.Forbidden else internal.scs.shcsr.memfaultpended,
            .bus_fault => if (Arch.target == .v6) error.Forbidden else internal.scs.shcsr.busfaultpended,
            .usage_fault => if (Arch.target == .v6) error.Forbidden else internal.scs.shcsr.usgfaultpended,
            .sv_call => if (Arch.target == .v6) error.Forbidden else internal.scs.shcsr.svcallpended,
            .external_interrupt => |i| internal.nvic.ispr[i / 32] & @as(u32, 1) << @as(u5, @truncate(i)) != 0,
            else => return error.Forbidden,
        };
    }

    /// Enables or disables the exception (allowing it to be raised or not)
    pub fn seten(this: @This(), en: bool) error{Forbidden}!void {
        switch (this) {
            .mem_manage, .bus_fault, .usage_fault => switch (Arch.target) {
                .v6 => return error.Forbidden,
                .v7 => switch (en) {
                    inline else => |val| _ = @atomicRmw(
                        u32,
                        @as(*volatile u32, @ptrCast(internal.scs.shcsr)),
                        if (val) .Or else .And,
                        blk: {
                            const mask: u32 = @bitCast(switch (this) {
                                .mem_manage => internal.scs.Shcsr{ .memfaultena = true },
                                .bus_fault => internal.scs.Shcsr{ .busfaultena = true },
                                .usage_fault => internal.scs.Shcsr{ .usgfaultena = true },
                                else => unreachable,
                            });
                            break :blk if (val) mask else ~mask;
                        },
                        .release,
                    ),
                },
            },
            .sys_tick => internal.systick.csr.tickint = en,
            .external_interrupt => |i| {
                const word = i / 32;
                const mask = @as(u32, 1) << @as(u5, @truncate(i));
                if (en) {
                    internal.nvic.iser[word] |= mask;
                } else {
                    internal.nvic.icer[word] |= mask;
                }
            },
            else => return error.Forbidden,
        }
    }

    /// Checks if the exception is enabled
    pub fn geten(this: @This()) error{Forbidden}!bool {
        switch (this) {
            .sys_tick => internal.systick.csr.tickint,
            .mem_manage => if (Arch.target == .v6) error.Forbidden else internal.scs.shcsr.memfaultena,
            .bus_fault => if (Arch.target == .v6) error.Forbidden else internal.scs.shcsr.busfaultena,
            .usage_fault => if (Arch.target == .v6) error.Forbidden else internal.scs.shcsr.usgfaultena,
            .external_interrupt => |i| internal.nvic.iser[i / 32] & 1 << i % 32 != 0,
            else => return error.Forbidden,
        }
    }

    /// Gets the currently active exception
    pub fn active() ?@This() {
        return .init(@truncate(internal.core.Register.ipsr.get()));
    }

    /// Priority group and subpriority
    pub fn Priority(group_bits: comptime_int) type {
        if (Arch.target == .v6 and group_bits != 2) {
            @compileError("ARMv6 only supports 2 bit priority groups");
        }
        return packed struct {
            sub: switch (Arch.target) {
                .v6 => void,
                .v7 => std.meta.Int(.unsigned, 8 - group_bits),
            } = switch (Arch.target) {
                .v6 => {},
                .v7 => 0,
            },
            grp: std.meta.Int(.unsigned, group_bits),

            /// Errors while getting or setting exception priority levels
            const Error = error{ FixedLevel, Reserved };

            /// Configures system to use specified priority group setting
            pub fn cfg() void {
                if (Arch.target == .v6) {
                    return;
                }
                internal.scs.aircr.prigroup = group_bits;
            }

            /// Apply exception priority
            pub fn set(
                this: @This(),
                exception: Exception,
            ) Error!void {
                switch (Arch.target) {
                    .v6 => switch (exception) {
                        .reset, .nmi, .hard_fault => return Error.FixedLevel,
                        .mem_manage, .bus_fault, .usage_fault, .debug_monitor => return Error.Reserved,
                        .external_interrupt => |n| {
                            const ipr = internal.nvic.ipr[n];
                            internal.nvic.ipr[n] = ipr & 0x3f | @as(u8, this.grp) << 6;
                        },
                        else => |e| {
                            const n = e.number();
                            const ipr = internal.scs.shpr[n];
                            internal.scs.shpr[n] = ipr & 0x3f | @as(u8, this.grp) << 6;
                        },
                    },
                    .v7 => switch (exception) {
                        .reset, .nmi, .hard_fault => return Error.FixedLevel,
                        .external_interrupt => |n| internal.nvic.ipr[n] = @bitCast(this),
                        else => |e| internal.scs.shpr[e.number()] = @bitCast(this),
                    },
                }
            }

            /// Get exception level
            pub fn get(exception: Exception) Error!@This() {
                return switch (Arch.target) {
                    .v6 => switch (exception) {
                        .reset, .nmi, .hard_fault => Error.FixedLevel,
                        .mem_manage, .bus_fault, .usage_fault, .debug_monitor => Error.Reserved,
                        .external_interrupt => |n| .{
                            .sub = {},
                            .grp = @truncate(internal.nvic.ipr[n] >> 6),
                        },
                        else => |e| .{
                            .sub = {},
                            .grp = @truncate(internal.scs.shpr[e.number()] >> 6),
                        },
                    },
                    .v7 => switch (exception) {
                        .reset, .nmi, .hard_fault => Error.FixedLevel,
                        .external_interrupt => |n| @bitCast(internal.nvic.ipr[n]),
                        else => |e| @bitCast(internal.scs.shpr[e.number()]),
                    },
                };
            }
        };
    }

    /// Builds a vector table with a callback
    pub fn vectortable(
        comptime sp_main: *allowzero align(@alignOf(*const Handler)) const anyopaque, // Pointer to main stack location
        comptime reset: Reset, // Reset handler
        comptime handlers: fn (@This()) ?Handler, // If handler is implemented, returns it
    ) [max_vector_count]*allowzero const Handler {
        @setEvalBranchQuota(1000 + max_vector_count * 100);
        const unimplemented_pass = struct {
            pub fn inner() callconv(.{ .arm_interrupt = .{} }) void {
                return;
            }
        }.inner;
        const unimplemented_loop = struct {
            pub fn inner() callconv(.{ .arm_interrupt = .{} }) void {
                while (true) {}
            }
        }.inner;
        @export(&reset, .{ .name = "_start", .linkage = .strong });

        var table: [max_vector_count]*allowzero const Handler =
            [1]*allowzero const Handler{@ptrCast(sp_main)} ++
            [1]*allowzero const Handler{@ptrCast(&reset)} ++
            [1]*allowzero const Handler{undefined} ** (max_vector_count - 2);
        for (2..table.len, table[2..]) |i, *t| {
            const e = @This().fromvec(@intCast(i)) orelse {
                t.* = @ptrFromInt(0x0000_0000);
                continue;
            };

            if (handlers(e)) |h| {
                t.* = &h;
            } else {
                t.* = switch (e) {
                    .sv_call, .debug_monitor, .pend_sv, .sys_tick => unimplemented_pass,
                    else => unimplemented_loop,
                };
            }
        }
        return table;
    }

    /// Maximum number of vectors
    pub const max_vector_count = switch (Arch.target) {
        .v6 => 16 + 32,
        .v7 => 16 + 496,
    };

    /// Function prototype for exception handlers
    pub const Handler = fn () callconv(.{ .arm_interrupt = .{} }) void;

    /// Reset function prototype
    pub const Reset = fn () callconv(.c) noreturn;
};
