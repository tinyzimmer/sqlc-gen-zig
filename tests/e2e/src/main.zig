const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;

const pg = @import("pg");

const queries = @import("gen/queries.zig");
const PoolQuerier = queries.PoolQuerier;

const schema = @embedFile("schema/schema.sql");

test "generated one field queries" {}

test "generated many field queries" {}

test "generated one struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualSlices = std.testing.expectEqualSlices;
    const expectEqualStrings = std.testing.expectEqualStrings;
    const expectError = std.testing.expectError;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = PoolQuerier.init(allocator, test_db.pool);

    try expectError(error.NotFound, querier.getUser(1));

    try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
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
    try expectEqual(1000.50, user.salary.?.toFloat());
}

test "generated many struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualSlices = std.testing.expectEqualSlices;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = PoolQuerier.init(allocator, test_db.pool);

    const empty_users = try querier.getUsers();
    try expectEqual(0, empty_users.len);

    try querier.createUser(.{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
    });

    try querier.createUser(.{
        .name = "user2",
        .email = "user2@example.com",
        .password = "password",
        .role = .user,
        .ip_address = "127.0.0.1",
    });

    const users = try querier.getUsers();
    defer {
        if (users.len > 0) {
            for (users) |user| {
                user.deinit();
            }
            allocator.free(users);
        }
    }
    try expectEqual(2, users.len);
    for (1..2) |idx| {
        const user = &users[idx - 1];
        try expectEqual(@as(i32, @intCast(idx)), user.id);
        try expect(user.created_at > 0);
        try expect(user.updated_at > 0);

        var namebuf: [6]u8 = undefined;
        var emailbuf: [18]u8 = undefined;
        const name = try std.fmt.bufPrint(&namebuf, "user{d}", .{idx});
        const email = try std.fmt.bufPrint(&emailbuf, "user{d}@example.com", .{idx});

        try expectEqualStrings(name, user.name);
        try expectEqualStrings(email, user.email);
        try expectEqualStrings("password", user.password);
        try expectEqual(.admin, user.role);
        try expectEqualSlices(u8, &.{ 127, 0, 0, 1 }, user.ip_address.?.address);
    }
}

const TestDB = struct {
    allocator: Allocator,
    db_name: []const u8,
    pool: *pg.Pool,

    fn init(allocator: Allocator) !TestDB {
        var prng = DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
        var rand = prng.random();

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

        var db_name: [16:0]u8 = undefined;
        const chars = "abcdefghijklmnopqrstuvwxyz";
        for (0..16) |idx| {
            db_name[idx] = chars[rand.intRangeLessThan(usize, 0, chars.len)];
        }

        const query = try std.fmt.allocPrint(allocator, "CREATE DATABASE {s}", .{db_name[0..]});
        defer allocator.free(query);
        _ = try pool.exec(query, .{});

        const temp_db_name = try allocator.dupe(u8, db_name[0..]);
        var temp_pool = try pg.Pool.init(allocator, .{ .size = 1, .connect = .{
            .port = 5432,
            .host = "127.0.0.1",
        }, .auth = .{
            .username = "postgres",
            .password = "postgres",
            .database = temp_db_name,
            .timeout = 10_000,
        } });
        _ = try temp_pool.exec(schema, .{});
        return .{
            .allocator = allocator,
            .db_name = temp_db_name,
            .pool = temp_pool,
        };
    }

    fn deinit(self: *TestDB) void {
        self.pool.deinit();
        self.allocator.free(self.db_name);
    }
};
