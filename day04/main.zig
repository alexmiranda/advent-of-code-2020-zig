const std = @import("std");
const example = @embedFile("example.txt");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day04/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = try countValidPassports(init.gpa, &reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn countValidPassports(gpa: Allocator, reader: *Reader) !usize {
    var list: std.Io.Writer.Allocating = try .initCapacity(gpa, 128);
    defer list.deinit();

    var count: usize = 0;
    var writer = list.writer;
    while (reader.streamDelimiter(&writer, '\n') catch null) |_| {
        // std.debug.print("==> {s} read: {d} peek: {d}\n", .{ writer.buffer[0..read], read, (reader.peekByte() catch 0) });
        _ = try reader.discard(.limited(1));
        while ((try reader.peekByte()) != '\n') {
            _ = try writer.writeByte(' ');
            if (reader.streamDelimiter(&writer, '\n') catch null) |_| {
                // std.debug.print("==> read: {d} peek: {d}\n", .{ rr, (reader.peekByte() catch 0) });
                _ = try reader.discard(.limited(1));
            }
        } else _ = try reader.discard(.limited(1));

        var it = std.mem.splitScalar(u8, writer.buffered(), ' ');
        var flag: u8 = 0;
        while (it.next()) |tok| {
            if (std.mem.eql(u8, "cid", tok[0..3])) continue;
            flag <<= 1;
            flag |= 1;
        }

        if (@popCount(flag) >= 7) count += 1;
        // std.debug.print("{s} (len={d} flag={b:0>8} pop={d} count={d})\n", .{ writer.buffered(), writer.end, flag, @popCount(flag), count });

        _ = writer.consumeAll();
        list.clearRetainingCapacity();
    }
    return count;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try countValidPassports(std.testing.allocator, &reader);
    try std.testing.expectEqual(2, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
