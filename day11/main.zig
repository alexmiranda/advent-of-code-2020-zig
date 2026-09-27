const std = @import("std");
const example = @embedFile("example.txt");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day11/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    var layout: Layout = try .initParse(gpa, &reader.interface);
    defer layout.deinit(gpa);

    const answer_p1 = try layout.sim(gpa);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

const Layout = struct {
    grid: [:.none]Tile,
    width: u16,
    height: u16,

    const Tile = enum(u2) {
        none = 0,
        empty = 1,
        occupied = 2,
        floor = 3,
    };

    const top_left_corner = mask(0b11010000);
    const top_edge_row = mask(0b11111000);
    const top_right_corner = mask(0b01101000);
    const left_edge_col = mask(0b11010110);
    const right_edge_col = mask(0b01101011);
    const bottom_left_corner = mask(0b00010110);
    const bottom_edge_row = mask(0b00011111);
    const bottom_right_corner = mask(0b00001011);

    fn initParse(gpa: Allocator, reader: *Reader) !Layout {
        const first_line = blk: {
            const line = try reader.peekDelimiterInclusive('\n');
            break :blk line[0 .. line.len - 1];
        };

        var list: std.ArrayList(Tile) = try .initCapacity(gpa, first_line.len * first_line.len);
        defer list.deinit(gpa);

        var rows: u16 = 0;
        const cols: u16 = @truncate(first_line.len);
        while (reader.take(first_line.len)) |line| : (_ = try reader.discard(.limited(1))) {
            try list.ensureUnusedCapacity(gpa, line.len);
            for (line) |c| {
                list.appendAssumeCapacity(switch (c) {
                    'L' => .empty,
                    '#' => .occupied,
                    '.' => .floor,
                    else => std.debug.panic("invalid tile: {c}", .{c}),
                });
            }
            rows += 1;
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }

        const grid = try list.toOwnedSliceSentinel(gpa, .none);
        return .{ .grid = grid, .width = cols, .height = rows };
    }

    fn deinit(self: *Layout, gpa: Allocator) void {
        gpa.free(self.grid);
    }

    fn sim(self: *Layout, gpa: Allocator) !u16 {
        // next state of the grid
        var next: [:.none]Tile = try gpa.allocSentinel(Tile, self.grid.len, .none);
        defer gpa.free(next);

        var keep_going = true;
        var total_occupied: u16 = 0;
        while (keep_going) {
            keep_going = false;
            total_occupied = 0;
            var slide: u16 = 0;
            while (slide < self.grid.len) : (slide += 1) {
                // floor tiles don't change
                if (self.grid[slide] == .floor) {
                    next[slide] = .floor;
                    continue;
                }

                // count occupied adjacent tiles
                const indices = adjacentIndices(slide, self.width, self.height);
                // std.debug.print("{any}\n", .{indices});
                var count_occupied: u8 = 0;
                inline for (0..8) |i| {
                    switch (self.grid[indices[i]]) {
                        .occupied => count_occupied += 1,
                        else => {},
                    }
                }

                // set the next state of the grid
                next[slide] = if (self.grid[slide] == .empty and count_occupied == 0) blk: {
                    keep_going = true;
                    total_occupied += 1;
                    break :blk .occupied;
                } else if (self.grid[slide] == .occupied and count_occupied >= 4) blk: {
                    keep_going = true;
                    break :blk .empty;
                } else blk: {
                    if (self.grid[slide] == .occupied) total_occupied += 1;
                    break :blk self.grid[slide];
                };
            }

            // std.debug.print(">>>>>>>>>>>>>>>>>>>>>>>\n", .{});
            // std.debug.print("{f}", .{self});
            std.mem.swap([:.none]Tile, &next, &self.grid);
            // std.debug.print("=======================\n", .{});
            // std.debug.print("{f}", .{self});
            // std.debug.print("<<<<<<<<<<<<<<<<<<<<<<<\n\n\n", .{});
        }
        return total_occupied;
    }

    /// Calculates the coordinates of all adjacents tiles
    fn adjacentIndices(index: u16, width: u16, height: u16) [8]u16 {
        const w: i16 = @bitCast(width);
        const h: i16 = @bitCast(height);
        const len: i16 = w * h;
        const offsets: @Vector(8, i16) = .{ -w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1 };
        const splat: @Vector(8, i16) = @splat(@bitCast(index));
        const pred = selectorMask(@bitCast(index), w, len);
        const sentinels: @Vector(8, i16) = @splat(len);
        const indices = splat + offsets;
        return @bitCast(@select(i16, pred, indices, sentinels));
    }

    /// Determines the mask used to pick which of the 8 adjacent tiles are relevant.
    /// If an adjacent tile coordinate is not relevant, it gets replaced with the sentinel position
    fn selectorMask(index: i16, size: i16, len: i16) @Vector(8, bool) {
        if (index == 0) {
            return top_left_corner;
        } else if (index == size - 1) {
            return top_right_corner;
        } else if (index == len - size) {
            return bottom_left_corner;
        } else if (index == len - 1) {
            return bottom_right_corner;
        } else if (index < size) {
            return top_edge_row;
        } else if (@rem(index, size) == 0) {
            return left_edge_col;
        } else if (@rem(index, size) == size - 1) {
            return right_edge_col;
        } else if (index > len - size) {
            return bottom_edge_row;
        } else {
            return @splat(true);
        }
    }

    pub fn format(self: Layout, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        for (0..self.height) |row| {
            const offset = row * self.width;
            for (self.grid[offset .. offset + self.width]) |tile| {
                try writer.writeByte(switch (tile) {
                    .empty => 'L',
                    .occupied => '#',
                    .floor => '.',
                    else => unreachable,
                });
            }
            try writer.writeByte('\n');
        }
    }

    /// Bit i selects neighbour i in the offset order used by adjacentIndices(..):
    /// top-left, top, top-right, left, right, bottom-left, bottom, bottom-right.
    /// So lane 0 is the top-left neighbour and a literal reads lane 7 -> lane 0.
    fn mask(comptime bits: u8) @Vector(8, bool) {
        return @bitCast(bits);
    }

    comptime {
        // Pins bit 0 to the top-left neighbour; without this a bit-order slip
        // compiles fine and can skew edge-tile neighbour counts
        std.debug.assert(@reduce(.And, mask(0b00001011) == @Vector(8, bool){
            true, true, false, true, false, false, false, false,
        }));
        std.debug.assert(mask(0b00000001)[0] and !mask(0b00000001)[1]);
    }
};

test "part 1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example);
    var layout: Layout = try .initParse(gpa, &reader);
    defer layout.deinit(gpa);

    // std.debug.print("{f}", .{layout});
    const answer = try layout.sim(gpa);
    try std.testing.expectEqual(37, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
