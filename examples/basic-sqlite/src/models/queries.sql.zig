// Generated with sqlc v1.28.0
 
const std = @import("std");
const Allocator = std.mem.Allocator;

const zqlite = @import("zqlite");
const models = @import("models.zig");

pub const ConnQuerier = Querier(zqlite.Conn);
pub const PoolQuerier = Querier(*zqlite.Pool);

pub fn Querier(comptime T: type) type {
    return struct{
        const Self = @This();
        
        allocator: Allocator,
        conn: T,

        pub fn init(allocator: Allocator, conn: T) Self {
            return .{ .allocator = allocator, .conn = conn };
        }
        
        const create_user_sql = 
            \\INSERT INTO users (
            \\    name, 
            \\    email, 
            \\    password, 
            \\    salary
            \\) VALUES (
            \\    ?, ?, ?, ?
            \\)
        ;

        pub const CreateUserParams = struct {
            name: []const u8,
            email: []const u8,
            password: []const u8,
            salary: ?f64 = null,
        };

        pub fn createUser(self: Self, create_user_params: CreateUserParams) !void {
            var conn: zqlite.Conn = blk: {
                if (T == *zqlite.Pool) {
                    break :blk self.conn.acquire();
                } else {
                    break :blk self.conn;
                }
            };
            defer if (T == *zqlite.Pool) {
                conn.release();
            };

            try conn.exec(create_user_sql, .{ 
                create_user_params.name,
                create_user_params.email,
                create_user_params.password,
                create_user_params.salary,
            });
        }

        const get_user_sql = 
            \\SELECT id, name, email, password, salary, notes, created_at, updated_at, archived_at FROM users
            \\WHERE id = ? LIMIT 1
        ;

        pub fn getUser(self: Self, id: i64) !models.User {
            const allocator = self.allocator;
            var conn: zqlite.Conn = blk: {
                if (T == *zqlite.Pool) {
                    break :blk self.conn.acquire();
                } else {
                    break :blk self.conn;
                }
            };
            defer if (T == *zqlite.Pool) {
                conn.release();
            };

            var rows = try conn.rows(get_user_sql, .{ 
                id,
            });
            defer rows.deinit();
            if (rows.err) |err| {
                return err;
            }
            const row = rows.next() orelse return error.NotFound;

            const row_id = row.int(0);
            const row_name = try allocator.dupe(u8, row.text(1));
            errdefer allocator.free(row_name);
            const row_email = try allocator.dupe(u8, row.text(2));
            errdefer allocator.free(row_email);
            const row_password = try allocator.dupe(u8, row.text(3));
            errdefer allocator.free(row_password);
            const row_salary = row.nullableFloat(4);

            const maybe_notes = row.nullableText(5);
            const row_notes: ?[]const u8 = blk: {
                if (maybe_notes) |field| {
                    break :blk try allocator.dupe(u8, field);
                }
                break :blk null;
            };
            errdefer if (row_notes) |field| {
                allocator.free(field);
            };
            const row_created_at = row.int(6);
            const row_updated_at = row.int(7);
            const row_archived_at = row.nullableInt(8);

            return .{
                .__allocator = allocator,
                .id = row_id,
                .name = row_name,
                .email = row_email,
                .password = row_password,
                .salary = row_salary,
                .notes = row_notes,
                .created_at = row_created_at,
                .updated_at = row_updated_at,
                .archived_at = row_archived_at,
            };
        }

        const get_user_by_email_sql = 
            \\SELECT id, name, email, password, salary, notes, created_at, updated_at, archived_at FROM users
            \\WHERE email = ? LIMIT 1
        ;

        pub fn getUserByEmail(self: Self, email: []const u8) !models.User {
            const allocator = self.allocator;
            var conn: zqlite.Conn = blk: {
                if (T == *zqlite.Pool) {
                    break :blk self.conn.acquire();
                } else {
                    break :blk self.conn;
                }
            };
            defer if (T == *zqlite.Pool) {
                conn.release();
            };

            var rows = try conn.rows(get_user_by_email_sql, .{ 
                email,
            });
            defer rows.deinit();
            if (rows.err) |err| {
                return err;
            }
            const row = rows.next() orelse return error.NotFound;

            const row_id = row.int(0);
            const row_name = try allocator.dupe(u8, row.text(1));
            errdefer allocator.free(row_name);
            const row_email = try allocator.dupe(u8, row.text(2));
            errdefer allocator.free(row_email);
            const row_password = try allocator.dupe(u8, row.text(3));
            errdefer allocator.free(row_password);
            const row_salary = row.nullableFloat(4);

            const maybe_notes = row.nullableText(5);
            const row_notes: ?[]const u8 = blk: {
                if (maybe_notes) |field| {
                    break :blk try allocator.dupe(u8, field);
                }
                break :blk null;
            };
            errdefer if (row_notes) |field| {
                allocator.free(field);
            };
            const row_created_at = row.int(6);
            const row_updated_at = row.int(7);
            const row_archived_at = row.nullableInt(8);

            return .{
                .__allocator = allocator,
                .id = row_id,
                .name = row_name,
                .email = row_email,
                .password = row_password,
                .salary = row_salary,
                .notes = row_notes,
                .created_at = row_created_at,
                .updated_at = row_updated_at,
                .archived_at = row_archived_at,
            };
        }

        const get_user_emails_sql = 
            \\SELECT id, email FROM users
            \\ORDER BY id ASC
        ;

        pub const GetUserEmailsRow = struct {
            __allocator: Allocator,

            id: i64,
            email: []const u8,

            pub fn deinit(self: *const GetUserEmailsRow) void {
                self.__allocator.free(self.email);
            }
        };

        pub fn getUserEmails(self: Self) ![]GetUserEmailsRow {
            const allocator = self.allocator;
            var conn: zqlite.Conn = blk: {
                if (T == *zqlite.Pool) {
                    break :blk self.conn.acquire();
                } else {
                    break :blk self.conn;
                }
            };
            defer if (T == *zqlite.Pool) {
                conn.release();
            };

            var rows = try conn.rows(get_user_emails_sql, .{});
            defer rows.deinit();
            var out = std.ArrayList(GetUserEmailsRow).init(allocator);
            defer out.deinit();
            while (rows.next()) |row| {
                const row_id = row.int(0);
                const row_email = try allocator.dupe(u8, row.text(1));
                errdefer allocator.free(row_email);
                try out.append(.{
                    .__allocator = allocator,
                    .id = row_id,
                    .email = row_email,
                });
            }
            if (rows.err) |err| {
                return err;
            }

            return try out.toOwnedSlice();
        }

        const get_user_i_ds_by_salary_range_sql = 
            \\SELECT id FROM users
            \\WHERE salary >= ? AND salary <= ?
            \\ORDER BY id ASC
        ;

        pub fn getUserIDsBySalaryRange(self: Self, salary_1: f64, salary_2: f64) ![]i64 {
            const allocator = self.allocator;
            var conn: zqlite.Conn = blk: {
                if (T == *zqlite.Pool) {
                    break :blk self.conn.acquire();
                } else {
                    break :blk self.conn;
                }
            };
            defer if (T == *zqlite.Pool) {
                conn.release();
            };

            var rows = try conn.rows(get_user_i_ds_by_salary_range_sql, .{ 
                salary_1,
                salary_2,
            });
            defer rows.deinit();
            var out = std.ArrayList(i64).init(allocator);
            defer out.deinit();
            while (rows.next()) |row| {
                const row_id = row.int(0);
                try out.append(row_id);
            }
            if (rows.err) |err| {
                return err;
            }

            return try out.toOwnedSlice();
        }

        const get_users_sql = 
            \\SELECT id, name, email, password, salary, notes, created_at, updated_at, archived_at FROM users
            \\ORDER BY id ASC
        ;

        pub fn getUsers(self: Self) ![]models.User {
            const allocator = self.allocator;
            var conn: zqlite.Conn = blk: {
                if (T == *zqlite.Pool) {
                    break :blk self.conn.acquire();
                } else {
                    break :blk self.conn;
                }
            };
            defer if (T == *zqlite.Pool) {
                conn.release();
            };

            var rows = try conn.rows(get_users_sql, .{});
            defer rows.deinit();
            var out = std.ArrayList(models.User).init(allocator);
            defer out.deinit();
            while (rows.next()) |row| {
                const row_id = row.int(0);
                const row_name = try allocator.dupe(u8, row.text(1));
                errdefer allocator.free(row_name);
                const row_email = try allocator.dupe(u8, row.text(2));
                errdefer allocator.free(row_email);
                const row_password = try allocator.dupe(u8, row.text(3));
                errdefer allocator.free(row_password);
                const row_salary = row.nullableFloat(4);

                const maybe_notes = row.nullableText(5);
                const row_notes: ?[]const u8 = blk: {
                    if (maybe_notes) |field| {
                        break :blk try allocator.dupe(u8, field);
                    }
                    break :blk null;
                };
                errdefer if (row_notes) |field| {
                    allocator.free(field);
                };
                const row_created_at = row.int(6);
                const row_updated_at = row.int(7);
                const row_archived_at = row.nullableInt(8);
                try out.append(.{
                    .__allocator = allocator,
                    .id = row_id,
                    .name = row_name,
                    .email = row_email,
                    .password = row_password,
                    .salary = row_salary,
                    .notes = row_notes,
                    .created_at = row_created_at,
                    .updated_at = row_updated_at,
                    .archived_at = row_archived_at,
                });
            }
            if (rows.err) |err| {
                return err;
            }

            return try out.toOwnedSlice();
        }

    };
}