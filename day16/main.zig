const std = @import("std");
const example = @embedFile("example.txt");
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

    const answer_p1 = ticket_translator.scan();
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

const TicketTranslator = struct {
    ranges: []struct { u16, u16 },
    near_by_tickets: []u16,

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

        // discard the next 4 lines - your tickets and nearby tickets header
        for (0..5) |_| _ = try reader.takeDelimiterInclusive('\n');

        var near_by_tickets: std.ArrayList(u16) = .empty;
        defer near_by_tickets.deinit(gpa);

        while (reader.takeDelimiterExclusive('\n')) |line| : (reader.toss(1)) {
            if (line.len == 0) break;
            var it = std.mem.splitScalar(u8, line, ',');
            while (it.next()) |s| {
                const ticket = try std.fmt.parseUnsigned(u16, s, 10);
                try near_by_tickets.append(gpa, ticket);
            }
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }

        return .{
            .ranges = try ranges.toOwnedSlice(gpa),
            .near_by_tickets = try near_by_tickets.toOwnedSlice(gpa),
        };
    }

    fn deinit(self: *TicketTranslator, gpa: Allocator) void {
        gpa.free(self.ranges);
        gpa.free(self.near_by_tickets);
    }

    fn scan(self: *TicketTranslator) u16 {
        var error_rate: u16 = 0;
        for (self.near_by_tickets) |ticket| {
            for (self.ranges) |range| {
                if (ticket >= range.@"0" and ticket <= range.@"1") {
                    break;
                }
            } else error_rate += ticket;
        }
        return error_rate;
    }
};

test "part 1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example);
    var ticket_translator: TicketTranslator = try .initParse(gpa, &reader);
    defer ticket_translator.deinit(gpa);

    try std.testing.expectEqual(71, ticket_translator.scan());
}

test "part 2" {
    return error.SkipZigTest;
}
