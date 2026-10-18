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

    const input = "day14/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    const gpa = init.gpa;
    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    var program: Program = try .initParse(gpa, &reader.interface);
    defer program.deinit(gpa);

    const answer_p1 = try program.executeV1(gpa);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    const answer_p2 = try program.executeV2(gpa);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

const InstructionKind = enum(u1) {
    mask = 0,
    mem = 1,
};

const Instruction = union(InstructionKind) {
    mask: struct {
        on: std.bit_set.Integer(36),
        off: std.bit_set.Integer(36),
        floating: std.bit_set.Integer(36),
    },
    mem: struct {
        address: u16,
        value: u32,
    },
};

const Program = struct {
    data: []Instruction,

    fn initParse(gpa: Allocator, reader: *Reader) !Program {
        var data: std.ArrayListUnmanaged(Instruction) = .empty;
        defer data.deinit(gpa);

        var on: std.bit_set.Integer(36) = undefined;
        var off: std.bit_set.Integer(36) = undefined;
        var floating: std.bit_set.Integer(36) = undefined;
        while (reader.take(4)) |prefix| : (_ = try reader.discard(.limited(1))) {
            if (std.mem.eql(u8, "mask", prefix)) {
                _ = try reader.discard(.limited(3)); // spaces and equal
                on = .empty;
                off = .full;
                floating = .empty;
                const mask = try reader.take(36);
                for (mask, 1..) |c, i| {
                    switch (c) {
                        '0' => off.unset(mask.len - i),
                        '1' => on.set(mask.len - i),
                        'X' => floating.set(mask.len - i),
                        else => std.debug.panic("invalid char: {c}", .{c}),
                    }
                }
                try data.append(gpa, .{ .mask = .{ .on = on, .off = off, .floating = floating } });
            } else if (std.mem.eql(u8, "mem[", prefix)) {
                var tok = try reader.takeDelimiterExclusive(']');
                const address = try std.fmt.parseInt(u16, tok, 10);
                _ = try reader.discard(.limited(4)); // ], spaces and equal
                tok = try reader.takeDelimiterExclusive('\n');
                const value = try std.fmt.parseInt(u32, tok, 10);
                try data.append(gpa, .{ .mem = .{ .address = address, .value = value } });
            } else {
                @panic("malformed input!");
            }
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }

        return .{ .data = try data.toOwnedSlice(gpa) };
    }

    fn deinit(self: *Program, gpa: Allocator) void {
        gpa.free(self.data);
    }

    fn executeV1(self: *Program, gpa: Allocator) !u64 {
        var mem: std.AutoHashMapUnmanaged(u16, u36) = .empty;
        defer mem.deinit(gpa);

        var on: u36 = undefined;
        var off: u36 = undefined;
        var sum: u64 = 0;
        for (self.data) |instruction| {
            switch (instruction) {
                .mask => |opts| {
                    on = opts.on.mask;
                    off = opts.off.mask;
                },
                .mem => |opts| {
                    const address = opts.address;
                    var value: u36 = opts.value;
                    value |= on;
                    value &= off;
                    sum += value;
                    if (try mem.fetchPut(gpa, address, value)) |prev| {
                        sum -= prev.value;
                    }
                },
            }
        }

        return sum;
    }

    fn executeV2(self: *Program, gpa: Allocator) !u64 {
        var mem: std.AutoHashMapUnmanaged(u36, u32) = .empty;
        defer mem.deinit(gpa);

        var addresses: std.ArrayListUnmanaged(std.bit_set.Integer(36)) = .empty;
        defer addresses.deinit(gpa);

        var on: std.bit_set.Integer(36) = undefined;
        var floating: std.bit_set.Integer(36) = undefined;
        var sum: u64 = 0;
        for (self.data) |instruction| {
            switch (instruction) {
                .mask => |opts| {
                    on = opts.on;
                    floating = opts.floating;
                    try addresses.ensureTotalCapacityPrecise(gpa, std.math.pow(usize, 2, floating.count()));
                },
                .mem => |opts| {
                    const value = opts.value;
                    var address: std.bit_set.Integer(36) = .{ .mask = opts.address };
                    address.setUnion(on);

                    addresses.clearRetainingCapacity();
                    addresses.appendAssumeCapacity(address);
                    sum += value;
                    if (try mem.fetchPut(gpa, address.mask, value)) |prev| {
                        sum -= prev.value;
                    }

                    const first_set = floating.findFirstSet() orelse continue;
                    const last_set = floating.findLastSet().? + 1;
                    for (first_set..last_set) |i| {
                        if (!floating.isSet(i)) continue;
                        for (0..addresses.items.len) |j| {
                            var next = addresses.items[j];
                            next.toggle(i);
                            addresses.appendAssumeCapacity(next);
                            sum += value;
                            if (try mem.fetchPut(gpa, next.mask, value)) |prev| {
                                sum -= prev.value;
                            }
                        }
                    }
                },
            }
        }

        return sum;
    }
};

test "part 1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example1);
    var program: Program = try .initParse(gpa, &reader);
    defer program.deinit(gpa);

    const answer = try program.executeV1(gpa);
    try std.testing.expectEqual(165, answer);
}

test "part 2" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example2);
    var program: Program = try .initParse(gpa, &reader);
    defer program.deinit(gpa);

    const answer = try program.executeV2(gpa);
    try std.testing.expectEqual(208, answer);
}
