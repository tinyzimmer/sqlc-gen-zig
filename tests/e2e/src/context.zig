const std = @import("std");
const Allocator = std.mem.Allocator;

const enums = @import("gen/context/enums.zig");
const models = @import("gen/context/models.zig");
const OrderQueries = @import("gen/context/orders.sql.zig");
const OrderQuerier = OrderQueries.PoolQuerier;
const UserQueries = @import("gen/context/users.sql.zig");
const UserQuerier = UserQueries.PoolQuerier;
const TestDB = @import("testdb.zig");

test "context - one field queries" {
    const expectEqual = std.testing.expectEqual;
    const expectError = std.testing.expectError;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const Context = struct {
        const Self = @This();
        call_count: u8 = 0,
        called_with: i32 = 0,

        pub fn handle(ctx: *Self, user_id: i32) anyerror!void {
            ctx.call_count += 1;
            ctx.called_with = user_id;
        }
    };

    const querier = UserQuerier.init(test_db.pool);

    var empty_ctx = Context{};
    try expectError(error.NotFound, querier.getUserIDByEmail("test@example.com", &empty_ctx));

    try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });

    var ctx = Context{};
    try querier.getUserIDByEmail("test@example.com", &ctx);
    try expectEqual(1, ctx.call_count);
    try expectEqual(1, ctx.called_with);
}

test "context - many field queries" {
    const expectEqual = std.testing.expectEqual;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const Context = struct {
        const Self = @This();
        call_count: u8 = 0,
        called_with: [2]i32 = undefined,

        pub fn handle(ctx: *Self, user_id: i32) anyerror!void {
            ctx.call_count += 1;
            ctx.called_with[ctx.call_count - 1] = user_id;
        }
    };

    const querier = UserQuerier.init(test_db.pool);

    var empty_context = Context{};
    try querier.getUserIDsByRole(.admin, &empty_context);
    try expectEqual(0, empty_context.call_count);

    try querier.createUser(.{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    try querier.createUser(.{
        .name = "user2",
        .email = "user2@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    try querier.createUser(.{
        .name = "user3",
        .email = "user3@example.com",
        .password = "password",
        .role = .user,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });

    var ctx = Context{};
    try querier.getUserIDsByRole(.admin, &ctx);
    try expectEqual(2, ctx.call_count);
    try expectEqual(1, ctx.called_with[0]);
    try expectEqual(2, ctx.called_with[1]);
}

test "context - one struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualSlices = std.testing.expectEqualSlices;
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
                try expectEqual(enums.UserRole.admin, user.role);
                try expectEqualSlices(u8, &.{ 127, 0, 0, 1 }, user.ip_address.?.address);
                try expectEqual(1000.50, user.salary.?.toFloat());
            }
        }
    };

    var error_ctx = Context{};
    try expectError(error.NotFound, querier.getUser(1, &error_ctx));

    try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });

    var ctx = Context{ .expect = true };
    try querier.getUser(1, &ctx);
}

test "context - many struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualSlices = std.testing.expectEqualSlices;
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
                const expected_role: enums.UserRole = blk: {
                    if (ctx.call_count == 1) {
                        break :blk .admin;
                    }
                    break :blk .user;
                };
                try expectEqual(expected_role, user.role);
                try expectEqualSlices(u8, &.{ 127, 0, 0, 1 }, user.ip_address.?.address);
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

    var ctx = Context{ .expect = true };
    try querier.getUsers(&ctx);
    try expectEqual(2, ctx.call_count);
}

test "context - partial struct returns" {
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

                try expectEqual(@as(i32, @intCast(ctx.call_count)), user.id);
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
        .role = .admin,
        .ip_address = "192.168.1.1",
        .salary = 1000,
    });

    try querier.createUser(.{
        .name = "user2",
        .email = "user2@example.com",
        .password = "password",
        .role = .user,
        .ip_address = "192.168.1.1",
        .salary = 500,
    });

    var ctx = Context{ .expect = true };
    try querier.getUserEmails(&ctx);
    try expectEqual(2, ctx.call_count);
}

test "context - array types" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = OrderQuerier.init(test_db.pool);

    const Context = struct {
        const Self = @This();
        expect: bool = false,
        call_count: u8 = 0,

        pub fn handle(ctx: *Self, o: models.Order) anyerror!void {
            ctx.call_count += 1;
            if (ctx.expect) {
                try expectEqual(1, o.id);
                try expect(o.order_date > 0);
                for (1..3) |expected| {
                    const item = o.item_ids.next() orelse return error.InvalidItemIDs;
                    try expectEqual(@as(i32, @intCast(expected)), item);
                }
            }
        }
    };

    var empty_ctx = Context{};
    try querier.getOrders(&empty_ctx);
    try expectEqual(0, empty_ctx.call_count);

    const item_ids: []const i32 = &.{ 1, 2, 3 };
    const item_quantities: []const f64 = &.{ 1.5, 2.5, 3.5 };
    const shipping_addresses: []const []const u8 = &.{ "address1", "address2", "address3" };
    const ip_addresses: []const []const u8 = &.{ "192.168.1.1", "172.16.0.1", "10.0.0.1" };
    const products = &[_]enums.Product{ .laptop, .desktop };

    try querier.createOrder(.{
        .order_date = std.time.milliTimestamp(),
        .item_ids = @constCast(item_ids),
        .item_quantities = @constCast(item_quantities),
        .shipping_addresses = @constCast(shipping_addresses),
        .ip_addresses = @constCast(ip_addresses),
        .products = @constCast(products),
        .total_amount = 1000.50,
    });

    var ctx = Context{ .expect = true };
    try querier.getOrders(&ctx);
    try expectEqual(1, ctx.call_count);
}
