//! General purpose processor configurations
const std = @import("std");

const internal = @import("internal.zig");
const Arch = @import("arch.zig").Arch;

/// Method of getting processor configuration
pub const Register = union(enum) {
    sevonpend: bool, // Should an isr going from inactive -> pending raise an event?
    sleepdeep: bool, // Is deep sleep is enabled?
    sleeponexit: bool, // Should the cpu sleep returning from an isr?
    fpuaccess: Access, // Who can access the fpu?
    status: Status, // Processor application flags
    primask: bool, // Used to raise execution priority to level 0
    basepri: u8, // Used in ARMv7 to set priority level required for exception preemption
    faultmask: bool, // Used in ARMv7 to raise execution priority to -1, only some handlers can do this
    thread_privilege: ThreadPrivilege, // Is the thread privileged?
    stack_pointer: StackSelect, // What stack pointer are we using?
    fpu_active: bool, // Is the fpu active?
    systick_config: SysTick, // SysTick configuration
    systick_current: SysTick.Counter, // Current SysTick timer
    systick_reset: void, // Write to this to reset systick timer
    systick_counted: bool, // Has the systick value underflowed since the last time this was read

    /// Tag of register
    pub const Tag = @typeInfo(@This()).@"union".tag_type orelse
        @compileError("Register must be tagged union");

    /// Checks config
    pub fn get(tag: Tag) error{ WriteOnly, Unsupported }!@This() {
        return switch (tag) {
            .sevonpend => .{ .sevonpend = internal.scs.scr.sevonpend },
            .sleepdeep => .{ .sleepdeep = internal.scs.scr.sleepdeep },
            .sleeponexit => .{ .sleeponexit = internal.scs.scr.sleeponexit },
            .fpuaccess => .{ .fpuaccess = internal.scs.cpacr.cp10 },
            inline .status,
            .basepri,
            .primask,
            .faultmask,
            => @unionInit(@This(), @tagName(tag), blk: {
                switch (tag) {
                    .basepri, .faultmask => if (Arch.target == .v6) return error.Unsupported,
                    else => {},
                }
                const code = std.fmt.comptimePrint("mrs %[ret], {s}", .{switch (tag) {
                    .status => "apsr",
                    .basepri => "basepri",
                    .primask => "primask",
                    .faultmask => "faultmask",
                    else => unreachable,
                }});
                const reg: u32 = asm volatile (code
                    : [ret] "=r" (-> u32),
                );
                break :blk switch (tag) {
                    .status => @bitCast(@as(
                        @typeInfo(Status).@"struct".backing_integer.?,
                        @truncate(reg >> 32 - @bitSizeOf(Status)),
                    )),
                    .basepri => @truncate(reg),
                    .primask, .faultmask => reg & 1 == 1,
                };
            }),
            inline .thread_privilege,
            .stack_pointer,
            .fpu_active,
            => @unionInit(@This(), @tagName(tag), blk: {
                const control: u3 = @truncate(asm volatile ("mrs %[ret], control"
                    : [ret] "=r" (-> u32),
                ));
                break :blk switch (tag) {
                    .thread_privilege => @enumFromInt(@as(u1, @truncate(control))),
                    .stack_pointer => @enumFromInt(@as(u1, @truncate(control >> 1))),
                    .fpu_active => if (Arch.target == .v6)
                        return error.Unsupported
                    else
                        control & 1 << 2 != 0,
                };
            }),
            .systick_config => .{ .systick_config = .{
                .enabled = internal.systick.csr.enable,
                .source = @enumFromInt(@intFromEnum(internal.systick.csr.clksource)),
                .reload = internal.systick.rvr,
            } },
            .systick_current => .{ .systick_current = @truncate(internal.systick.cvr) },
            .systick_reset => return error.WriteOnly,
            .systick_counted => .{ .systick_counted = internal.systick.csr.countflag },
        };
    }

    /// Applies config
    pub fn set(this: @This()) error{ ReadOnly, Unsupported }!void {
        switch (this) {
            .sevonpend => |val| internal.scs.scr.sevonpend = val,
            .sleepdeep => |val| internal.scs.scr.sleepdeep = val,
            .sleeponexit => |val| internal.scs.scr.sleeponexit = val,
            .fpuaccess => |val| {
                internal.scs.cpacr.cp10 = val;
                internal.scs.cpacr.cp11 = val;
            },
            inline .status, .basepri => {
                switch (this) {
                    .basepri => if (Arch.target == .v6) return error.Unsupported,
                    else => {},
                }
                const val: u32 = switch (this) {
                    .basepri => |x| x,
                    .status => |x| @as(u32, @as(
                        @typeInfo(Status).@"struct".backing_integer.?,
                        @bitCast(x),
                    )) << 32 - @bitSizeOf(Status),
                };
                const code = std.fmt.comptimePrint("msr {s}, %[val]", .{switch (this) {
                    .status => "apsr",
                    .basepri => "basepri",
                    else => unreachable,
                }});
                asm volatile (code
                    :
                    : [val] "=r" (val),
                );
            },
            .primask, .faultmask => |val| asm volatile (std.fmt.comptimePrint("cps{s} {s}", .{
                    switch (val) {
                        true => "ie",
                        false => "id",
                    },
                    switch (this) {
                        .primask => "i",
                        .faultmask => if (Arch.target == .v6) return error.Unsupported else "f",
                        else => unreachable,
                    },
                })),
            .fpu_active => return error.ReadOnly,
            inline .thread_privilege, .stack_pointer => {
                var control: u3 = @truncate(asm volatile ("mrs %[ret], control"
                    : [ret] "=r" (-> u32),
                ));
                switch (this) {
                    .thread_privilege => |val| {
                        control &= 1 << 0;
                        control |= @intFromEnum(val) << 0;
                    },
                    .stack_pointer => |val| {
                        control &= 1 << 1;
                        control |= @intFromEnum(val) << 1;
                    },
                }
                asm volatile (
                    \\msr control, %[control]
                    \\isb
                    :
                    : [control] "=r" (control),
                );
            },
            .systick_config => |val| {
                internal.systick.rvr = val.reload;
                internal.systick.csr.clksource = @enumFromInt(@intFromEnum(val.source));
                internal.systick.csr.enable = val.enabled;
            },
            .systick_current => return error.ReadOnly,
            .systick_reset => internal.systick.cvr = 0,
            .systick_counted => return error.ReadOnly,
        }
    }

    /// Coprocessor access
    pub const Access = enum(u2) {
        denied,
        privileged,
        reserved,
        full,
    };

    /// Application status flags
    pub const Status = packed struct {
        q: switch (Arch.target) {
            .v6 => void,
            .v7 => bool,
        }, // Saturate flag
        v: bool, // Overflow flag
        c: bool, // Carry flag
        z: bool, // Zero flag
        n: bool, // Negative flag
    };

    /// Thread mode privilege level
    pub const ThreadPrivilege = enum(u1) {
        privileged,
        unprivileged,
    };

    /// What stack pointer to use
    pub const StackSelect = enum(u1) {
        main,
        process,
    };

    /// SysTick configuration
    pub const SysTick = struct {
        enabled: bool,
        reload: Counter,
        source: Source,

        /// Counter values are 24 bits
        pub const Counter = u24;

        /// How is the clock sourced?
        pub const Source = enum(u1) {
            internal, // Same as cpu clock
            external, // External reference clock
        };
    };
};
