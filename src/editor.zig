//! Editor subcommand — opens a file in the appropriate editor.

const std = @import("std");
const detect = @import("detect.zig");
const exec_mod = @import("exec.zig");

/// Runs the editor subcommand.
/// `args` contains the arguments after "editor" (e.g., the file path).
pub fn run(args: []const []const u8) noreturn {
    if (args.len == 1 and (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        printUsage();
        std.process.exit(0);
    }

    if (args.len != 1) {
        exec_mod.fatal("usage: gitgood editor <file>", .{});
    }

    const file = args[0];

    const argv: []const []const u8 = switch (detect.detectTerminal()) {
        .vscode => &.{ "code", "--wait", file },
        .vscode_insiders => &.{ "code-insiders", "--wait", file },
        .standalone => &.{ detect.resolveEditor(), file },
    };

    const err = exec_mod.exec(argv);
    exec_mod.fatal("exec failed: {s}", .{@errorName(err)});
}

fn printUsage() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("usage: gitgood editor <file>\n", .{}) catch {};
    w.interface.flush() catch {};
}
