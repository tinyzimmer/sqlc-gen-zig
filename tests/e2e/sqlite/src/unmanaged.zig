const std = @import("std");
const Allocator = std.mem.Allocator;

const models = @import("gen/unmanaged/models.zig");
const UserQueries = @import("gen/unmanaged/users.sql.zig");
const UserQuerier = UserQueries.PoolQuerier;
const TestDB = @import("testdb.zig");

test "sqlite(unmanaged): one field queries" {
    const expectEqual = std.testing.expectEqual;
    const expectError = std.testing.expectError;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(test_db.pool);
    try expectError(error.NotFound, querier.getUserIDByEmail("test@example.com"));

    try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .salary = 1000.50,
    });

    const user_id = try querier.getUserIDByEmail("test@example.com");
    try expectEqual(1, user_id);
}

test "sqlite(unmanaged): many field queries" {
    const expectEqual = std.testing.expectEqual;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(test_db.pool);
    const empty_users = try querier.getUserIDsBySalaryRange(allocator, 1000, 2000);
    try expectEqual(0, empty_users.len);

    try querier.createUser(.{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
        .salary = 1000.50,
    });
    try querier.createUser(.{
        .name = "user2",
        .email = "user2@example.com",
        .password = "password",
        .salary = 1500.50,
    });
    try querier.createUser(.{
        .name = "user3",
        .email = "user3@example.com",
        .password = "password",
        .salary = 2000.50,
    });

    const user_ids = try querier.getUserIDsBySalaryRange(allocator, 1000, 2000);
    defer if (user_ids.len > 0) {
        allocator.free(user_ids);
    };
    try expectEqual(2, user_ids.len);
}

test "sqlite(unmanaged): one struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualStrings = std.testing.expectEqualStrings;
    const expectError = std.testing.expectError;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(test_db.pool);

    try expectError(error.NotFound, querier.getUser(allocator, 1));

    try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .salary = 1000.50,
    });

    const user = try querier.getUser(allocator, 1);
    defer user.deinit();

    try expectEqual(1, user.id);
    try expect(user.created_at > 0);
    try expect(user.updated_at > 0);
    try expectEqualStrings("test", user.name);
    try expectEqualStrings("test@example.com", user.email);
    try expectEqualStrings("password", user.password);
    try expectEqual(1000.50, user.salary.?);
}

test "sqlite(unmanaged): many struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(test_db.pool);

    const empty_users = try querier.getUsers(allocator);
    try expectEqual(0, empty_users.len);

    try querier.createUser(.{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
    });

    try querier.createUser(.{
        .name = "user2",
        .email = "user2@example.com",
        .password = "password",
    });

    const users = try querier.getUsers(allocator);
    defer if (users.len > 0) {
        for (users) |user| {
            user.deinit();
        }
        allocator.free(users);
    };
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
    }
}

test "sqlite(unmanaged): partial struct returns" {
    const expectEqual = std.testing.expectEqual;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(test_db.pool);

    const empty = try querier.getUserEmails(allocator);
    try expectEqual(0, empty.len);

    try querier.createUser(.{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
        .salary = 1000,
    });

    try querier.createUser(.{
        .name = "user2",
        .email = "user2@example.com",
        .password = "password",
        .salary = 500,
    });

    const users = try querier.getUserEmails(allocator);
    defer if (users.len > 0) {
        for (users) |user| {
            user.deinit();
        }
        allocator.free(users);
    };
    try expectEqual(2, users.len);
    for (1..2) |idx| {
        const user = &users[idx - 1];

        var emailbuf: [18]u8 = undefined;
        const email = try std.fmt.bufPrint(&emailbuf, "user{d}@example.com", .{idx});

        try expectEqual(@as(i32, @intCast(idx)), user.id);
        try expectEqualStrings(email, user.email);
    }
}
