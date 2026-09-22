#!/usr/bin/env bash

for path in $(seq -f 'day%02g' 1 25); do
  mkdir -p "${path}"
  [ ! -f "${path}/main.zig" ] && cat <<-EOF > "${path}/main.zig"
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input = "$path/input.txt";
    var input_file = std.Io.Dir.cwd().openFile(io, input, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file " ++ input ++ " is missing"),
        else => std.debug.panic("{any}", .{err}),
    };
    defer input_file.close(io);

    try stdout.print("All your {s} are belong to us.\n", .{"codebase"});
    try stdout.flush();
}

test "part 1" {
    return error.SkipZigTest;
}

test "part 2" {
    return error.SkipZigTest;
}
EOF
  zig fmt "$path/main.zig"

  echo 'pub const '"$path"' = @import("'"$path"'/main.zig");' >> main.zig
done

cat <<-EOF >> main.zig

test {
    @import("std").testing.refAllDecls(@This());
}
EOF
zig fmt main.zig
