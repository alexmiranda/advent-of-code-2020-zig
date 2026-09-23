const std = @import("std");
const example = @embedFile("example.txt");
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day06/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = try countAnsweredQuestions(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try reader.seekTo(0);
    const answer_p2 = try countAnsweredQuestionsGroup(&reader.interface);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn countAnsweredQuestions(reader: *Reader) !usize {
    var bitset: std.bit_set.StaticBitSet(26) = .empty;
    var sum: usize, var last: u8 = .{ 0, 0 };
    return while (reader.takeByte() catch |err| switch (err) {
        error.EndOfStream => null,
        else => return err,
    }) |c| {
        // std.debug.print("{c}", .{c});
        sw: switch (c) {
            '\n' => {
                if (last != '\n') break :sw;
                sum += bitset.count();
                bitset = .empty;
                // std.debug.print("sum = {d}\n", .{sum});
            },
            'a'...'z' => bitset.set(c - 'a'),
            else => unreachable,
        }
        last = c;
    } else sum;
}

fn countAnsweredQuestionsGroup(reader: *Reader) !usize {
    var group: std.bit_set.StaticBitSet(26) = .full;
    var bitset: std.bit_set.StaticBitSet(26) = .empty;
    var sum: usize, var last: u8 = .{ 0, 0 };
    return while (reader.takeByte() catch |err| switch (err) {
        error.EndOfStream => null,
        else => return err,
    }) |c| {
        // std.debug.print("{c}", .{c});
        sw: switch (c) {
            '\n' => {
                if (last == '\n') {
                    sum += group.count();
                    group = .full;
                    // std.debug.print("sum = {d}\n", .{sum});
                    break :sw;
                }
                group.setIntersection(bitset);
                bitset = .empty;
            },
            'a'...'z' => bitset.set(c - 'a'),
            else => unreachable,
        }
        last = c;
    } else sum;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try countAnsweredQuestions(&reader);
    try std.testing.expectEqual(11, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    const answer = try countAnsweredQuestionsGroup(&reader);
    try std.testing.expectEqual(6, answer);
}
