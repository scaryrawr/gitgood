//! Merge subcommand for gitgood.
//!
//! Opens a 3-way merge view in VS Code or a standalone editor,
//! depending on the detected terminal environment.

const std = @import("std");
const detect = @import("detect.zig");
const exec_mod = @import("exec.zig");

/// Runs the merge subcommand.
/// `args` contains the arguments after "merge" (REMOTE, LOCAL, BASE, MERGED file paths).
pub fn run(allocator: std.mem.Allocator, args: []const []const u8) noreturn {
    if (args.len == 1 and (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        printUsage();
        std.process.exit(0);
    }

    if (args.len != 4) {
        exec_mod.fatal("usage: gitgood merge <REMOTE> <LOCAL> <BASE> <MERGED>", .{});
    }

    const remote = args[0];
    const local = args[1];
    const base = args[2];
    const merged = args[3];

    const argv: []const []const u8 = switch (detect.detectTerminal(allocator)) {
        .vscode => &.{ "code", "--wait", "--merge", remote, local, base, merged },
        .vscode_insiders => &.{ "code-insiders", "--wait", "--merge", remote, local, base, merged },
        .standalone => blk: {
            const editor_cmd = detect.resolveEditor(allocator) catch |err| {
                exec_mod.fatal("failed to resolve editor: {s}", .{@errorName(err)});
            };
            break :blk &.{ editor_cmd, "-d", merged, local, remote };
        },
    };

    exec_mod.execOrExit(allocator, argv);
}

fn printUsage() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("usage: gitgood merge <REMOTE> <LOCAL> <BASE> <MERGED>\n", .{}) catch {};
    w.interface.flush() catch {};
}
