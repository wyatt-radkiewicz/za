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
            .status => .{ .status = @bitCast(@as(
                @typeInfo(Status).@"struct".backing_integer.?,
                @truncate(internal.core.Register.apsr.get() >> 32 - @bitSizeOf(Status)),
            )) },
            .basepri => .{ .basepri = if (Arch.target == .v6)
                return error.Unsupported
            else
                @truncate(internal.core.Register.basepri.get()) },
            .primask => .{ .primask = internal.core.Register.primask.get() & 1 == 1 },
            .faultmask => .{ .faultmask = if (Arch.target == .v6)
                return error.Unsupported
            else
                internal.core.Register.faultmask.get() & 1 == 1 },
            .thread_privilege => .{ .thread_privilege = @enumFromInt(
                @as(u1, @truncate(internal.core.Register.control.get())),
            ) },
            .stack_pointer => .{ .thread_privilege = @enumFromInt(
                @as(u1, @truncate(internal.core.Register.control.get() >> 1)),
            ) },
            .fpu_active => .{
                .thread_privilege = if (Arch.target == .v6)
                    return error.Unsupported
                else
                    @as(u1, @truncate(internal.core.Register.control.get() >> 2)) == 1,
            },
            .systick_config => .{ .systick_config = .{
                .enabled = internal.systick.csr.enable,
                .source = internal.systick.csr.clksource,
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
            .status => |val| {
                var apsr = internal.core.Register.apsr.get();
                apsr &= 0x07ff_ffff;
                apsr |= @as(u32, @as(
                    @typeInfo(Status).@"struct".backing_integer.?,
                    @bitCast(val),
                )) << 32 - @bitSizeOf(Status);
                internal.core.Register.apsr.set(apsr);
            },
            .basepri => |val| {
                var basepri = internal.core.Register.basepri.get();
                basepri &= 0xffff_ff00;
                basepri |= val;
                internal.core.Register.basepri.set(basepri);
            },
            .primask => |val| internal.core.Register.primask.set(@intFromBool(val)),
            .faultmask => |val| internal.core.Register.faultmask.set(@intFromBool(val)),
            .thread_privilege => |val| {
                var control = internal.core.Register.control.get();
                control &= 1 << 0;
                control |= @as(u32, @intFromEnum(val)) << 0;
                internal.core.Register.control.set(control);
            },
            .stack_pointer => |val| {
                var control = internal.core.Register.control.get();
                control &= 1 << 1;
                control |= @as(u32, @intFromEnum(val)) << 1;
                internal.core.Register.control.set(control);
            },
            .fpu_active => return error.ReadOnly,
            .systick_config => |val| {
                internal.systick.rvr.* = val.reload;
                internal.systick.csr.clksource = val.source;
                internal.systick.csr.enable = val.enabled;
            },
            .systick_current => return error.ReadOnly,
            .systick_reset => internal.systick.cvr.* = 0,
            .systick_counted => return error.ReadOnly,
        }
    }

    /// Coprocessor access
    pub const Access = internal.scs.Cpacr.Access;

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
        pub const Source = internal.systick.Csr.Source;
    };
};
