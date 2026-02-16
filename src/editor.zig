//! Editor subcommand — opens a file in the appropriate editor.

const std = @import("std");
const detect = @import("detect.zig");
const exec_mod = @import("exec.zig");

/// Runs the editor subcommand.
/// `args` contains the arguments after "editor" (e.g., the file path).
pub fn run(allocator: std.mem.Allocator, args: []const []const u8) noreturn {
    if (args.len == 1 and (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        printUsage();
        std.process.exit(0);
    }

    if (args.len != 1) {
        exec_mod.fatal("usage: navigit editor <file>", .{});
    }

    const file = args[0];

    const argv: []const []const u8 = switch (detect.detectTerminal(allocator)) {
        .vscode => &.{ "code", "--wait", file },
        .vscode_insiders => &.{ "code-insiders", "--wait", file },
        .standalone => blk: {
            const editor_cmd = detect.resolveEditor(allocator) catch |err| {
                exec_mod.fatal("failed to resolve editor: {s}", .{@errorName(err)});
            };
            break :blk &.{ editor_cmd, file };
        },
    };

    exec_mod.execOrExit(allocator, argv);
}

fn printUsage() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("usage: navigit editor <file>\n", .{}) catch {};
    w.interface.flush() catch {};
}
