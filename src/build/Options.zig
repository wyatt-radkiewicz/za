//! Options that can be passed in to "za" dependency
const std = @import("std");

/// Omit frame pointer?
omit_frame_pointer: bool = false,

/// Gets the options from the builder
pub fn init(b: *std.Build) @This() {
    var this = @This(){};
    inline for (std.meta.fields(@This())) |field| {
        const desc = fieldDesc(std.meta.stringToEnum(
            std.meta.FieldEnum(@This()),
            field.name,
        ).?);
        @field(this, field.name) = b.option(field.type, field.name, desc) orelse
            @as(*const field.type, @ptrCast(field.default_value_ptr)).*;
    }
    return this;
}

/// Gets description for an option
pub fn fieldDesc(option: std.meta.FieldEnum(@This())) []const u8 {
    return switch (option) {
        .omit_frame_pointer => "Omit frame pointer setup (default: false)",
    };
}
