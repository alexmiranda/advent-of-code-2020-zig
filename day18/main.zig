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
    const answer_p1 = try doHomework(gpa, &reader.interface, basic);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try reader.seekTo(0);
    const answer_p2 = try doHomework(gpa, &reader.interface, advanced);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

const Expr = struct {
    evalFn: *const fn (*Expr, Allocator) error{OutOfMemory}!u64,

    fn eval(self: *Expr, gpa: Allocator) error{OutOfMemory}!u64 {
        return self.evalFn(self, gpa);
    }
};

fn basic(gpa: Allocator, slice: []const u8) error{OutOfMemory}!u64 {
    return @constCast(&Basic.init(slice)).expr.eval(gpa);
}

fn advanced(gpa: Allocator, slice: []const u8) error{OutOfMemory}!u64 {
    return @constCast(&Advanced.init(slice)).expr.eval(gpa);
}

const Basic = struct {
    expr: Expr,
    slice: []const u8,

    const Self = @This();

    fn init(slice: []const u8) Self {
        return .{
            .expr = .{ .evalFn = Self.eval },
            .slice = slice,
        };
    }

    fn eval(expr: *Expr, gpa: Allocator) !u64 {
        const self: *Self = @fieldParentPtr("expr", expr);
        const max_operands = std.math.divCeil(usize, self.slice.len * 2, @as(usize, 5)) catch 0;
        var operands: std.ArrayList(u64) = try .initCapacity(gpa, max_operands);
        defer operands.deinit(gpa);

        const max_operators = std.math.divCeil(usize, self.slice.len, 5) catch 0;
        var operators: std.ArrayList(u8) = try .initCapacity(gpa, max_operators);
        defer operators.deinit(gpa);

        for (self.slice) |c| {
            // std.debug.print("{c}", .{c});
            sw: switch (c) {
                ' ', '\n' => {},
                '0'...'9' => {
                    operands.appendAssumeCapacity(c - '0');
                    if (operators.items.len > 0) continue :sw ')';
                },
                '+', '*' => |op| try operators.append(gpa, op),
                '(' => {
                    operands.appendAssumeCapacity(0);
                    operators.appendAssumeCapacity('+');
                },
                ')' => {
                    if (operands.items.len < 2) continue;
                    const rhs = operands.pop().?;
                    const lhs = operands.pop().?;
                    switch (operators.pop().?) {
                        '+' => operands.appendAssumeCapacity(lhs + rhs),
                        '*' => operands.appendAssumeCapacity(lhs * rhs),
                        else => |invalid| continue :sw invalid,
                    }
                },
                else => |invalid| std.debug.panic("invalid char: {c}", .{invalid}),
            }
        }

        // std.debug.print("\n", .{});
        return operands.pop() orelse 0;
    }
};

const Advanced = struct {
    expr: Expr,
    slice: []const u8,

    const Self = @This();

    fn init(slice: []const u8) Self {
        return .{
            .expr = .{ .evalFn = Self.eval },
            .slice = slice,
        };
    }

    fn eval(expr: *Expr, _: Allocator) !u64 {
        const self: *Self = @fieldParentPtr("expr", expr);
        var tokeniser = std.mem.window(u8, self.slice, 1, 1);
        return evalRecursively(&tokeniser);
    }

    fn evalRecursively(tokeniser: *std.mem.WindowIterator(u8)) !u64 {
        var sum: u64 = 0;
        var product: u64 = 1;

        while (tokeniser.next()) |tok| {
            // std.debug.print("{s}", .{tok});
            const c = tok[0];
            switch (c) {
                ' ', '\n' => {},
                '0'...'9' => sum += c - '0',
                '+' => {},
                '*' => {
                    product *= sum;
                    sum = 0;
                },
                '(' => sum += try evalRecursively(tokeniser),
                ')' => {
                    product *= sum;
                    return product;
                },
                else => |invalid| std.debug.panic("invalid char: {c}", .{invalid}),
            }
        }

        // std.debug.print("\n", .{});
        return product * sum;
    }
};

fn doHomework(gpa: Allocator, reader: *Reader, evalFn: *const fn (Allocator, []const u8) error{OutOfMemory}!u64) !u64 {
    var sum: u64 = 0;
    while (reader.takeDelimiterInclusive('\n')) |expr| {
        sum += try evalFn(gpa, expr);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return sum;
}

test "part 1" {
    const gpa = std.testing.allocator;
    try std.testing.expectEqual(26, basic(gpa, "2 * 3 + (4 * 5)"));
    try std.testing.expectEqual(437, basic(gpa, "5 + (8 * 3 + 9 + 3 * 4 * 3)"));
    try std.testing.expectEqual(437, basic(gpa, "5 + (8 * 3 + 9 + 3 * 4 * 3)"));
    try std.testing.expectEqual(12240, basic(gpa, "5 * 9 * (7 * 3 * 3 + 9 * 3 + (8 + 6 * 4))"));
    try std.testing.expectEqual(13632, basic(gpa, "((2 + 4 * 9) * (6 + 9 * 8 + 6) + 6) + 2 + 4 * 2"));
}

test "part 2" {
    const gpa = std.testing.allocator;
    try std.testing.expectEqual(51, advanced(gpa, "1 + (2 * 3) + (4 * (5 + 6))"));
    try std.testing.expectEqual(46, advanced(gpa, "2 * 3 + (4 * 5)"));
    try std.testing.expectEqual(1445, advanced(gpa, "5 + (8 * 3 + 9 + 3 * 4 * 3)"));
    try std.testing.expectEqual(669060, advanced(gpa, "5 * 9 * (7 * 3 * 3 + 9 * 3 + (8 + 6 * 4))"));
    try std.testing.expectEqual(23340, advanced(gpa, "((2 + 4 * 9) * (6 + 9 * 8 + 6) + 6) + 2 + 4 * 2"));
}
