const ContextTests = @import("context.zig");
const ManagedTests = @import("managed.zig");
const UnmanagedTests = @import("unmanaged.zig");

test {
    _ = ManagedTests;
    _ = UnmanagedTests;
    _ = ContextTests;
}
