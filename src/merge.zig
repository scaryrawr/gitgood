//! Merge subcommand for gitgood.
//!
//! Opens a 3-way merge view in VS Code or a standalone editor,
//! depending on the detected terminal environment.

const std = @import("std");
const detect = @import("detect.zig");
const exec_mod = @import("exec.zig");

/// Runs the merge subcommand.
/// `args` contains the arguments after "merge" (REMOTE, LOCAL, BASE, MERGED file paths).
pub fn run(args: []const []const u8) noreturn {
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

    const argv: []const []const u8 = switch (detect.detectTerminal()) {
        .vscode => &.{ "code", "--wait", "--merge", remote, local, base, merged },
        .vscode_insiders => &.{ "code-insiders", "--wait", "--merge", remote, local, base, merged },
        .standalone => &.{ detect.resolveEditor(), "-d", merged, local, remote },
    };

    const err = exec_mod.exec(argv);
    exec_mod.fatal("exec failed: {s}", .{@errorName(err)});
}

fn printUsage() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("usage: gitgood merge <REMOTE> <LOCAL> <BASE> <MERGED>\n", .{}) catch {};
    w.interface.flush() catch {};
}
