//! gitgood — context-aware git tool dispatcher.
//!
//! Parses the first positional argument as a subcommand (`editor`, `diff`,
//! `merge`) and dispatches to the corresponding module.

const std = @import("std");

const diff = @import("diff.zig");
const editor = @import("editor.zig");
const exec_mod = @import("exec.zig");
const merge = @import("merge.zig");

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    if (args.len < 2) {
        printUsage();
        std.process.exit(1);
    }

    const cmd = args[1];
    const cmd_args = args[2..];

    if (std.mem.eql(u8, cmd, "editor")) {
        editor.run(cmd_args);
    } else if (std.mem.eql(u8, cmd, "diff")) {
        diff.run(cmd_args);
    } else if (std.mem.eql(u8, cmd, "merge")) {
        merge.run(cmd_args);
    } else {
        exec_mod.fatal("unknown command: {s}", .{cmd});
    }
}

/// Prints usage information to stderr.
fn printUsage() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    w.interface.print(
        \\gitgood — context-aware git tool dispatcher
        \\
        \\Usage:
        \\    gitgood editor <file>
        \\    gitgood diff <LOCAL> <REMOTE>
        \\    gitgood merge <REMOTE> <LOCAL> <BASE> <MERGED>
        \\
        \\Automatically detects VS Code integrated terminal and dispatches
        \\to the appropriate editor or tool.
        \\
    , .{}) catch {};
    w.interface.flush() catch {};
}

test {
    _ = @import("detect.zig");
    _ = @import("editor.zig");
    _ = @import("diff.zig");
    _ = @import("merge.zig");
    _ = @import("exec.zig");
}
