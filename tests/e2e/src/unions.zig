const std = @import("std");
const Allocator = std.mem.Allocator;

const enums = @import("gen/unions/enums.zig");
const OrderQueries = @import("gen/unions/orders.sql.zig");
const OrderQuerier = OrderQueries.PoolQuerier;
const UserQueries = @import("gen/unions/users.sql.zig");
const UserQuerier = UserQueries.PoolQuerier;
const TestDB = @import("testdb.zig");

test "unions - one field queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectError = std.testing.expectError;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(allocator, test_db.pool);
    try expectError(error.NotFound, querier.getUserIDByEmail("test@example.com"));

    const result = try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    try expectEqual(.ok, result);

    const user_id_result = try querier.getUserIDByEmail("test@example.com");
    try expectEqual(1, user_id_result.id);

    // We should get a unique error
    const unique_err = try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    const err = unique_err.err() orelse unreachable;
    defer allocator.free(unique_err.pgerr);
    try expect(err.?.isUnique());
}

// test "managed - many field queries" {
//     const expectEqual = std.testing.expectEqual;
//     const allocator = std.testing.allocator;

//     var test_db = try TestDB.init(allocator);
//     defer test_db.deinit();

//     const querier = UserQuerier.init(allocator, test_db.pool);
//     const empty_users = try querier.getUserIDsByRole(.admin);
//     try expectEqual(0, empty_users.len);

//     try querier.createUser(.{
//         .name = "user1",
//         .email = "user1@example.com",
//         .password = "password",
//         .role = .admin,
//         .ip_address = "127.0.0.1",
//         .salary = 1000.50,
//     });
//     try querier.createUser(.{
//         .name = "user2",
//         .email = "user2@example.com",
//         .password = "password",
//         .role = .admin,
//         .ip_address = "127.0.0.1",
//         .salary = 1000.50,
//     });
//     try querier.createUser(.{
//         .name = "user3",
//         .email = "user3@example.com",
//         .password = "password",
//         .role = .user,
//         .ip_address = "127.0.0.1",
//         .salary = 1000.50,
//     });

//     const user_ids = try querier.getUserIDsByRole(.admin);
//     defer {
//         if (user_ids.len > 0) {
//             allocator.free(user_ids);
//         }
//     }
//     try expectEqual(2, user_ids.len);
// }

// test "managed - one struct queries" {
//     const expect = std.testing.expect;
//     const expectEqual = std.testing.expectEqual;
//     const expectEqualSlices = std.testing.expectEqualSlices;
//     const expectEqualStrings = std.testing.expectEqualStrings;
//     const expectError = std.testing.expectError;

//     const allocator = std.testing.allocator;

//     var test_db = try TestDB.init(allocator);
//     defer test_db.deinit();

//     const querier = UserQuerier.init(allocator, test_db.pool);

//     try expectError(error.NotFound, querier.getUser(1));

//     try querier.createUser(.{
//         .name = "test",
//         .email = "test@example.com",
//         .password = "password",
//         .role = .admin,
//         .ip_address = "127.0.0.1",
//         .salary = 1000.50,
//     });

//     const user = try querier.getUser(1);
//     defer user.deinit();

//     try expectEqual(1, user.id);
//     try expect(user.created_at > 0);
//     try expect(user.updated_at > 0);
//     try expectEqualStrings("test", user.name);
//     try expectEqualStrings("test@example.com", user.email);
//     try expectEqualStrings("password", user.password);
//     try expectEqual(.admin, user.role);
//     try expectEqualSlices(u8, &.{ 127, 0, 0, 1 }, user.ip_address.?.address);
//     try expectEqual(1000.50, user.salary.?.toFloat());
// }

// test "managed - many struct queries" {
//     const expect = std.testing.expect;
//     const expectEqual = std.testing.expectEqual;
//     const expectEqualSlices = std.testing.expectEqualSlices;
//     const expectEqualStrings = std.testing.expectEqualStrings;

//     const allocator = std.testing.allocator;

//     var test_db = try TestDB.init(allocator);
//     defer test_db.deinit();

//     const querier = UserQuerier.init(allocator, test_db.pool);

//     const empty_users = try querier.getUsers();
//     try expectEqual(0, empty_users.len);

//     try querier.createUser(.{
//         .name = "user1",
//         .email = "user1@example.com",
//         .password = "password",
//         .role = .admin,
//         .ip_address = "127.0.0.1",
//     });

//     try querier.createUser(.{
//         .name = "user2",
//         .email = "user2@example.com",
//         .password = "password",
//         .role = .user,
//         .ip_address = "127.0.0.1",
//     });

//     const users = try querier.getUsers();
//     defer {
//         if (users.len > 0) {
//             for (users) |user| {
//                 user.deinit();
//             }
//             allocator.free(users);
//         }
//     }
//     try expectEqual(2, users.len);
//     for (1..2) |idx| {
//         const user = &users[idx - 1];
//         try expectEqual(@as(i32, @intCast(idx)), user.id);
//         try expect(user.created_at > 0);
//         try expect(user.updated_at > 0);

//         var namebuf: [6]u8 = undefined;
//         var emailbuf: [18]u8 = undefined;
//         const name = try std.fmt.bufPrint(&namebuf, "user{d}", .{idx});
//         const email = try std.fmt.bufPrint(&emailbuf, "user{d}@example.com", .{idx});

//         try expectEqualStrings(name, user.name);
//         try expectEqualStrings(email, user.email);
//         try expectEqualStrings("password", user.password);
//         try expectEqual(.admin, user.role);
//         try expectEqualSlices(u8, &.{ 127, 0, 0, 1 }, user.ip_address.?.address);
//     }
// }

// test "managed - special type queries" {
//     const expectEqual = std.testing.expectEqual;

//     const allocator = std.testing.allocator;

//     var test_db = try TestDB.init(allocator);
//     defer test_db.deinit();

//     const querier = UserQuerier.init(allocator, test_db.pool);
//     const empty = try querier.getUserIDsBySalaryRange(0, 1000);
//     try expectEqual(0, empty.len);

//     try querier.createUser(.{
//         .name = "user1",
//         .email = "user1@example.com",
//         .password = "password",
//         .role = .admin,
//         .ip_address = "192.168.1.1",
//         .salary = 1000,
//     });

//     try querier.createUser(.{
//         .name = "user2",
//         .email = "user2@example.com",
//         .password = "password",
//         .role = .user,
//         .ip_address = "192.168.1.1",
//         .salary = 500,
//     });

//     try querier.createUser(.{
//         .name = "user3",
//         .email = "user3@example.com",
//         .password = "password",
//         .role = .user,
//         .ip_address = "192.168.1.2",
//         .salary = 1500,
//     });

//     const users = try querier.getUserIDsBySalaryRange(0, 1000);
//     defer {
//         if (users.len > 0) {
//             allocator.free(users);
//         }
//     }
//     try expectEqual(2, users.len);

//     const ip_users = try querier.getUserIDsByIPAddress("192.168.1.1");
//     defer {
//         if (ip_users.len > 0) {
//             allocator.free(ip_users);
//         }
//     }
//     try expectEqual(2, ip_users.len);
// }

// test "managed - partial struct returns" {
//     const expectEqual = std.testing.expectEqual;
//     const expectEqualStrings = std.testing.expectEqualStrings;

//     const allocator = std.testing.allocator;

//     var test_db = try TestDB.init(allocator);
//     defer test_db.deinit();

//     const querier = UserQuerier.init(allocator, test_db.pool);

//     const empty = try querier.getUserEmails();
//     try expectEqual(0, empty.len);

//     try querier.createUser(.{
//         .name = "user1",
//         .email = "user1@example.com",
//         .password = "password",
//         .role = .admin,
//         .ip_address = "192.168.1.1",
//         .salary = 1000,
//     });

//     try querier.createUser(.{
//         .name = "user2",
//         .email = "user2@example.com",
//         .password = "password",
//         .role = .user,
//         .ip_address = "192.168.1.1",
//         .salary = 500,
//     });

//     const users = try querier.getUserEmails();
//     defer {
//         if (users.len > 0) {
//             for (users) |user| {
//                 user.deinit();
//             }
//             allocator.free(users);
//         }
//     }
//     try expectEqual(2, users.len);
//     for (1..2) |idx| {
//         const user = &users[idx - 1];

//         var emailbuf: [18]u8 = undefined;
//         const email = try std.fmt.bufPrint(&emailbuf, "user{d}@example.com", .{idx});

//         try expectEqual(@as(i32, @intCast(idx)), user.id);
//         try expectEqualStrings(email, user.email);
//     }
// }

// test "managed - array types" {
//     const expect = std.testing.expect;
//     const expectEqual = std.testing.expectEqual;
//     const expectEqualStrings = std.testing.expectEqualStrings;

//     const allocator = std.testing.allocator;

//     var test_db = try TestDB.init(allocator);
//     defer test_db.deinit();

//     const querier = OrderQuerier.init(allocator, test_db.pool);

//     const empty = try querier.getOrders();
//     try expectEqual(0, empty.len);

//     const item_ids: []const i32 = &.{ 1, 2, 3 };
//     const item_quantities: []const f64 = &.{ 1.5, 2.5, 3.5 };
//     const shipping_addresses: []const []const u8 = &.{ "address1", "address2", "address3" };
//     const ip_addresses: []const []const u8 = &.{ "192.168.1.1", "172.16.0.1", "10.0.0.1" };
//     const products = &[_]enums.Product{ .laptop, .desktop };

//     try querier.createOrder(.{
//         .order_date = std.time.milliTimestamp(),
//         .item_ids = @constCast(item_ids),
//         .item_quantities = @constCast(item_quantities),
//         .shipping_addresses = @constCast(shipping_addresses),
//         .ip_addresses = @constCast(ip_addresses),
//         .products = @constCast(products),
//         .total_amount = 1000.50,
//     });

//     const order = try querier.getOrders();
//     defer {
//         if (order.len > 0) {
//             for (order) |o| {
//                 o.deinit();
//             }
//             allocator.free(order);
//         }
//     }
//     try expectEqual(1, order.len);

//     const o = &order[0];
//     try expectEqual(1, o.id);
//     try expect(o.order_date > 0);
//     try expectEqual(3, o.item_ids.len);
//     try expectEqual(1, o.item_ids[0]);
//     try expectEqual(2, o.item_ids[1]);
//     try expectEqual(3, o.item_ids[2]);
//     try expectEqual(3, o.item_quantities.len);
//     try expectEqual(1.5, o.item_quantities[0].toFloat());
//     try expectEqual(2.5, o.item_quantities[1].toFloat());
//     try expectEqual(3.5, o.item_quantities[2].toFloat());
//     try expectEqual(3, o.shipping_addresses.len);
//     try expectEqualStrings("address1", o.shipping_addresses[0]);
//     try expectEqualStrings("address2", o.shipping_addresses[1]);
//     try expectEqualStrings("address3", o.shipping_addresses[2]);
//     try expectEqual(3, o.ip_addresses.len);
//     try expectEqualStrings(&.{ 192, 168, 1, 1 }, o.ip_addresses[0].address);
//     try expectEqualStrings(&.{ 172, 16, 0, 1 }, o.ip_addresses[1].address);
//     try expectEqualStrings(&.{ 10, 0, 0, 1 }, o.ip_addresses[2].address);
//     try expectEqual(2, o.products.len);
//     try expectEqual(.laptop, o.products[0]);
//     try expectEqual(.desktop, o.products[1]);
// }
