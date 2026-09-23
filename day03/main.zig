const std = @import("std");
const example = @embedFile("example.txt");
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day03/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = try followSlope(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn followSlope(reader: *Reader) !usize {
    const width = (reader.discardDelimiterInclusive('\n') catch 0) - 1;
    var pos: usize = 0;
    var count: usize = 0;
    while (reader.takeDelimiterExclusive('\n') catch null) |row| : (_ = try reader.discard(.limited(1))) {
        if (row.len == 0) break;
        pos = (pos + 3) % width;
        // std.debug.print("{s} (pos={d})\n", .{ row, pos });
        if ('#' == row[pos]) count += 1;
    }
    return count;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try followSlope(&reader);
    try std.testing.expectEqual(7, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
