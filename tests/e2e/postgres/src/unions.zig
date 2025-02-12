const std = @import("std");
const Allocator = std.mem.Allocator;

const OrderQueries = @import("gen/unions/orders.sql.zig");
const OrderQuerier = OrderQueries.PoolQuerier;
const UserQueries = @import("gen/unions/users.sql.zig");
const UserQuerier = UserQueries.PoolQuerier;
const TestDB = @import("testdb.zig");

test "postgres(unions): one field queries" {
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
    switch (result) {
        .ok => {},
        .pgerr => return error.UnexpectedPGError,
    }

    const user_id_result = try querier.getUserIDByEmail("test@example.com");
    switch (user_id_result) {
        .id => |id| try expectEqual(1, id),
        .pgerr => return error.UnexpectedPGError,
    }
}

test "postgres(unions): unique constraints" {
    const expect = std.testing.expect;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(allocator, test_db.pool);

    var result = try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    switch (result) {
        .ok => {},
        .pgerr => return error.UnexpectedPGError,
    }

    // We should get a unique error
    result = try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    switch (result) {
        .ok => return error.ExpectedUniqueError,
        .pgerr => {
            const err = result.err() orelse unreachable;
            defer allocator.free(result.pgerr);
            try expect(err.isUnique());
        },
    }
}

test "postgres(unions): many field queries" {
    const expectEqual = std.testing.expectEqual;
    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(allocator, test_db.pool);
    const empty_users = try querier.getUserIDsByRole(.admin);
    try expectEqual(0, empty_users.id_list.len);

    var create = try querier.createUser(.{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    switch (create) {
        .ok => {},
        .pgerr => return error.UnexpectedPGError,
    }
    create = try querier.createUser(.{
        .name = "user2",
        .email = "user2@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    switch (create) {
        .ok => {},
        .pgerr => return error.UnexpectedPGError,
    }
    create = try querier.createUser(.{
        .name = "user3",
        .email = "user3@example.com",
        .password = "password",
        .role = .user,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    switch (create) {
        .ok => {},
        .pgerr => return error.UnexpectedPGError,
    }

    const result = try querier.getUserIDsByRole(.admin);
    switch (result) {
        .id_list => |id_list| {
            defer {
                if (id_list.len > 0) {
                    allocator.free(id_list);
                }
            }
            try expectEqual(2, id_list.len);
        },
        .pgerr => return error.UnexpectedPGError,
    }
}

test "postgres(unions): one struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualSlices = std.testing.expectEqualSlices;
    const expectEqualStrings = std.testing.expectEqualStrings;
    const expectError = std.testing.expectError;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(allocator, test_db.pool);

    try expectError(error.NotFound, querier.getUser(1));

    const create = try querier.createUser(.{
        .name = "test",
        .email = "test@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
        .salary = 1000.50,
    });
    switch (create) {
        .ok => {},
        .pgerr => return error.UnexpectedPGError,
    }

    const result = try querier.getUser(1);
    switch (result) {
        .user => |user| {
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
        },
        .pgerr => return error.UnexpectedPGError,
    }
}

test "postgres(unions): many struct queries" {
    const expect = std.testing.expect;
    const expectEqual = std.testing.expectEqual;
    const expectEqualSlices = std.testing.expectEqualSlices;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const allocator = std.testing.allocator;

    var test_db = try TestDB.init(allocator);
    defer test_db.deinit();

    const querier = UserQuerier.init(allocator, test_db.pool);

    const empty_users = try querier.getUsers();
    switch (empty_users) {
        .user_list => |user_list| try expectEqual(0, user_list.len),
        .pgerr => return error.UnexpectedPGError,
    }

    var create = try querier.createUser(.{
        .name = "user1",
        .email = "user1@example.com",
        .password = "password",
        .role = .admin,
        .ip_address = "127.0.0.1",
    });
    switch (create) {
        .ok => {},
        .pgerr => return error.UnexpectedPGError,
    }

    create = try querier.createUser(.{
        .name = "user2",
        .email = "user2@example.com",
        .password = "password",
        .role = .user,
        .ip_address = "127.0.0.1",
    });
    switch (create) {
        .ok => {},
        .pgerr => return error.UnexpectedPGError,
    }

    const users = try querier.getUsers();
    switch (users) {
        .user_list => |user_list| {
            defer {
                for (user_list) |user| {
                    user.deinit();
                }
                allocator.free(user_list);
            }
            try expectEqual(2, user_list.len);
            for (1..2) |idx| {
                const user = user_list[idx - 1];
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
        },
        .pgerr => return error.UnexpectedPGError,
    }
}
