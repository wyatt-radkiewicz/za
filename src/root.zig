//! Embedded Zig ARM HAL - "eklipsed"
const std = @import("std");

pub const Arch = @import("arch.zig").Arch;
pub const Exception = @import("exception.zig").Exception;
pub const Register = @import("register.zig").Register;

/// Reset configuration
pub const Reset = struct {
    /// Data segment, where to get it and where to but it
    data: struct {
        source: []const u8,
        dest: []u8,
    },

    /// BSS segment, where to zero it out
    bss: []u8,

    /// Enable the fpu on startup?
    fpu: switch (Arch.target) {
        .v6 => void,
        .v7 => bool,
    } = switch (Arch.target) {
        .v6 => {},
        .v7 => false,
    },

    /// How to setup prio group?
    priogrp: switch (Arch.target) {
        .v6 => void,
        .v7 => comptime_int,
    } = switch (Arch.target) {
        .v6 => {},
        .v7 => 4,
    },

    /// Takes in a comptime this, but runs at runtime
    pub fn init(comptime this: @This()) Error!void {
        // Disable interrupts
        Register.set(.{ .primask = true }) catch return Error.Init;

        // Setup data and bss segments
        @memcpy(this.data.dest, this.data.source);
        @memset(this.bss, 0);

        // Enable fpu
        if (Arch.target != .v6 and this.fpu) {
            Register.set(.{ .fpuaccess = .full }) catch return Error.Fpu;
        }

        // Set priority group
        if (Arch.target != .v6) {
            Exception.Priority(this.priogrp).cfg();
        }

        // Enable interrupts
        Register.set(.{ .primask = false }) catch return Error.Init;
    }

    /// Error that can occur at startup
    pub const Error = error{
        Init, // Error during initialization
        Fpu, // FPU couldn't be activated
    };
};
