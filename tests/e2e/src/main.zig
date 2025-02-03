const std = @import("std");

const pg = @import("pg");

pub const ContextTests = @import("context.zig");
pub const ManagedTests = @import("managed.zig");
pub const UnmanagedTests = @import("unmanaged.zig");

test {
    std.testing.refAllDecls(@This());
}
