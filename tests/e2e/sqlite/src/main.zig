const std = @import("std");

pub const ManagedTests = @import("managed.zig");

test {
    std.testing.refAllDecls(@This());
}
