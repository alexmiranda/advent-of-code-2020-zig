const std = @import("std");
const example1 = @embedFile("example1.txt");
const example2 = @embedFile("example2.txt");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day10/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);

    const gpa = init.gpa;
    var adapter_array: *AdapterArray = try .initParse(gpa, &reader.interface);
    defer adapter_array.deinit(gpa);

    const product, const ways = try adapter_array.findChains();
    try stdout.print("Part 1: {d}\n", .{product});
    try stdout.print("Part 2: {d}\n", .{ways});
    try stdout.flush();
}

const AdapterArray = struct {
    min_heap: std.PriorityQueue(u16, void, lessThan) = .empty,

    fn lessThan(_: void, a: u16, b: u16) std.math.Order {
        return std.math.order(a, b);
    }

    fn initParse(gpa: Allocator, reader: *Reader) !*AdapterArray {
        var self = try gpa.create(AdapterArray);
        errdefer gpa.destroy(self);
        self.* = .{};

        while (reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.EndOfStream => null,
            else => return err,
        }) |tok| : (_ = try reader.discard(.limited(1))) {
            if (tok.len == 0) break;
            // std.debug.print("{s}\n", .{tok});
            const jolt = try std.fmt.parseInt(u16, tok, 10);
            try self.min_heap.push(gpa, jolt);
        }

        return self;
    }

    fn deinit(self: *AdapterArray, gpa: Allocator) void {
        self.min_heap.deinit(gpa);
        gpa.destroy(self);
    }

    fn findChains(self: *AdapterArray) !struct { u16, usize } {
        // walk the sorted chain, counting 1-jolt and 3-jolt differences
        // and how many distinct ways the chain can be arranged using dp
        // and zero allocs (ring buffer to store that last 3 jolts)
        var output: u16 = 0;
        var delta: struct { u16, u16 } = .{ 0, 1 };
        var dp = [_]u64{ 1, 0, 0 };
        var slide: usize = 1;
        while (self.min_heap.pop()) |jolt| : (slide = (slide + 1) % dp.len) {
            sw: switch (jolt - output) {
                0 => std.debug.panic("duplicate jolt found: {d}", .{jolt}),
                1 => delta.@"0" += 1,
                2 => {
                    dp[slide] = 0;
                    slide = (slide + 1) % dp.len;
                },
                3 => {
                    delta.@"1" += 1;
                    dp[slide] = 0;
                    slide = (slide + 1) % dp.len;
                    continue :sw 2;
                },
                else => {},
            }

            // sum the the ways the previous jolts can be connected
            const sum = dp[0] + dp[1] + dp[2];
            dp[slide] = sum;
            output = jolt;
        }

        return .{ delta.@"0" * delta.@"1", dp[(slide - 1) % dp.len] };
    }
};

test "part 1 example1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example1);
    var adapter_array: *AdapterArray = try .initParse(gpa, &reader);
    defer adapter_array.deinit(gpa);

    const product, const ways = try adapter_array.findChains();
    try std.testing.expectEqual(35, product);
    try std.testing.expectEqual(8, ways);
}

test "part 1 example2" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example2);
    var adapter_array: *AdapterArray = try .initParse(gpa, &reader);
    defer adapter_array.deinit(gpa);

    const product, const ways = try adapter_array.findChains();
    try std.testing.expectEqual(220, product);
    try std.testing.expectEqual(19208, ways);
}

test "part 2 example1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example1);
    var adapter_array: *AdapterArray = try .initParse(gpa, &reader);
    defer adapter_array.deinit(gpa);

    const result = try adapter_array.findChains();
    try std.testing.expectEqual(8, result.@"1");
}

test "part 2 example2" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example2);
    var adapter_array: *AdapterArray = try .initParse(gpa, &reader);
    defer adapter_array.deinit(gpa);

    const result = try adapter_array.findChains();
    try std.testing.expectEqual(19208, result.@"1");
}
