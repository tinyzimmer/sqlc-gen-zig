const std = @import("std");

const pg = @import("pg");

const Users = @import("models/queries.sql.zig").PoolQuerier;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var pool = try pg.Pool.init(allocator, .{ .size = 1, .connect = .{
        .port = 5432,
        .host = "127.0.0.1",
    }, .auth = .{
        .username = "postgres",
        .password = "postgres",
        .database = "postgres",
        .timeout = 10_000,
    } });
    defer pool.deinit();

    const querier = Users.init(allocator, pool);

    try querier.createUser(.{
        .name = "admin",
        .email = "admin@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "192.168.1.1",
        .salary = 1000.50,
    });

    try querier.createUser(.{
        .name = "user",
        .email = "user@example.com",
        .password = "password",
        .role = .user,
        .ip_address = "192.168.1.1",
        .salary = 1000.50,
    });

    const by_id = try querier.getUser(1);
    defer by_id.deinit();
    std.debug.print("{d}: {s}\n", .{ by_id.id, by_id.email });

    const by_email = try querier.getUserByEmail("admin@example.com");
    defer by_email.deinit();
    std.debug.print("{d}: {s}\n", .{ by_email.id, by_email.email });

    const by_role = try querier.getUsersByRole(.admin);
    defer {
        if (by_role.len > 0) {
            for (by_role) |user| {
                user.deinit();
            }
            allocator.free(by_role);
        }
    }
    for (by_role) |user| {
        std.debug.print("{d}: {s}\n", .{ user.id, user.email });
    }
}
