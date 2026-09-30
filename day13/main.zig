const std = @import("std");
const example = @embedFile("example.txt");
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day13/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [256]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = try findEarliestBus(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn findEarliestBus(reader: *Reader) !u32 {
    var timestamp: u32 = 0;
    while (reader.takeByte()) |c| {
        switch (c) {
            '\n' => break,
            else => timestamp = timestamp * 10 + c - '0',
        }
    } else |err| switch (err) {
        error.EndOfStream => return 0,
        else => return err,
    }

    var wait: u32 = std.math.maxInt(u32);
    var earliest: u32 = 0;
    var bus: u32 = 0;
    while (reader.takeByte()) |c| {
        switch (c) {
            '0'...'9' => bus = bus * 10 + c - '0',
            'x' => {
                _ = try reader.discard(.limited(1));
                bus = 0;
            },
            ',', '\n' => {
                if (bus == 0) continue;
                const expected_time = (std.math.divCeil(u32, timestamp, bus) catch std.math.maxInt(u32)) *| bus;
                const tentative_wait = expected_time - timestamp;
                // std.debug.print("timestamp={d} bus={d} expected_time={d} tentative_wait={d} wait={d}\n", .{ timestamp, bus, expected_time, tentative_wait, wait });
                if (tentative_wait < wait) {
                    wait = tentative_wait;
                    earliest = bus;
                }
                bus = 0;
            },
            else => std.debug.panic("invalid char: {c}\n", .{c}),
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return earliest * wait;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try findEarliestBus(&reader);
    try std.testing.expectEqual(295, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
