const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day23/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [9]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    const slice = reader.interface.take(9) catch undefined;

    var crab_game: CrabGame = .init(slice);
    const answer_p1 = crab_game.play(100);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    const gpa = init.gpa;
    crab_game = .init(slice);
    const answer_p2 = try crab_game.playForReal(gpa, 10_000_000);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

const CrabGame = struct {
    cups: [9]u8,
    current: u8,

    fn init(slice: []const u8) CrabGame {
        var self: CrabGame = undefined;
        var it = std.mem.window(u8, slice, 2, 1);
        while (it.next()) |pair| {
            const current, const next = .{ pair[0] - '0', pair[1] - '0' };
            self.cups[current - 1] = next;
        }
        const current, const next = .{ slice[slice.len - 1] - '0', slice[0] - '0' };
        self.cups[current - 1] = next;
        self.current = next - 1;
        return self;
    }

    fn play(self: *CrabGame, n: u8) u64 {
        for (0..n) |_| {
            // pick up the next 3 cups clockwise
            var pick_up: [3]u8 = undefined;
            var next = self.cups[self.current];
            for (0..3) |slide| {
                pick_up[slide] = next;
                next = self.cups[next - 1];
            }

            // decide the destination
            var dest = if (self.current == 0) 9 else self.current;
            while (std.mem.findScalar(u8, &pick_up, dest)) |_| {
                dest -= 1;
                if (dest == 0) dest = 9;
            }

            // move cups
            self.cups[self.current] = next;
            self.current = next - 1;
            next = self.cups[dest - 1];
            self.cups[dest - 1] = pick_up[0];
            self.cups[pick_up[2] - 1] = next;
        }

        var result: u64 = 0;
        var value = self.cups[0];
        for (0..8) |_| {
            result *= 10;
            result += value;
            value = self.cups[value - 1];
        }
        return result;
    }

    fn playForReal(self: *CrabGame, gpa: Allocator, n: u64) !u64 {
        var circle: std.AutoHashMapUnmanaged(u32, u32) = .empty;
        defer circle.deinit(gpa);

        const first: u8 = self.current + 1;
        var prev: u32 = 0;
        for (self.cups, 1..) |next, slide| {
            try circle.put(gpa, @intCast(slide), next);
            if (next == first) prev = @intCast(slide);
        }

        try circle.put(gpa, prev, self.cups.len + 1);
        try circle.put(gpa, 1_000_000, first);

        var current: u32 = self.current + 1;
        for (0..n) |_| {
            // pick up the next 3 cups clockwise
            var pick_up: [3]u32 = undefined;
            var next = nextOf(&circle, current);
            for (0..3) |slide| {
                pick_up[slide] = next;
                next = nextOf(&circle, next);
            }

            // decide the destination
            var dest = if (current == 1) 1_000_000 else current - 1;
            while (std.mem.findScalar(u32, &pick_up, dest)) |_| {
                dest -= 1;
                if (dest == 0) dest = 1_000_000;
            }

            // move cups
            try circle.put(gpa, current, next);
            current = next;
            next = nextOf(&circle, dest);
            try circle.put(gpa, dest, pick_up[0]);
            try circle.put(gpa, pick_up[2], next);
        }

        const a: u32 = nextOf(&circle, 1);
        const b: u64 = nextOf(&circle, a);
        return a * b;
    }

    fn nextOf(circle: *std.AutoHashMapUnmanaged(u32, u32), cup: u32) u32 {
        return circle.get(cup) orelse (if (cup == 1_000_000) 1 else cup + 1);
    }

    pub fn format(self: CrabGame, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        var buf: [9]u8 = undefined;
        buf[0] = '0' + self.current + 1;
        var next = self.cups[self.current];
        for (1..9) |slide| {
            buf[slide] = '0' + next;
            next = self.cups[next - 1];
        }
        try writer.writeAll(&buf);
    }
};

test "part 1" {
    var crab_game: CrabGame = .init("389125467");
    try std.testing.expectEqual(92658374, crab_game.play(10));
    try std.testing.expectEqual(67384529, crab_game.play(90));
}

test "part 2" {
    const gpa = std.testing.allocator;
    var crab_game: CrabGame = .init("389125467");
    try std.testing.expectEqual(149245887792, crab_game.playForReal(gpa, 10_000_000));
}
