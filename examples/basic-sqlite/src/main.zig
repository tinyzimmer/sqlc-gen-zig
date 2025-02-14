const std = @import("std");

const zqlite = @import("zqlite");

const Users = @import("models/queries.sql.zig").PoolQuerier;

const schema = @embedFile("./schema/schema.sql");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var pool = try zqlite.Pool.init(allocator, .{
        .size = 5,
        .path = "./test.db",
        .flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode,
        .on_connection = null,
        .on_first_connection = null,
    });
    defer pool.deinit();
    defer std.fs.cwd().deleteFile("test.db") catch {};

    const c = pool.acquire();
    try c.exec(schema, .{});
    c.release();

    const querier = Users.init(allocator, pool);

    try querier.createUser(.{
        .name = "admin",
        .email = "admin@example.com",
        .password = "password",
        .salary = 1000.50,
    });

    try querier.createUser(.{
        .name = "user",
        .email = "user@example.com",
        .password = "password",
        .salary = 1000.50,
    });

    const by_id = try querier.getUser(1);
    defer by_id.deinit();
    std.debug.print("{d}: {s}\n", .{ by_id.id, by_id.email });

    const by_email = try querier.getUserByEmail("admin@example.com");
    defer by_email.deinit();
    std.debug.print("{d}: {s}\n", .{ by_email.id, by_email.email });
}
