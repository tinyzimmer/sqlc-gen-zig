const std = @import("std");
const Allocator = std.mem.Allocator;

const models = @import("gen/contextunions/models.zig");
const OrderQueries = @import("gen/contextunions/orders.sql.zig");
const OrderQuerier = OrderQueries.PoolQuerier;
const UserQueries = @import("gen/contextunions/users.sql.zig");
const UserQuerier = UserQueries.PoolQuerier;
const TestDB = @import("testdb.zig");

const MustCreateUserContext = struct {
    const Self = @This();

    pub fn handle(_: *Self, result: UserQuerier.CreateUserResult) anyerror!void {
        switch (result) {
            .ok => {},
            .pgerr => return error.UnexpectedPGError,
        }
    }
};

const MustCreateOrderContext = struct {
    const Self = @This();

    pub fn handle(_: *Self, result: OrderQuerier.CreateOrderResult) anyerror!void {
        switch (result) {
            .ok => {},
            .pgerr => return error.UnexpectedPGError,
        }
    }
};

test "contextunions - one field queries" {
    const expectEqual = std.testing.expectEqual;
    const expectError = std.testing.expectError;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const Context = struct {
        const Self = @This();
        call_count: u8 = 0,
        called_with: i32 = 0,

        pub fn handle(ctx: *Self, result: UserQuerier.GetUserIDByEmailResult) anyerror!void {
            ctx.call_count += 1;
            switch (result) {
                .id => |id| ctx.called_with = id,
                .pgerr => return error.UnexpectedPGError,
            }
        }
    };

    const querier = UserQuerier.init(test_db.pool);

    var empty_ctx = Context{};
    try expectError(error.NotFound, querier.getUserIDByEmail(&empty_ctx, "test@example.com"));

    var create_ctx = MustCreateUserContext{};
    try querier.createUser(&create_ctx, .{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });

    var ctx = Context{};
    try querier.getUserIDByEmail(&ctx, "test@example.com");
    try expectEqual(1, ctx.call_count);
    try expectEqual(1, ctx.called_with);
}

test "contextunions - unique constraints" {
    const expect = std.testing.expect;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(test_db.pool);

    const Context = struct {
        expect_err: bool = false,
        pub fn handle(self: @This(), result: UserQuerier.CreateUserResult) anyerror!void {
            switch (result) {
                .ok => {
                    if (self.expect_err) {
                        return error.ExpectedUniqueError;
                    }
                },
                .pgerr => {
                    if (!self.expect_err) {
                        return error.UnexpectedPGError;
                    }
                    const err = result.err() orelse unreachable;
                    try expect(err.isUnique());
                },
            }
        }
    };

    var ctx = Context{ .expect_err = false };
    try querier.createUser(&ctx, .{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });

    var err_ctx = Context{ .expect_err = true };
    try querier.createUser(&err_ctx, .{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
}

test "contextunions - many field queries" {
    const expectEqual = std.testing.expectEqual;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const Context = struct {
        const Self = @This();
        call_count: u8 = 0,
        called_with: [2]i32 = undefined,

        pub fn handle(ctx: *Self, result: UserQuerier.GetUserIDByEmailResult) anyerror!void {
            ctx.call_count += 1;
            switch (result) {
                .id => |id| ctx.called_with[ctx.call_count - 1] = id,
                .pgerr => return error.UnexpectedPGError,
            }
        }
    };

    const querier = UserQuerier.init(test_db.pool);

    var empty_context = Context{};
    try querier.getUserIDsByRole(&empty_context, .admin);
    try expectEqual(0, empty_context.call_count);

    var create_ctx = MustCreateUserContext{};
    try querier.createUser(&create_ctx, .{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    try querier.createUser(&create_ctx, .{
        .name = "user2",
        .email = "user2@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    try querier.createUser(&create_ctx, .{
        .name = "user3",
        .email = "user3@example.com",
        .password = "password",
        .role = .user,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });

    var ctx = Context{};
    try querier.getUserIDsByRole(&ctx, .admin);
    try expectEqual(2, ctx.call_count);
    try expectEqual(1, ctx.called_with[0]);
    try expectEqual(2, ctx.called_with[1]);
}

test "contextunions - one struct queries" {
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

        pub fn handle(ctx: *Self, result: UserQuerier.GetUserResult) anyerror!void {
            ctx.call_count += 1;
            if (ctx.expect) {
                const user = try blk: {
                    switch (result) {
                        .user => break :blk result.user,
                        .pgerr => break :blk error.UnexpectedPGError,
                    }
                };
                try expectEqual(1, user.id);
                try expect(user.created_at > 0);
                try expect(user.updated_at > 0);
                try expectEqualStrings("test", user.name);
                try expectEqualStrings("test@example.com", user.email);
                try expectEqualStrings("password", user.password);
                try expectEqual(models.UserRole.admin, user.role);
                try expectEqualSlices(u8, &.{ 127, 0, 0, 1 }, user.ip_address.?.address);
                try expectEqual(1000.50, user.salary.?.toFloat());
            }
        }
    };

    var error_ctx = Context{};
    try expectError(error.NotFound, querier.getUser(&error_ctx, 1));

    var create_ctx = MustCreateUserContext{};
    try querier.createUser(&create_ctx, .{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });

    var ctx = Context{ .expect = true };
    try querier.getUser(&ctx, 1);
}

test "contextunions - many struct queries" {
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

        pub fn handle(ctx: *Self, result: UserQuerier.GetUsersResult) anyerror!void {
            ctx.call_count += 1;
            if (ctx.expect) {
                const user = try blk: {
                    switch (result) {
                        .user => break :blk result.user,
                        .pgerr => break :blk error.UnexpectedPGError,
                    }
                };
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
                const expected_role: models.UserRole = blk: {
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

    var create_ctx = MustCreateUserContext{};
    try querier.createUser(&create_ctx, .{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
    });

    try querier.createUser(&create_ctx, .{
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

test "contextunions - partial struct returns" {
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

        pub fn handle(ctx: *Self, result: UserQuerier.GetUserEmailsResult) anyerror!void {
            ctx.call_count += 1;
            if (ctx.expect) {
                const user = try blk: {
                    switch (result) {
                        .get_user_emails_row => break :blk result.get_user_emails_row,
                        .pgerr => break :blk error.UnexpectedPGError,
                    }
                };
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

    var create_ctx = MustCreateUserContext{};
    try querier.createUser(&create_ctx, .{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "192.168.1.1",
        .salary = 1000,
    });

    try querier.createUser(&create_ctx, .{
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

test "contextunions - array types" {
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

        pub fn handle(ctx: *Self, result: OrderQuerier.GetOrdersResult) anyerror!void {
            ctx.call_count += 1;
            if (ctx.expect) {
                const o = try blk: {
                    switch (result) {
                        .order => break :blk result.order,
                        .pgerr => break :blk error.UnexpectedPGError,
                    }
                };
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
    const products = &[_]models.Product{ .laptop, .desktop };

    var create_ctx = MustCreateOrderContext{};
    try querier.createOrder(&create_ctx, .{
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
