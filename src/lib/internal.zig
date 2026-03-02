//! Internal registers
const std = @import("std");

// System control space
pub const scs = struct {
    pub const Icsr = packed struct(u32) {
        vectactive: u9 = 0, // Is there any currently running handler? (0 for thread mode)
        reserved0: u2 = 0,
        rettobase: bool = false, // True if there is an exception active other than the one in IPSR
        vectpending: u9 = 0, // Exception number for highest priority pending exception
        reserved1: u1 = 0,
        isrpending: bool = false, // Indicates if an external interrupt is pending
        isrpreempt: bool = false, // True if pending exception will be serviced after halt state
        reserved2: u1 = 0,
        pendstclr: bool = false, // Clears a pending sys_tick handler
        pendstset: bool = false, // Sets a pending sys_tick handler or gets its pending state
        pendsvclr: bool = false, // Clears a pending SVCall
        pendsvset: bool = false, // Sets or gets SVCall pending state
        reserved3: u2 = 0,
        nmipendset: bool = false, // Gets nmi active state or sets it (its always instantly serviced)
    };
    pub const icsr: *volatile Icsr = @ptrFromInt(0xe000_ed04);
    pub const Scr = packed struct(u32) {
        reserved0: u1 = 0,
        sleeponexit: bool = false,
        sleepdeep: bool = false,
        reserved1: u1 = 0,
        sevonpend: bool = false, // When an interrupt goes from inactive to pending, do SEV?
        reserved2: u27 = 0,
    };
    pub const scr: *volatile Scr = @ptrFromInt(0xe000_ed10);
    pub const Ccr = packed struct(u32) {
        /// Controls whether the processor can enter Thread mode with exceptions active
        /// 0 -> Any attempt to go back if an exception is still active results in exception
        /// 1 -> Thread mode can be entered with exceptions active based on return value
        nonbasethrdena: bool = false,
        /// Controls whether unprivileged software can access the STIR
        usersetmpend: bool = false,
        reserved0: u1 = 0,
        /// Controls the trapping of unaligned word or halfword accesses
        unalign_trp: bool = false,
        /// Controls the trap on divide by 0
        div_0_trp: bool = false,
        reserved1: u3 = 0,
        /// Ignore data access faults in prio -1 or -2 handlers. Disabled means lockup processor
        bfhfnmign: bool = false,
        /// Align the stack to 8 bytes when entering an exception handler
        stkalign: bool = false,
        reserved2: u6 = 0,
        /// Data cache enable
        dc: bool = false,
        /// Instruction cache enable
        ic: bool = false,
        /// Branch predictor enable bit
        bp: bool = false,
        reserved3: u13 = 0,
    };
    pub const Aircr = packed struct(u32) {
        vectreset: bool = false, // Cause a local reset
        vectclractive: bool = false, // Reset interrupt active state info
        sysresetreq: bool = false, // Signal external system to cause local reset
        reserved0: u5 = 0,
        prigroup: u3 = 0, // Priority grouping bit position
        reserved1: u4 = 0,
        endianess: Endian = .little, // Read only
        vectkey: u16 = 0, // I literally don't know

        pub const Endian = enum(u1) { little, big };
    };
    pub const aircr: *volatile Aircr = @ptrFromInt(0xe000_ed0c);
    pub const Shcsr = packed struct(u32) {
        memfaultact: bool = false,
        busfaultact: bool = false,
        reserved0: u1 = 0,
        usgfaultact: bool = false,
        reserved1: u3 = 0,
        svcallact: bool = false,
        monitoract: bool = false,
        reserved2: u1 = 0,
        pendsvact: bool = false,
        systickact: bool = false,
        usgfaultpended: bool = false,
        memfaultpended: bool = false,
        busfaultpended: bool = false,
        svcallpended: bool = false,
        memfaultena: bool = false,
        busfaultena: bool = false,
        usgfaultena: bool = false,
        reserved3: u13 = 0,
    };
    pub const shcsr: *volatile Shcsr = @ptrFromInt(0xe000_ed24);
    pub const Cpacr = packed struct(u32) {
        reserved0: u20 = 0,
        cp10: Access = .denied,
        cp11: Access = .denied,
        reserved1: u8 = 0,

        pub const Access = enum(u2) {
            denied,
            privileged,
            reserved,
            full,
        };
    };
    pub const cpacr: *volatile Cpacr = @ptrFromInt(0xe000_ed88);
    pub const shpr: [*]volatile u8 = @ptrFromInt(0xe000_ed18);
};

// SysTick
pub const systick = struct {
    pub const Csr = packed struct(u32) {
        enable: bool = false,
        tickint: bool = false,
        clksource: Source = .cpu,
        reserved0: u13 = 0,
        countflag: bool = false,
        reserved1: u15 = 0,

        pub const Source = enum(u1) { cpu, external };
    };
    pub const csr: *volatile Csr = @ptrFromInt(0xe000_e010);
    pub const rvr: *volatile u32 = @ptrFromInt(0xe000_e014);
    pub const cvr: *volatile u32 = @ptrFromInt(0xe000_e018);

    pub const Calib = packed struct(u32) {
        tenms: u24 = 0,
        reserved0: u6 = 0,
        skew: bool = false, // Shows if the tenms calibration value is exact
        noref: bool = false,
    };
    pub const calib: *volatile Calib = @ptrFromInt(0xe000_e01c);
};

// Nested vector interrupt controller
pub const nvic = struct {
    pub const ipr: [*]volatile u8 = @ptrFromInt(0xe000_e400);
    pub const iser: [*]volatile u32 = @ptrFromInt(0xe000_e100);
    pub const icer: [*]volatile u32 = @ptrFromInt(0xe000_e180);
    pub const ispr: [*]volatile u32 = @ptrFromInt(0xe000_e200);
    pub const icpr: [*]volatile u32 = @ptrFromInt(0xe000_e280);
};
