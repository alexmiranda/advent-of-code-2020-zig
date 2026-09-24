const std = @import("std");
const example = @embedFile("example.txt");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day08/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);

    const gpa = init.gpa;
    var program: Program = try .load(gpa, &reader.interface);
    defer program.deinit(gpa);

    const answer_p1 = try program.run(gpa);
    try stdout.print("Part 1: {d}\n", .{answer_p1.halt});

    const answer_p2 = try program.patch(gpa);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

const Instruction = union(enum) {
    acc: i16,
    jmp: i16,
    nop: i16,
};

const Exit = union(enum) {
    halt: i16,
    terminate: i16,
};

const Program = struct {
    data: []Instruction,

    fn load(gpa: Allocator, reader: *Reader) !Program {
        var data: std.ArrayListUnmanaged(Instruction) = .empty;
        defer data.deinit(gpa);

        while (reader.take(4) catch |err| switch (err) {
            error.EndOfStream => null,
            else => return err,
        }) |inst| {
            const op = inst[0..3];
            const args = try reader.takeDelimiterInclusive('\n');
            if (std.mem.eql(u8, "acc", op)) {
                const acc = try std.fmt.parseInt(i16, args[0 .. args.len - 1], 10);
                try data.append(gpa, .{ .acc = acc });
            } else if (std.mem.eql(u8, "jmp", op)) {
                const jmp = try std.fmt.parseInt(i16, args[0 .. args.len - 1], 10);
                try data.append(gpa, .{ .jmp = jmp });
            } else if (std.mem.eql(u8, "nop", op)) {
                const nop = try std.fmt.parseInt(i16, args[0 .. args.len - 1], 10);
                try data.append(gpa, .{ .nop = nop });
            }
        }

        return .{ .data = try data.toOwnedSlice(gpa) };
    }

    fn deinit(self: *Program, gpa: Allocator) void {
        gpa.free(self.data);
    }

    fn run(self: *Program, gpa: Allocator) !Exit {
        var pc: usize, var acc: i16 = .{ 0, 0 };
        var bitset: std.bit_set.DynamicBitSetUnmanaged = try .initEmpty(gpa, self.data.len);
        defer bitset.deinit(gpa);

        while (pc < self.data.len) {
            if (bitset.isSet(pc)) {
                return .{ .halt = acc };
            }
            const op = self.data[pc];
            bitset.set(pc);
            switch (op) {
                .acc => |arg| {
                    // std.debug.print("{d:0>2} acc {d}\n", .{ pc, arg });
                    acc += arg;
                    pc += 1;
                },
                .jmp => |arg| {
                    // std.debug.print("{d:0>2} jmp {d}\n", .{ pc, arg });
                    if (arg >= 0) {
                        pc += @intCast(arg);
                    } else {
                        pc -= @intCast(arg * -1);
                    }
                },
                .nop => {
                    // std.debug.print("{d:0>2} nop\n", .{pc});
                    pc += 1;
                },
            }
        }

        return .{ .terminate = acc };
    }

    fn patch(self: *Program, gpa: Allocator) !i16 {
        for (self.data, 0..) |inst, i| {
            switch (inst) {
                .jmp => |arg| {
                    self.data[i] = .{ .nop = arg };
                    switch (try self.run(gpa)) {
                        .halt => {
                            self.data[i] = .{ .jmp = arg };
                        },
                        .terminate => |acc| {
                            return acc;
                        },
                    }
                },
                .nop => |arg| {
                    self.data[i] = .{ .jmp = arg };
                    switch (try self.run(gpa)) {
                        .halt => {
                            self.data[i] = .{ .nop = arg };
                        },
                        .terminate => |acc| {
                            return acc;
                        },
                    }
                },
                .acc => {},
            }
        }
        unreachable;
    }
};

test "part 1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example);
    var program: Program = try .load(gpa, &reader);
    defer program.deinit(gpa);

    const exit = try program.run(gpa);
    try std.testing.expectEqual(5, exit.halt);
}

test "part 2" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example);
    var program: Program = try .load(gpa, &reader);
    defer program.deinit(gpa);

    const acc = try program.patch(gpa);
    try std.testing.expectEqual(8, acc);
}
