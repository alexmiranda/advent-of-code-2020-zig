const std = @import("std");
const example = @embedFile("example.txt");
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day12/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = try navigate(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try reader.seekTo(0);
    const answer_p2 = try navigateCorrected(&reader.interface);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn navigate(reader: *Reader) !u32 {
    const dirs = [_]u8{ 'E', 'S', 'W', 'N' };
    var face: i16 = 0;
    var x: i16, var y: i16 = .{ 0, 0 };
    while (reader.takeDelimiterInclusive('\n')) |instruction| {
        if (instruction.len <= 1) break;
        const unit = try std.fmt.parseInt(i16, instruction[1 .. instruction.len - 1], 10);
        sw: switch (instruction[0]) {
            'E' => x += unit,
            'S' => y -= unit,
            'W' => x -= unit,
            'N' => y += unit,
            'L' => face = @mod(face - @divExact(unit, 90), 4),
            'R' => face = @mod(face + @divExact(unit, 90), 4),
            'F' => continue :sw dirs[@intCast(face)],
            else => {},
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return @abs(x) + @abs(y);
}

fn navigateCorrected(reader: *Reader) !u32 {
    const Point = struct {
        x: i32,
        y: i32,
    };
    var ship: Point = .{ .x = 0, .y = 0 };
    var waypoint: Point = .{ .x = 10, .y = 1 };
    while (reader.takeDelimiterInclusive('\n')) |instruction| {
        if (instruction.len <= 1) break;
        var unit = try std.fmt.parseInt(i32, instruction[1 .. instruction.len - 1], 10);
        sw: switch (instruction[0]) {
            'E' => waypoint.x += unit,
            'S' => waypoint.y -= unit,
            'W' => waypoint.x -= unit,
            'N' => waypoint.y += unit,
            'L' => waypoint = switch (unit) {
                90 => Point{ .x = -waypoint.y, .y = waypoint.x },
                180 => Point{ .x = -waypoint.x, .y = -waypoint.y },
                270 => Point{ .x = waypoint.y, .y = -waypoint.x },
                else => unreachable,
            },
            'R' => {
                unit = @mod(360 - unit, 360);
                continue :sw 'L';
            },
            'F' => {
                ship.x += unit * waypoint.x;
                ship.y += unit * waypoint.y;
            },
            else => unreachable,
        }
        // std.debug.print("{s} ship: ({d}, {d}) waypoint: ({d}, {d})\n", .{ instruction[0 .. instruction.len - 1], ship.x, ship.y, waypoint.x, waypoint.y });
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return @abs(ship.x) + @abs(ship.y);
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try navigate(&reader);
    try std.testing.expectEqual(25, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    const answer = try navigateCorrected(&reader);
    try std.testing.expectEqual(286, answer);
}
