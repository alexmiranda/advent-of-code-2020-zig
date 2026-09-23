const std = @import("std");
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day05/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = try highestSeatID(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

const SpacePartitioningError = error{
    InvalidLength,
    InvalidRow,
    InvalidCol,
};

fn highestSeatID(reader: *Reader) !u32 {
    var max: u32 = 0;
    while (reader.take(10) catch |err| switch (err) {
        error.EndOfStream => null,
        else => return err,
    }) |locator| : (_ = try reader.discard(.limited(1))) {
        max = @max(max, try seatID(locator));
    }
    return max;
}

fn seatID(locator: []const u8) SpacePartitioningError!u32 {
    if (locator.len != 10) return error.InvalidLength;
    const row = blk: {
        var lo: u8, var hi: u8 = .{ 0, 127 };
        for (locator[0..7]) |p| lo, hi = halve(lo, hi, p) orelse return error.InvalidRow;
        std.debug.assert(lo == hi);
        break :blk @as(u32, lo);
    };
    const col = blk: {
        var lo: u8, var hi: u8 = .{ 0, 7 };
        for (locator[7..]) |p| lo, hi = halve(lo, hi, p) orelse return error.InvalidCol;
        std.debug.assert(lo == hi);
        break :blk @as(u32, lo);
    };
    // std.debug.print("{d}*8+{d}={d}\n", .{ row, col, row * 8 + col });
    return row * 8 + col;
}

inline fn halve(lo: u8, hi: u8, p: u8) ?struct { u8, u8 } {
    return switch (p) {
        'F', 'L' => .{ lo, lo + (std.math.divFloor(u8, hi - lo, 2) catch unreachable) },
        'B', 'R' => .{ lo + (std.math.divCeil(u8, hi - lo, 2) catch unreachable), hi },
        else => null,
    };
}

test "part 1" {
    try std.testing.expectEqual(357, seatID("FBFBBFFRLR"));
    try std.testing.expectEqual(567, seatID("BFFFBBFRRR"));
    try std.testing.expectEqual(119, seatID("FFFBBBFRRR"));
    try std.testing.expectEqual(820, seatID("BBFFBBFRLL"));
}

test "part 2" {
    return error.SkipZigTest;
}
