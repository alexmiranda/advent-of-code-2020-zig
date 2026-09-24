const std = @import("std");
const example1 = @embedFile("example1.txt");
const example2 = @embedFile("example2.txt");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

fn lessThan(_: void, a: u16, b: u16) std.math.Order {
    return std.math.order(a, b);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day10/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);

    const gpa = init.gpa;
    const answer = try findChain(gpa, &reader.interface);

    try stdout.print("Part 1: {d}\n", .{answer});
    try stdout.flush();
}

fn findChain(gpa: Allocator, reader: *Reader) !u16 {
    var heap: std.PriorityQueue(u16, void, lessThan) = .empty;
    defer heap.deinit(gpa);

    while (reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
        error.EndOfStream => null,
        else => return err,
    }) |tok| : (_ = try reader.discard(.limited(1))) {
        if (tok.len == 0) break;
        // std.debug.print("{s}\n", .{tok});
        const jolt = try std.fmt.parseInt(u16, tok, 10);
        try heap.push(gpa, jolt);
    }

    var output: u16 = 0;
    var delta: struct { u16, u16 } = .{ 0, 1 };
    while (heap.pop()) |jolt| : (output = jolt) {
        switch (jolt - output) {
            0, 2 => {},
            1 => delta.@"0" += 1,
            3 => delta.@"1" += 1,
            else => break,
        }
    }
    return delta.@"0" * delta.@"1";
}

test "part 1 example1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example1);
    const answer = try findChain(gpa, &reader);
    try std.testing.expectEqual(35, answer);
}

test "part 1 example2" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example2);
    const answer = try findChain(gpa, &reader);
    try std.testing.expectEqual(220, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
