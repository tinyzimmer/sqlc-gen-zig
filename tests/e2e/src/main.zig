const std = @import("std");

const pg = @import("pg");

const queries = @import("gen/queries.zig");

test "generated code" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualSlices = std.testing.expectEqualSlices;
    const expectEqualStrings = std.testing.expectEqualStrings;
    const expectError = std.testing.expectError;

    const allocator = std.testing.allocator;

    var pool = try pg.Pool.init(allocator, .{ .size = 5, .connect = .{
        .port = 5432,
        .host = "127.0.0.1",
    }, .auth = .{
        .username = "postgres",
        .database = "postgres",
        .password = "postgres",
        .timeout = 10_000,
    } });
    defer pool.deinit();

    const querier = queries.PoolQuerier.init(allocator, pool);

    try expectError(error.NotFound, querier.getUser(999));

    try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
    });

    const user = try querier.getUser(1);
    defer user.deinit();

    try expectEqual(1, user.id);
    try expect(user.created_at > 0);
    try expect(user.updated_at > 0);
    try expectEqualStrings("test", user.name);
    try expectEqualStrings("test@example.com", user.email);
    try expectEqualStrings("password", user.password);
    try expectEqual(.admin, user.role);
    try expectEqualSlices(u8, &.{ 127, 0, 0, 1 }, user.ip_address.?.address);
}
