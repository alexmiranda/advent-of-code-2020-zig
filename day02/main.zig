const std = @import("std");
const example = @embedFile("example.txt");
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day02/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = countValidPasswords(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try reader.seekTo(0);
    const answer_p2 = countValidPasswordsRevised(&reader.interface);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn countValidPasswords(reader: *Reader) usize {
    var count: usize = 0;
    var tok: []u8 = undefined;
    while (reader.peekByte() catch null) |ch| {
        if (ch == '\n') break;
        tok = reader.takeDelimiterExclusive('-') catch unreachable;
        _ = reader.discard(.limited(1)) catch unreachable;
        const min = std.fmt.parseInt(u8, tok, 10) catch unreachable;

        tok = reader.takeDelimiterExclusive(' ') catch unreachable;
        _ = reader.discard(.limited(1)) catch unreachable;
        const max = std.fmt.parseInt(u8, tok, 10) catch unreachable;

        const letter = reader.takeByte() catch unreachable;
        _ = reader.discard(.limited(2)) catch unreachable;

        tok = reader.takeDelimiterExclusive('\n') catch unreachable;
        _ = reader.discard(.limited(1)) catch unreachable;

        // std.debug.print("{d}-{d} {c}: {s}\n", .{ min, max, letter, tok });

        const actual = std.mem.countScalar(u8, tok, letter);
        if (actual >= min and actual <= max) count += 1;
    }
    return count;
}

fn countValidPasswordsRevised(reader: *Reader) usize {
    var count: usize = 0;
    var tok: []u8 = undefined;
    while (reader.peekByte() catch null) |ch| {
        if (ch == '\n') break;
        tok = reader.takeDelimiterExclusive('-') catch unreachable;
        _ = reader.discard(.limited(1)) catch unreachable;
        const lhs = std.fmt.parseInt(u8, tok, 10) catch unreachable;

        tok = reader.takeDelimiterExclusive(' ') catch unreachable;
        _ = reader.discard(.limited(1)) catch unreachable;
        const rhs = std.fmt.parseInt(u8, tok, 10) catch unreachable;

        const letter = reader.takeByte() catch unreachable;
        _ = reader.discard(.limited(2)) catch unreachable;

        tok = reader.takeDelimiterExclusive('\n') catch unreachable;
        _ = reader.discard(.limited(1)) catch unreachable;

        // std.debug.print("{d}-{d} {c}: {s}\n", .{ lhs, rhs, letter, tok });
        if (((tok.len >= lhs and tok[lhs - 1] == letter) or (tok.len >= rhs and tok[rhs - 1] == letter)) and tok[lhs - 1] != tok[rhs - 1]) count += 1;
    }
    return count;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = countValidPasswords(&reader);
    try std.testing.expectEqual(2, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    const answer = countValidPasswordsRevised(&reader);
    try std.testing.expectEqual(1, answer);
}
