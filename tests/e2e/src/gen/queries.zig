// Generated with sqlc v1.28.0

const std = @import("std");
const Allocator = std.mem.Allocator;

const pg = @import("pg");

const models = @import("models.zig");
const enums = @import("enums.zig");

pub const ConnQuerier = Querier(*pg.Conn);
pub const PoolQuerier = Querier(*pg.Pool);

pub fn Querier(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        conn: T,

        pub fn init(allocator: Allocator, conn: T) Self {
            return .{ .allocator = allocator, .conn = conn };
        }
        
        pub const create_user_sql = 
            \\INSERT INTO "user" (
            \\    name, 
            \\    email, 
            \\    password, 
            \\    role, 
            \\    ip_address,
            \\    salary,
            \\    created_at,
            \\    updated_at
            \\) VALUES (
            \\    $1, $2, $3, $4, $5, $6, NOW(), NOW()
            \\)
        ;

        pub const CreateUserParams = struct {
            name: []const u8,
            email: []const u8,
            password: []const u8,
            role: enums.UserRole,
            ip_address: ?[]const u8 = null,
            salary: ?f64 = null,
        };

        pub fn createUser(self: Self, create_user_params: CreateUserParams) !void {
            _ = try self.conn.exec(create_user_sql, .{
                create_user_params.name,
                create_user_params.email,
                create_user_params.password,
                @tagName(create_user_params.role),
                create_user_params.ip_address,
                create_user_params.salary, 
            });
        }

        pub const get_user_sql = 
            \\SELECT id, name, email, password, role, ip_address, salary, notes, created_at, updated_at, archived_at FROM "user"
            \\WHERE id = $1 LIMIT 1
        ;

        pub fn getUser(self: Self, id: i32) !models.User {
            const result = try self.conn.query(get_user_sql, .{
                id, 
            });
            defer result.deinit();
            const row = try result.next() orelse return error.NotFound;

            const row_id = row.get(i32, 0);
            const row_name = try self.allocator.dupe(u8, row.get([]const u8, 1));
            errdefer self.allocator.free(row_name);
            const row_email = try self.allocator.dupe(u8, row.get([]const u8, 2));
            errdefer self.allocator.free(row_email);
            const row_password = try self.allocator.dupe(u8, row.get([]const u8, 3));
            errdefer self.allocator.free(row_password);
            const row_role = std.meta.stringToEnum(enums.UserRole, row.get([]const u8, 4)) orelse unreachable;
            const ip_address_cidr = row.get(?pg.Cidr, 5);
            const row_ip_address: ?pg.Cidr = blk: {
                if (ip_address_cidr) |cidr| {
                    break :blk pg.Cidr{
                        .address = try self.allocator.dupe(u8, cidr.address),
                        .netmask = cidr.netmask,
                        .family = cidr.family,
                    };
                }
                break :blk null;
            };
            errdefer {
                if (row_ip_address) |cidr| {
                    self.allocator.free(cidr.address);
                }
            }
            const salary_numeric = row.get(?pg.Numeric, 6);
            const row_salary: ?pg.Numeric = blk: {
                if (salary_numeric) |numeric| {
                    break :blk pg.Numeric{
                        .number_of_digits = numeric.number_of_digits,
                        .weight = numeric.weight,
                        .sign = numeric.sign,
                        .scale = numeric.scale,
                        .digits = try self.allocator.dupe(u8, numeric.digits),
                    };
                }
                break :blk null;
            };
            errdefer {
                if (row_salary) |numeric| {
                    self.allocator.free(numeric.digits);
                }
            }
            const maybe_notes = row.get(?[]const u8, 7);
            const row_notes: ?[]const u8 = blk: {
                if (maybe_notes) |field| {
                    break :blk try self.allocator.dupe(u8, field);
                }
                break :blk null;
            };
            errdefer {
                if (row_notes) |field| {
                    self.allocator.free(field);
                }
            }
            const row_created_at = row.get(i64, 8);
            const row_updated_at = row.get(i64, 9);
            const row_archived_at = row.get(?i64, 10);

            return .{
                .__allocator = self.allocator,
                .id = row_id,
                .name = row_name,
                .email = row_email,
                .password = row_password,
                .role = row_role,
                .ip_address = row_ip_address,
                .salary = row_salary,
                .notes = row_notes,
                .created_at = row_created_at,
                .updated_at = row_updated_at,
                .archived_at = row_archived_at,
            };
        }

        pub const get_user_id_by_email_sql = 
            \\SELECT id FROM "user"
            \\WHERE email = $1 LIMIT 1
        ;

        pub fn getUserIDByEmail(self: Self, email: []const u8) !i32 {
            const result = try self.conn.query(get_user_id_by_email_sql, .{
                email, 
            });
            defer result.deinit();
            const row = try result.next() orelse return error.NotFound;

            const row_id = row.get(i32, 0);
            return row_id;
        }

        pub const get_user_i_ds_by_ip_address_sql = 
            \\SELECT id FROM "user"
            \\WHERE ip_address = $1
        ;

        pub fn getUserIDsByIPAddress(self: Self, ip_address: []const u8) ![]i32 {
            const result = try self.conn.query(get_user_i_ds_by_ip_address_sql, .{
                ip_address, 
            });
            defer result.deinit();
            var out = std.ArrayList(i32).init(self.allocator);
            defer out.deinit();
            while (try result.next()) |row| {
                const row_id = row.get(i32, 0);try out.append(row_id);
            }
            return try out.toOwnedSlice();
        }

        pub const get_user_i_ds_by_role_sql = 
            \\SELECT id FROM "user"
            \\WHERE role = $1
        ;

        pub fn getUserIDsByRole(self: Self, role: enums.UserRole) ![]i32 {
            const result = try self.conn.query(get_user_i_ds_by_role_sql, .{
                @tagName(role), 
            });
            defer result.deinit();
            var out = std.ArrayList(i32).init(self.allocator);
            defer out.deinit();
            while (try result.next()) |row| {
                const row_id = row.get(i32, 0);try out.append(row_id);
            }
            return try out.toOwnedSlice();
        }

        pub const get_user_i_ds_by_salary_range_sql = 
            \\SELECT id FROM "user"
            \\WHERE salary >= $1 AND salary <= $2
        ;

        pub fn getUserIDsBySalaryRange(self: Self, salary_1: f64, salary_2: f64) ![]i32 {
            const result = try self.conn.query(get_user_i_ds_by_salary_range_sql, .{
                salary_1,
                salary_2, 
            });
            defer result.deinit();
            var out = std.ArrayList(i32).init(self.allocator);
            defer out.deinit();
            while (try result.next()) |row| {
                const row_id = row.get(i32, 0);try out.append(row_id);
            }
            return try out.toOwnedSlice();
        }

        pub const get_users_sql = 
            \\SELECT id, name, email, password, role, ip_address, salary, notes, created_at, updated_at, archived_at FROM "user"
            \\ORDER BY id ASC
        ;

        pub fn getUsers(self: Self) ![]models.User {
            const result = try self.conn.query(get_users_sql, .{});
            defer result.deinit();
            var out = std.ArrayList(models.User).init(self.allocator);
            defer out.deinit();
            while (try result.next()) |row| {
                const row_id = row.get(i32, 0);
                const row_name = try self.allocator.dupe(u8, row.get([]const u8, 1));
                errdefer self.allocator.free(row_name);
                const row_email = try self.allocator.dupe(u8, row.get([]const u8, 2));
                errdefer self.allocator.free(row_email);
                const row_password = try self.allocator.dupe(u8, row.get([]const u8, 3));
                errdefer self.allocator.free(row_password);
                const row_role = std.meta.stringToEnum(enums.UserRole, row.get([]const u8, 4)) orelse unreachable;
                const ip_address_cidr = row.get(?pg.Cidr, 5);
                const row_ip_address: ?pg.Cidr = blk: {
                    if (ip_address_cidr) |cidr| {
                        break :blk pg.Cidr{
                            .address = try self.allocator.dupe(u8, cidr.address),
                            .netmask = cidr.netmask,
                            .family = cidr.family,
                        };
                    }
                    break :blk null;
                };
                errdefer {
                    if (row_ip_address) |cidr| {
                        self.allocator.free(cidr.address);
                    }
                }
                const salary_numeric = row.get(?pg.Numeric, 6);
                const row_salary: ?pg.Numeric = blk: {
                    if (salary_numeric) |numeric| {
                        break :blk pg.Numeric{
                            .number_of_digits = numeric.number_of_digits,
                            .weight = numeric.weight,
                            .sign = numeric.sign,
                            .scale = numeric.scale,
                            .digits = try self.allocator.dupe(u8, numeric.digits),
                        };
                    }
                    break :blk null;
                };
                errdefer {
                    if (row_salary) |numeric| {
                        self.allocator.free(numeric.digits);
                    }
                }
                const maybe_notes = row.get(?[]const u8, 7);
                const row_notes: ?[]const u8 = blk: {
                    if (maybe_notes) |field| {
                        break :blk try self.allocator.dupe(u8, field);
                    }
                    break :blk null;
                };
                errdefer {
                    if (row_notes) |field| {
                        self.allocator.free(field);
                    }
                }
                const row_created_at = row.get(i64, 8);
                const row_updated_at = row.get(i64, 9);
                const row_archived_at = row.get(?i64, 10);
                try out.append(.{
                    .__allocator = self.allocator,
                    .id = row_id,
                    .name = row_name,
                    .email = row_email,
                    .password = row_password,
                    .role = row_role,
                    .ip_address = row_ip_address,
                    .salary = row_salary,
                    .notes = row_notes,
                    .created_at = row_created_at,
                    .updated_at = row_updated_at,
                    .archived_at = row_archived_at,
                });
            }
            return try out.toOwnedSlice();
        }

    };
}
