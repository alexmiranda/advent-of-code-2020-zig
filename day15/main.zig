const std = @import("std");
const example1 = @embedFile("example1.txt");
const example2 = @embedFile("example2.txt");
const example3 = @embedFile("example3.txt");
const example4 = @embedFile("example4.txt");
const example5 = @embedFile("example5.txt");
const example6 = @embedFile("example6.txt");
const example7 = @embedFile("example7.txt");
const Allocator = std.mem.Allocator;

const turns = 2020;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day15/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    const gpa = init.gpa;
    var buf: [24]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const data = try reader.interface.takeDelimiterExclusive('\n');

    const answer_p1 = try play(gpa, data);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn play(gpa: Allocator, input: []const u8) !u32 {
    var memo: std.AutoHashMapUnmanaged(u32, u16) = .empty;
    defer memo.deinit(gpa);

    var it = std.mem.tokenizeAny(u8, input, ",\n");
    var turn: u16 = 0;
    var number: u32 = undefined;
    while (it.next()) |tok| : (turn += 1) {
        // std.debug.print("turn={d} number={s}\n", .{ turn, tok });
        number = try std.fmt.parseInt(u32, tok, 10);
        try memo.put(gpa, number, turn);
    }

    number = 0;
    while (turn < turns - 1) : (turn += 1) {
        // std.debug.print("turn={d} number={d}\n", .{ turn, number });
        const res = try memo.getOrPut(gpa, number);
        if (res.found_existing) {
            const last_turn = res.value_ptr.*;
            const next = turn - last_turn;
            res.value_ptr.* = turn;
            number = next;
        } else {
            res.value_ptr.* = turn;
            number = 0;
        }
    }

    return number;
}

test "part 1" {
    const gpa = std.testing.allocator;
    try std.testing.expectEqual(436, play(gpa, example1));
    try std.testing.expectEqual(1, play(gpa, example2));
    try std.testing.expectEqual(10, play(gpa, example3));
    try std.testing.expectEqual(27, play(gpa, example4));
    try std.testing.expectEqual(78, play(gpa, example5));
    try std.testing.expectEqual(438, play(gpa, example6));
    try std.testing.expectEqual(1836, play(gpa, example7));
}

test "part 2" {
    return error.SkipZigTest;
}
