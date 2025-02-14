// Generated with sqlc v1.28.0
 
const std = @import("std");
const Allocator = std.mem.Allocator;


pub const User = struct {
    __allocator: Allocator,

    id: i64,
    name: []const u8,
    email: []const u8,
    password: []const u8,
    salary: ?f64,
    notes: ?[]const u8,
    created_at: i64,
    updated_at: i64,
    archived_at: ?i64,

    pub fn deinit(self: *const User) void {
        self.__allocator.free(self.name);
        self.__allocator.free(self.email);
        self.__allocator.free(self.password);
        if (self.notes) |field| {
            self.__allocator.free(field);
        }
    }
};
