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

    try reader.seekTo(0);
    const answer_p2 = try findEarliestTimestamp(&reader.interface);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
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

fn findEarliestTimestamp(reader: *Reader) !u64 {
    // the first line doesn't matter anymore
    _ = reader.discardDelimiterInclusive('\n') catch |err| switch (err) {
        error.EndOfStream => return 0,
        else => return err,
    };

    var residue: Residue = .{ .r = 0, .m = 1 };
    var bus: u32 = 0;
    var pos: u32 = 0;
    while (reader.takeByte()) |c| {
        switch (c) {
            '0'...'9' => bus = bus * 10 + c - '0',
            'x' => {
                _ = try reader.discard(.limited(1));
                pos += 1;
            },
            ',', '\n' => {
                residue = try crt(residue, pos, bus + @intFromBool(bus == 0));
                bus = 0;
                pos += 1;
            },
            else => std.debug.panic("invalid char: {c}\n", .{c}),
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return @bitCast(residue.r);
}

const Residue = struct {
    // x ≡ r (mod m), 0 <= r < m
    r: i64,
    m: i64,
};

// merges x ≡ residue.r (mod residue.m) with x ≡ -pos (mod bus):
// the bus at index pos departs at timestamp x + pos
fn crt(residue: Residue, pos: u32, bus: u32) error{NotConsistent}!Residue {
    const p: i64 = pos;
    const b: i64 = bus;
    const r = residue.r;
    const m = residue.m;
    // m ≡ m mod b (mod b) and g | m, so m / g ≡ (m mod b) / g (mod b / g):
    // egcd on the reduced first argument still yields the inverse we want
    const eg = egcd(@truncate(@mod(m, b)), @truncate(b));
    const gcd = eg.gcd;
    const s = eg.s;
    const delta = -p - r;
    if (@rem(delta, gcd) != 0) return error.NotConsistent;
    // r + m * k ≡ -pos (mod b), for k ≡ (-pos - r) / g * s (mod b / g)
    const step = @mod(@divExact(delta, gcd) * s, @divExact(b, gcd));
    return .{
        .r = r + m * step,
        .m = m * @divExact(b, gcd),
    };
}

const EgcdResult = struct {
    gcd: i32,
    // Bézout coefients: a * s + b * t = gcd
    s: i32,
    t: i32,
};

fn egcd(a: i32, b: i32) EgcdResult {
    if (b == 0) {
        return .{ .gcd = a, .s = 1, .t = 0 };
    }

    const next = egcd(b, @mod(a, b));
    return .{
        .gcd = next.gcd,
        .s = next.t,
        .t = next.s - @divFloor(a, b) * next.t,
    };
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try findEarliestBus(&reader);
    try std.testing.expectEqual(295, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    const answer = try findEarliestTimestamp(&reader);
    try std.testing.expectEqual(1068781, answer);
}
