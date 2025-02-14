const std = @import("std");
const Allocator = std.mem.Allocator;

const models = @import("gen/context/models.zig");
const UserQueries = @import("gen/context/users.sql.zig");
const UserQuerier = UserQueries.PoolQuerier;
const TestDB = @import("testdb.zig");

test "sqlite(context): one field queries" {
    const expectEqual = std.testing.expectEqual;
    const expectError = std.testing.expectError;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const Context = struct {
        const Self = @This();
        call_count: u8 = 0,
        called_with: i64 = 0,

        pub fn handle(ctx: *Self, user_id: i64) anyerror!void {
            ctx.call_count += 1;
            ctx.called_with = user_id;
        }
    };

    const querier = UserQuerier.init(test_db.pool);

    var empty_ctx = Context{};
    try expectError(error.NotFound, querier.getUserIDByEmail(&empty_ctx, "test@example.com"));

    try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .salary = 1000.50,
    });

    var ctx = Context{};
    try querier.getUserIDByEmail(&ctx, "test@example.com");
    try expectEqual(1, ctx.call_count);
    try expectEqual(1, ctx.called_with);
}

test "sqlite(context): many field queries" {
    const expectEqual = std.testing.expectEqual;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const Context = struct {
        const Self = @This();
        call_count: u8 = 0,
        called_with: [2]i64 = undefined,

        pub fn handle(ctx: *Self, user_id: i64) anyerror!void {
            ctx.call_count += 1;
            ctx.called_with[ctx.call_count - 1] = user_id;
        }
    };

    const querier = UserQuerier.init(test_db.pool);

    var empty_context = Context{};
    try querier.getUserIDsBySalaryRange(&empty_context, 1000, 2000);
    try expectEqual(0, empty_context.call_count);

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

    var ctx = Context{};
    try querier.getUserIDsBySalaryRange(&ctx, 1000, 2000);
    try expectEqual(2, ctx.call_count);
    try expectEqual(1, ctx.called_with[0]);
    try expectEqual(2, ctx.called_with[1]);
}

test "sqlite(context): one struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualStrings = std.testing.expectEqualStrings;
    const expectError = std.testing.expectError;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(test_db.pool);

    const Context = struct {
        const Self = @This();
        expect: bool = false,
        call_count: u8 = 0,

        pub fn handle(ctx: *Self, user: models.User) anyerror!void {
            ctx.call_count += 1;
            if (ctx.expect) {
                try expectEqual(1, user.id);
                try expect(user.created_at > 0);
                try expect(user.updated_at > 0);
                try expectEqualStrings("test", user.name);
                try expectEqualStrings("test@example.com", user.email);
                try expectEqualStrings("password", user.password);
                try expectEqual(1000.50, user.salary.?);
            }
        }
    };

    var error_ctx = Context{};
    try expectError(error.NotFound, querier.getUser(&error_ctx, 1));

    try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .salary = 1000.50,
    });

    var ctx = Context{ .expect = true };
    try querier.getUser(&ctx, 1);
}

test "sqlite(context): many struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(test_db.pool);

    const Context = struct {
        const Self = @This();
        expect: bool = false,
        call_count: u8 = 0,

        pub fn handle(ctx: *Self, user: models.User) anyerror!void {
            ctx.call_count += 1;
            if (ctx.expect) {
                try expectEqual(@as(i32, @intCast(ctx.call_count)), user.id);
                try expect(user.created_at > 0);
                try expect(user.updated_at > 0);

                var namebuf: [6]u8 = undefined;
                var emailbuf: [18]u8 = undefined;
                const name = try std.fmt.bufPrint(&namebuf, "user{d}", .{ctx.call_count});
                const email = try std.fmt.bufPrint(&emailbuf, "user{d}@example.com", .{ctx.call_count});

                try expectEqualStrings(name, user.name);
                try expectEqualStrings(email, user.email);
                try expectEqualStrings("password", user.password);
            }
        }
    };

    var empty_ctx = Context{};
    try querier.getUsers(&empty_ctx);
    try expectEqual(0, empty_ctx.call_count);

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

    var ctx = Context{ .expect = true };
    try querier.getUsers(&ctx);
    try expectEqual(2, ctx.call_count);
}

test "sqlite(context): partial struct returns" {
    const expectEqual = std.testing.expectEqual;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(test_db.pool);

    const Context = struct {
        const Self = @This();
        expect: bool = false,
        call_count: u8 = 0,

        pub fn handle(ctx: *Self, user: UserQuerier.GetUserEmailsRow) anyerror!void {
            ctx.call_count += 1;
            if (ctx.expect) {
                var emailbuf: [18]u8 = undefined;
                const email = try std.fmt.bufPrint(&emailbuf, "user{d}@example.com", .{ctx.call_count});

                try expectEqual(@as(i64, @intCast(ctx.call_count)), user.id);
                try expectEqualStrings(email, user.email);
            }
        }
    };

    var empty_ctx = Context{};
    try querier.getUserEmails(&empty_ctx);
    try expectEqual(0, empty_ctx.call_count);

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

    var ctx = Context{ .expect = true };
    try querier.getUserEmails(&ctx);
    try expectEqual(2, ctx.call_count);
}
