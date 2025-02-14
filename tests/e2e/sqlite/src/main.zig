const std = @import("std");

pub const ManagedTests = @import("managed.zig");
pub const UnmanagedTests = @import("unmanaged.zig");

test {
    std.testing.refAllDecls(@This());
}
