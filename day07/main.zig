const std = @import("std");
const example = @embedFile("example.txt");
const example2 = @embedFile("example2.txt");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "day07/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    const gpa = init.gpa;
    var buf: [4096]u8 = undefined;
    var reader = input_file.reader(io, &buf);
    var ruleset: RuleSet = try .initParse(gpa, &reader.interface);
    defer ruleset.deinit(gpa);

    const answer_p1 = try ruleset.countContainers(gpa, "shiny gold");
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    const answer_p2 = try ruleset.countItems(gpa, "shiny gold");
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

const RuleSet = struct {
    rules: RuleMap = .empty,

    const RuleMap = std.hash_map.StringHashMapUnmanaged(std.ArrayListUnmanaged(Content));
    const Content = struct {
        qty: u32,
        colour: []const u8,
    };

    fn initParse(gpa: Allocator, reader: *Reader) !RuleSet {
        var self: RuleSet = .{};
        errdefer self.deinit(gpa);

        var rules = &self.rules;
        outer: while (reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
            error.EndOfStream => null,
            else => return err,
        }) |line| {
            if (line.len == 0) break;
            // std.debug.print("{s}", .{line});
            var it = std.mem.tokenizeAny(u8, line[0 .. line.len - 1], " ,.");
            const container_colour = blk: {
                const variation = it.next() orelse continue;
                const colour_name = it.next() orelse continue;
                const colour: []const u8 = try std.fmt.allocPrint(gpa, "{s} {s}", .{ variation, colour_name });
                errdefer gpa.free(colour);

                const res = try rules.getOrPut(gpa, colour);
                if (res.found_existing) gpa.free(colour);
                res.value_ptr.* = .empty;
                break :blk res.key_ptr.*;
            };
            // std.debug.print("colour={s}\n", .{container_colour});
            _ = it.next(); // bags
            _ = it.next(); // contain

            while (it.next()) |qtytok| {
                if (std.mem.eql(u8, "no", qtytok)) continue :outer;
                const qty = try std.fmt.parseInt(u32, qtytok, 10);

                const item_colour = blk: {
                    const variation = it.next() orelse continue :outer;
                    const colour_name = it.next() orelse continue :outer;
                    const colour: []const u8 = try std.fmt.allocPrint(gpa, "{s} {s}", .{ variation, colour_name });
                    errdefer gpa.free(colour);

                    const res = try rules.getOrPut(gpa, colour);
                    if (res.found_existing) {
                        gpa.free(colour);
                    } else {
                        res.value_ptr.* = .empty;
                    }
                    break :blk res.key_ptr.*;
                };

                if (rules.getPtr(container_colour)) |list| {
                    try list.append(gpa, .{ .qty = qty, .colour = item_colour });
                }
                _ = it.next(); // bag or bags
                // std.debug.print("=> contains {d} {s} bag(s)\n", .{ qty, item_colour });
            }
        }
        return self;
    }

    fn countContainers(self: *RuleSet, gpa: Allocator, target: []const u8) !u32 {
        var containers: std.StringHashMapUnmanaged(void) = .empty;
        defer containers.deinit(gpa);

        var queue: std.ArrayListUnmanaged([]const u8) = .empty;
        defer queue.deinit(gpa);
        try queue.append(gpa, target);

        var head: usize = 0;
        while (head < queue.items.len) : (head += 1) {
            const colour = queue.items[head];
            var it = self.rules.iterator();
            while (it.next()) |entry| {
                for (entry.value_ptr.items) |item| {
                    if (std.mem.eql(u8, item.colour, colour)) {
                        const container_colour = entry.key_ptr.*;
                        if (try containers.fetchPut(gpa, container_colour, {})) |_| continue;
                        try queue.append(gpa, container_colour);
                    }
                }
            }
        }

        return containers.count();
    }

    fn countItems(self: *RuleSet, gpa: Allocator, target: []const u8) !u32 {
        var dfs: std.ArrayListUnmanaged(Content) = .empty;
        defer dfs.deinit(gpa);

        if (self.rules.get(target)) |list| {
            try dfs.appendSlice(gpa, list.items);
        }

        var total: u32 = 0;
        while (dfs.pop()) |state| {
            total += state.qty;
            if (self.rules.get(state.colour)) |list| {
                try dfs.ensureUnusedCapacity(gpa, list.items.len);
                for (list.items) |item| {
                    dfs.appendAssumeCapacity(.{ .qty = state.qty * item.qty, .colour = item.colour });
                }
            }
        }
        return total;
    }

    fn deinit(self: *RuleSet, gpa: Allocator) void {
        var it = self.rules.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(gpa);
            gpa.free(entry.key_ptr.*);
        }
        self.rules.deinit(gpa);
        self.* = undefined;
    }
};

test "part 1" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example);
    var ruleset: RuleSet = try .initParse(gpa, &reader);
    defer ruleset.deinit(gpa);
    try std.testing.expectEqual(4, ruleset.countContainers(gpa, "shiny gold"));
}

test "part 2" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example);
    var ruleset: RuleSet = try .initParse(gpa, &reader);
    defer ruleset.deinit(gpa);
    try std.testing.expectEqual(32, ruleset.countItems(gpa, "shiny gold"));
}

test "part 2 chain example" {
    const gpa = std.testing.allocator;
    var reader: Reader = .fixed(example2);
    var ruleset: RuleSet = try .initParse(gpa, &reader);
    defer ruleset.deinit(gpa);
    try std.testing.expectEqual(126, ruleset.countItems(gpa, "shiny gold"));
}
