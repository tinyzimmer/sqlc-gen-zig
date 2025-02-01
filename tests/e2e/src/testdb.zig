const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;

const pg = @import("pg");

const schema = @embedFile("schema/schema.sql");

const TestDB = @This();

allocator: Allocator,
db_name: []const u8,
pool: *pg.Pool,

pub fn init(allocator: Allocator) !TestDB {
    var prng = DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
    var rand = prng.random();

    var pool = try pg.Pool.init(allocator, .{ .size = 1, .connect = .{
        .port = 5432,
        .host = "127.0.0.1",
    }, .auth = .{
        .username = "postgres",
        .password = "postgres",
        .database = "postgres",
        .timeout = 10_000,
    } });
    defer pool.deinit();

    var db_name: [16:0]u8 = undefined;
    const chars = "abcdefghijklmnopqrstuvwxyz";
    for (0..16) |idx| {
        db_name[idx] = chars[rand.intRangeLessThan(usize, 0, chars.len)];
    }

    const query = try std.fmt.allocPrint(allocator, "CREATE DATABASE {s}", .{db_name[0..]});
    defer allocator.free(query);
    _ = try pool.exec(query, .{});

    const temp_db_name = try allocator.dupe(u8, db_name[0..]);
    var temp_pool = try pg.Pool.init(allocator, .{ .size = 1, .connect = .{
        .port = 5432,
        .host = "127.0.0.1",
    }, .auth = .{
        .username = "postgres",
        .password = "postgres",
        .database = temp_db_name,
        .timeout = 10_000,
    } });
    _ = try temp_pool.exec(schema, .{});
    return .{
        .allocator = allocator,
        .db_name = temp_db_name,
        .pool = temp_pool,
    };
}

pub fn deinit(self: *TestDB) void {
    self.pool.deinit();
    self.allocator.free(self.db_name);
}
