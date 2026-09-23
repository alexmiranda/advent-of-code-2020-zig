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
    const answer_p1 = try countValidPassports(init.gpa, &reader.interface, false);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try reader.seekTo(0);
    const answer_p2 = try countValidPassports(init.gpa, &reader.interface, true);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn countValidPassports(gpa: Allocator, reader: *Reader, comptime validate: bool) !usize {
    var list: std.Io.Writer.Allocating = try .initCapacity(gpa, 128);
    defer list.deinit();

    var count: usize = 0;
    var writer = list.writer;
    outer: while (reader.streamDelimiter(&writer, '\n') catch null) |_| {
        defer {
            _ = writer.consumeAll();
            list.clearRetainingCapacity();
        }

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
            const key, const val = .{ tok[0..3], tok[4..] };
            if (std.mem.eql(u8, "cid", key)) continue;
            if (validate) {
                if (std.mem.eql(u8, "byr", key)) {
                    const byr = std.fmt.parseInt(u16, val, 10) catch continue :outer;
                    if (byr < 1920 or byr > 2002) continue :outer;
                } else if (std.mem.eql(u8, "iyr", key)) {
                    const iyr = std.fmt.parseInt(u16, val, 10) catch continue :outer;
                    if (iyr < 2010 or iyr > 2020) continue :outer;
                } else if (std.mem.eql(u8, "eyr", key)) {
                    const eyr = std.fmt.parseInt(u16, val, 10) catch continue :outer;
                    if (eyr < 2020 or eyr > 2030) continue :outer;
                } else if (std.mem.eql(u8, "hgt", key)) {
                    const hgt = std.fmt.parseInt(u16, val[0 .. val.len - 2], 10) catch continue :outer;
                    if (std.mem.endsWith(u8, val, "cm")) {
                        if (hgt < 150 or hgt > 193) continue :outer;
                    } else if (std.mem.endsWith(u8, val, "in")) {
                        if (hgt < 59 or hgt > 76) continue :outer;
                    } else continue :outer;
                } else if (std.mem.eql(u8, "hcl", key)) {
                    if (val[0] != '#' or val.len != 7) continue :outer;
                    for (val[1..]) |c| if (std.mem.indexOfScalar(u8, "0123456789abcdef", c) == null) continue :outer;
                } else if (std.mem.eql(u8, "ecl", key)) {
                    inline for (.{ "amb", "blu", "brn", "gry", "grn", "hzl", "oth" }) |ecl| {
                        if (std.mem.eql(u8, ecl, val)) break;
                    } else continue :outer;
                } else if (std.mem.eql(u8, "pid", key)) {
                    if (val.len != 9) continue :outer;
                    for (val) |c| switch (c) {
                        '0'...'9' => {},
                        else => continue :outer,
                    };
                }
            }
            flag <<= 1;
            flag |= 1;
        }

        if (@popCount(flag) >= 7) count += 1;
        // std.debug.print("{s} (len={d} flag={b:0>8} pop={d} count={d})\n", .{ writer.buffered(), writer.end, flag, @popCount(flag), count });
    }
    return count;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try countValidPassports(std.testing.allocator, &reader, false);
    try std.testing.expectEqual(2, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    const answer = try countValidPassports(std.testing.allocator, &reader, true);
    try std.testing.expectEqual(2, answer);
}
