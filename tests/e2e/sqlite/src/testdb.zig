const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;

const zqlite = @import("zqlite");

const schema = @embedFile("schema/schema.sql");

const TestDB = @This();

allocator: Allocator,
tmp_dir: std.testing.TmpDir,
db_path: []const u8,
pool: *zqlite.Pool,

pub fn init(allocator: Allocator) !TestDB {
    const tmp_dir = std.testing.tmpDir(.{});
    const absolute_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(absolute_path);

    const db_path = try std.fs.path.join(allocator, &.{ absolute_path, "zqlite.sqlite" });
    var pool = try zqlite.Pool.init(allocator, .{
        .size = 5,
        .path = @ptrCast(db_path),
        .flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode,
        .on_connection = null,
        .on_first_connection = null,
    });
    const c = pool.acquire();
    defer c.release();

    try c.exec(schema, .{});

    return .{
        .allocator = allocator,
        .tmp_dir = tmp_dir,
        .db_path = db_path,
        .pool = pool,
    };
}

pub fn deinit(self: *TestDB) void {
    self.pool.deinit();
    self.allocator.free(self.db_path);
    self.tmp_dir.cleanup();
}
