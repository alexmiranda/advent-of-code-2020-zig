const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day18/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    const gpa = init.gpa;
    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const answer_p1 = try doHomework(gpa, &reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn doHomework(gpa: Allocator, reader: *Reader) !u64 {
    var sum: u64 = 0;
    while (reader.takeDelimiterInclusive('\n')) |expr| {
        sum += try eval(gpa, expr);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return sum;
}

fn eval(gpa: Allocator, expr: []const u8) !u64 {
    var operands: std.ArrayList(u64) = .empty;
    defer operands.deinit(gpa);

    var operators: std.ArrayList(u8) = .empty;
    defer operators.deinit(gpa);

    for (expr) |c| {
        // std.debug.print("{c}", .{c});
        sw: switch (c) {
            ' ', '\n' => {},
            '0'...'9' => {
                try operands.append(gpa, c - '0');
                if (operators.items.len > 0) continue :sw ')';
            },
            '+', '*' => |op| try operators.append(gpa, op),
            '(' => {
                try operands.append(gpa, 0);
                try operators.append(gpa, '+');
            },
            ')' => {
                if (operands.items.len < 2) continue;
                const rhs = operands.pop().?;
                const lhs = operands.pop().?;
                switch (operators.pop().?) {
                    '+' => try operands.append(gpa, lhs + rhs),
                    '*' => try operands.append(gpa, lhs * rhs),
                    else => |invalid| continue :sw invalid,
                }
            },
            else => |invalid| std.debug.panic("invalid char: {c}", .{invalid}),
        }
    }

    // std.debug.print("\n", .{});
    return operands.pop() orelse 0;
}

test "part 1" {
    const gpa = std.testing.allocator;
    try std.testing.expectEqual(26, eval(gpa, "2 * 3 + (4 * 5)"));
    try std.testing.expectEqual(437, eval(gpa, "5 + (8 * 3 + 9 + 3 * 4 * 3)"));
    try std.testing.expectEqual(12240, eval(gpa, "5 * 9 * (7 * 3 * 3 + 9 * 3 + (8 + 6 * 4))"));
    try std.testing.expectEqual(13632, eval(gpa, "((2 + 4 * 9) * (6 + 9 * 8 + 6) + 6) + 2 + 4 * 2"));
}

test "part 2" {
    return error.SkipZigTest;
}
