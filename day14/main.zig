const std = @import("std");
const example = @embedFile("example.txt");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day14/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    const gpa = init.gpa;
    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = try solve(gpa, &reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn solve(gpa: Allocator, reader: *Reader) !u64 {
    var mem: std.AutoHashMapUnmanaged(u16, u36) = .empty;
    defer mem.deinit(gpa);

    var on: std.bit_set.Integer(36) = undefined;
    var off: std.bit_set.Integer(36) = undefined;
    while (reader.take(4)) |prefix| : (_ = try reader.discard(.limited(1))) {
        if (std.mem.eql(u8, "mask", prefix)) {
            _ = try reader.discard(.limited(3)); // spaces and equal
            on = .empty;
            off = .full;
            const mask = try reader.take(36);
            for (mask, 1..) |c, i| {
                switch (c) {
                    '0' => off.unset(mask.len - i),
                    '1' => on.set(mask.len - i),
                    'X' => {},
                    else => std.debug.panic("invalid char: {c}", .{c}),
                }
            }
        } else if (std.mem.eql(u8, "mem[", prefix)) {
            var tok = try reader.takeDelimiterExclusive(']');
            const address = try std.fmt.parseInt(u16, tok, 10);
            _ = try reader.discard(.limited(4)); // ], spaces and equal
            tok = try reader.takeDelimiterExclusive('\n');
            var value = try std.fmt.parseInt(u36, tok, 10);
            value |= on.mask;
            value &= off.mask;
            try mem.put(gpa, address, value);
        } else {
            @panic("malformed input!");
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    var it = mem.valueIterator();
    var sum: u64 = 0;
    while (it.next()) |value| sum += value.*;

    return sum;
}

test "part 1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example);
    const answer = try solve(gpa, &reader);
    try std.testing.expectEqual(165, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
