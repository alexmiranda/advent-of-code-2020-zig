const std = @import("std");
const example = @embedFile("example.txt");
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day01/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = findTwoEntries(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try reader.seekTo(0);
    const answer_p2 = findThreeEntries(&reader.interface);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn findTwoEntries(reader: *Reader) u32 {
    var nums: std.bit_set.StaticBitSet(2020) = .initEmpty();

    var val: u32 = 0;
    while (reader.takeByte()) |ch| {
        switch (ch) {
            '\n' => {
                std.debug.assert(val <= 2020);
                const d: u32 = 2020 - val;
                if (nums.isSet(d)) {
                    return val * d;
                }
                nums.set(val);
                val = 0;
            },
            else => {
                val = (val * 10) + (ch - '0');
            },
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => std.debug.panic("{any}", .{err}),
    }
    unreachable;
}

fn findThreeEntries(reader: *Reader) u64 {
    var nums: std.bit_set.StaticBitSet(2020) = .initEmpty();

    var val: u64 = 0;
    while (reader.takeByte()) |ch| {
        switch (ch) {
            '\n' => {
                std.debug.assert(val <= 2020);
                if (nums.count() >= 2) {
                    const d: u64 = 2020 - val;
                    var it1 = nums.iterator(.{});
                    while (it1.next()) |lhs| {
                        var it2 = nums.iterator(.{});
                        while (it2.next()) |rhs| {
                            // std.debug.print("{d} + {d} + {d} = {d}\n", .{ lhs, rhs, val, lhs + rhs + val });
                            if (lhs != rhs and lhs + rhs == d) {
                                return lhs * rhs * val;
                            }
                        }
                    }
                }
                nums.set(val);
                val = 0;
            },
            else => {
                val = (val * 10) + (ch - '0');
            },
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => std.debug.panic("{any}", .{err}),
    }
    unreachable;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = findTwoEntries(&reader);
    try std.testing.expectEqual(514579, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    const answer = findThreeEntries(&reader);
    try std.testing.expectEqual(241861950, answer);
}
