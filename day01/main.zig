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
    const answer_p1 = find(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn find(reader: *Reader) u32 {
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

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = find(&reader);
    try std.testing.expectEqual(514579, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
