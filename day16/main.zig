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

    const input = "day16/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    const gpa = init.gpa;
    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    var ticket_translator: TicketTranslator = try .initParse(gpa, &reader.interface);
    defer ticket_translator.deinit(gpa);

    const answer_p1 = try ticket_translator.scan(gpa, &reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    const answer_p2 = try ticket_translator.solve(gpa);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

const TicketTranslator = struct {
    ranges: []struct { u16, u16 },
    tickets: std.ArrayList(u16),
    near_by_tickets: ?[]u16 = null,

    fn initParse(gpa: Allocator, reader: *Reader) !TicketTranslator {
        var ranges: std.ArrayList(struct { u16, u16 }) = .empty;
        defer ranges.deinit(gpa);

        while (reader.takeDelimiterExclusive('\n') catch null) |line| : (reader.toss(1)) {
            if (line.len == 0) break;
            const sep = std.mem.indexOfScalar(u8, line, ':').?;
            var it = std.mem.splitAny(u8, line[sep + 2 ..], " -");
            const a1 = try std.fmt.parseUnsigned(u16, it.next().?, 10);
            const a2 = try std.fmt.parseUnsigned(u16, it.next().?, 10);
            _ = it.next(); // or
            const b1 = try std.fmt.parseUnsigned(u16, it.next().?, 10);
            const b2 = try std.fmt.parseUnsigned(u16, it.next().?, 10);
            try ranges.ensureUnusedCapacity(gpa, 2);
            ranges.appendAssumeCapacity(.{ a1, a2 });
            ranges.appendAssumeCapacity(.{ b1, b2 });
        }

        _ = try reader.takeDelimiterInclusive('\n'); // empty line
        _ = try reader.takeDelimiterInclusive('\n'); // your ticket

        const field_count = ranges.items.len / 2;
        var your_ticket: std.ArrayList(u16) = try .initCapacity(gpa, field_count);
        errdefer your_ticket.deinit(gpa);

        {
            const line = try reader.takeDelimiterInclusive('\n');
            var it = std.mem.splitScalar(u8, line[0 .. line.len - 1], ',');
            while (it.next()) |tok| {
                const value = try std.fmt.parseUnsigned(u16, tok, 10);
                your_ticket.appendAssumeCapacity(value);
            }
        }

        _ = try reader.takeDelimiterInclusive('\n'); // empty line

        return .{
            .ranges = try ranges.toOwnedSlice(gpa),
            .tickets = your_ticket,
        };
    }

    fn deinit(self: *TicketTranslator, gpa: Allocator) void {
        gpa.free(self.ranges);
        self.tickets.deinit(gpa);
    }

    fn scan(self: *TicketTranslator, gpa: Allocator, reader: *Reader) !u16 {
        const field_count = self.ranges.len / 2;
        var error_rate: u16 = 0;
        _ = try reader.takeDelimiterInclusive('\n'); // near by tickets
        outer: while (reader.takeDelimiterExclusive('\n')) |line| : (reader.toss(1)) {
            if (line.len == 0) break;
            const len = self.tickets.items.len;
            try self.tickets.ensureUnusedCapacity(gpa, field_count);
            var it = std.mem.splitScalar(u8, line, ',');
            var value: u16 = 0;
            while (it.next()) |tok| {
                value = try std.fmt.parseUnsigned(u16, tok, 10);
                for (self.ranges) |range| {
                    if (value >= range.@"0" and value <= range.@"1") {
                        self.tickets.appendAssumeCapacity(value);
                        break;
                    }
                } else {
                    error_rate += value;
                    self.tickets.shrinkRetainingCapacity(len);
                    continue :outer;
                }
            }
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }

        return error_rate;
    }

    fn solve(self: *TicketTranslator, gpa: Allocator) !u64 {
        const field_count: u16 = @truncate(self.ranges.len / 2);
        var matrix: std.bit_set.Dynamic = try .initEmpty(gpa, field_count * field_count);
        defer matrix.deinit(gpa);

        var solution = try gpa.alloc(u8, field_count);
        defer gpa.free(solution);
        @memset(solution, std.math.maxInt(u8));

        var stack: std.ArrayList(u8) = .empty;
        defer stack.deinit(gpa);

        var it = std.mem.window(struct { u16, u16 }, self.ranges, 2, 2);
        for (0..field_count) |col| {
            it.reset();
            var count_matches: u8 = 0;
            var last_match_index: u8 = std.math.maxInt(u8);
            var field_index: u8 = 0;
            while (it.next()) |field| : (field_index += 1) {
                // already found a solution for this field
                if (solution[field_index] != std.math.maxInt(u8)) {
                    continue;
                }

                // determine which fields are matched
                var slide = col;
                const valid = while (slide < self.tickets.items.len) : (slide += field_count) {
                    const value = self.tickets.items[slide];
                    const a, const b = .{ field[0], field[1] };
                    if ((value < a.@"0" or value > a.@"1") and (value < b.@"0" or value > b.@"1")) {
                        // don't need to continue checking more values at this point
                        break false;
                    }
                } else blk: {
                    count_matches += 1;
                    last_match_index = field_index;
                    break :blk true;
                };
                // if all values in the column matched, we set its bit
                if (valid) matrix.set(col * field_count + field_index);
            }

            // if the column matches only a single field, then we lock it in
            if (count_matches == 1) {
                try stack.append(gpa, @truncate(col));
                solution[last_match_index] = @truncate(col);
                // std.debug.print("{d} col is locked in!\n", .{col});
            }
        }

        // in my input, the first 6 fields start with "departure". YMMV
        const last_relevant_index = @min(6, solution.len);
        while (stack.pop()) |col| {
            // stop early if the relevant columns are locked in
            if (!std.mem.containsAtLeastScalar(u8, solution[0..last_relevant_index], std.math.maxInt(u8), 1)) break;

            // read each column and if it's locked in, clear all other matches for the same field
            const bits = foldColBits(&matrix, col, field_count);
            // std.debug.print("col={d:0>2} bits={b:0>20}\n", .{ col, bits });
            if (@popCount(bits) != 1) continue;
            const field_index = @ctz(bits);
            solution[field_index] = col;
            for (0..field_count) |index| {
                const i: u8 = @truncate(index);
                if (i == col) continue;
                matrix.unset(i * field_count + field_index);
                if (std.mem.findScalar(u8, solution, i) == null) {
                    try stack.append(gpa, i);
                }
            }
        }

        // printMatrix(&matrix, field_count);
        // std.debug.print("solution: {any}\n", .{solution});
        // std.debug.print("your ticket: {any}\n", .{self.tickets.items[0..field_count]});

        // multiply the relevant values from 'your ticket'
        var result: u64 = self.tickets.items[solution[0]];
        for (solution[1..@min(6, solution.len)]) |col| {
            // std.debug.print("result = {d} * {d} (col={d})\n", .{ result, self.tickets.items[col], col });
            result *= self.tickets.items[col];
        }
        return result;
    }

    fn foldColBits(matrix: *std.bit_set.Dynamic, col: u8, field_count: u16) u32 {
        var bits: u32 = 0;
        const start = col * field_count;
        const end = start + field_count;
        for (start..end) |slice| {
            if (matrix.isSet(slice)) {
                const pos: u5 = @truncate(slice - start);
                bits |= @as(u32, 1) << pos;
            }
        }
        return bits;
    }

    fn printMatrix(matrix: *std.bit_set.Dynamic, field_count: u16) void {
        for (0..matrix.bit_length) |i| {
            if (matrix.isSet(i)) std.debug.print("1", .{}) else std.debug.print("0", .{});
            if (i % field_count == field_count - 1) std.debug.print("\n", .{});
        }
    }
};

test "part 1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example1);
    var ticket_translator: TicketTranslator = try .initParse(gpa, &reader);
    defer ticket_translator.deinit(gpa);

    try std.testing.expectEqual(71, ticket_translator.scan(gpa, &reader));
}

test "part 2" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example2);
    var ticket_translator: TicketTranslator = try .initParse(gpa, &reader);
    defer ticket_translator.deinit(gpa);

    _ = try ticket_translator.scan(gpa, &reader);
    try std.testing.expectEqual(11 * 12 * 13, ticket_translator.solve(gpa));
}
