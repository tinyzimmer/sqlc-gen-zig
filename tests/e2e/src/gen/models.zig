// Generated with sqlc v1.28.0

const std = @import("std");
const Allocator = std.mem.Allocator;

const pg = @import("pg");

const enums = @import("enums.zig");

pub const User = struct {
    __allocator: Allocator,

    id: i32,
    name: []const u8,
    email: []const u8,
    password: []const u8,
    role: enums.UserRole,
    ip_address: ?pg.Cidr,
    salary: ?pg.Numeric,
    notes: ?[]const u8,
    created_at: i64,
    updated_at: i64,
    archived_at: ?i64,

    pub fn deinit(self: *const User) void {
        self.__allocator.free(self.name);
        self.__allocator.free(self.email);
        self.__allocator.free(self.password);
        if (self.ip_address) |field| {
            self.__allocator.free(field.address);
        }
        if (self.salary) |field| {
            self.__allocator.free(field.digits);
        }
        if (self.notes) |field| {
            self.__allocator.free(field);
        }
    }
};
