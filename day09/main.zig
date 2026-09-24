const std = @import("std");
const example = @embedFile("example.txt");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day09/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);

    const gpa = init.gpa;
    var cypher: *XmasCypher(25) = try .initReader(gpa, &reader.interface);
    defer cypher.deinit(gpa);

    const answer_p1 = try cypher.findInvalidNumber(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn XmasCypher(preamble: u16) type {
    return struct {
        window: [preamble]u64 = [_]u64{0} ** preamble,
        prefix_sums: [preamble * preamble]u64 = [_]u64{0} ** (preamble * preamble),

        const lanes = std.simd.suggestVectorLength(u64) orelse 1;
        const Self = @This();

        fn initReader(gpa: Allocator, reader: *Reader) !*Self {
            var self = try gpa.create(Self);
            errdefer gpa.destroy(self);
            self.* = .{};

            for (0..preamble) |slide| {
                const tok = reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
                    error.EndOfStream => break,
                    else => return err,
                };
                self.window[slide] = try std.fmt.parseInt(u64, tok[0 .. tok.len - 1], 10);
            }

            return self;
        }

        fn deinit(self: *Self, gpa: Allocator) void {
            gpa.destroy(self);
        }

        fn recomputePrefixSums(self: *Self, end: usize) void {
            for (0..preamble) |row| {
                var col: usize = 0;

                // compute prefix sum in chunks
                while (col + lanes <= preamble) : (col += lanes) {
                    const base: @Vector(lanes, u64) = @splat(self.window[(end + row) % preamble]);
                    var window: @Vector(lanes, u64) = undefined;
                    inline for (0..lanes) |i| window[i] = self.window[(end + col + i) % preamble];
                    const res: [lanes]u64 = base + window;
                    std.mem.copyForwards(u64, self.prefix_sums[row * preamble + col ..][0..lanes], &res);
                }

                // compute remaining prefix sum
                for (col..preamble) |i| {
                    self.prefix_sums[row * preamble + i] = self.window[(end + row) % preamble] + self.window[(end + i) % preamble];
                }
            }
        }

        fn findInvalidNumber(self: *Self, reader: *Reader) !u64 {
            self.recomputePrefixSums(0);
            var end: usize = 0;
            while (reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
                error.EndOfStream => null,
                else => return err,
            }) |tok| {
                const num = try std.fmt.parseInt(u64, tok[0 .. tok.len - 1], 10);

                // check if num is found in the prefix sums
                if (std.mem.findScalar(u64, &self.prefix_sums, num) == null) {
                    return num;
                }

                // append to sliding window and recompute prefix sums
                self.window[end] = num;
                end = (end + 1) % preamble;
                recomputePrefixSums(self, end);
            }
            return 0; // not found
        }
    };
}

test "part 1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example);
    var cypher: *XmasCypher(5) = try .initReader(gpa, &reader);
    defer cypher.deinit(gpa);

    const answer = try cypher.findInvalidNumber(&reader);
    try std.testing.expectEqual(127, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
