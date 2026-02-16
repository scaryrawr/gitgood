//! Diff subcommand for gitgood.
//!
//! Uses VS Code's visual diff in integrated terminals and `git diff`
//! in standalone terminals.

const std = @import("std");
const detect = @import("detect.zig");
const exec_mod = @import("exec.zig");

/// Runs the diff subcommand.
/// `args` contains the arguments after "diff" (LOCAL and REMOTE file paths).
pub fn run(args: []const []const u8) noreturn {
    if (args.len == 1 and (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        printUsage();
        std.process.exit(0);
    }

    if (args.len != 2) {
        exec_mod.fatal("expected 2 arguments (LOCAL, REMOTE), got {d}", .{args.len});
    }

    const local = args[0];
    const remote = args[1];

    var argv_buf: [7][]const u8 = undefined;
    const argv = buildArgv(detect.detectTerminal(std.heap.page_allocator), local, remote, &argv_buf);

    exec_mod.execOrExit(std.heap.page_allocator, argv);
}

fn buildArgv(term: detect.Terminal, local: []const u8, remote: []const u8, argv_buf: *[7][]const u8) []const []const u8 {
    return switch (term) {
        .vscode => blk: {
            argv_buf.* = .{ "code", "--wait", "--diff", local, remote, "", "" };
            break :blk argv_buf[0..5];
        },
        .vscode_insiders => blk: {
            argv_buf.* = .{ "code-insiders", "--wait", "--diff", local, remote, "", "" };
            break :blk argv_buf[0..5];
        },
        .standalone => blk: {
            argv_buf.* = .{ "git", "--no-pager", "diff", "--no-index", "--", local, remote };
            break :blk argv_buf[0..7];
        },
    };
}

fn printUsage() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("usage: gitgood diff <LOCAL> <REMOTE>\n", .{}) catch {};
    w.interface.flush() catch {};
}

test "buildArgv keeps VS Code diff behavior" {
    var argv_buf: [7][]const u8 = undefined;
    const argv = buildArgv(.vscode, "LOCAL", "REMOTE", &argv_buf);
    try std.testing.expectEqualStrings("code", argv[0]);
    try std.testing.expectEqualStrings("--wait", argv[1]);
    try std.testing.expectEqualStrings("--diff", argv[2]);
    try std.testing.expectEqualStrings("LOCAL", argv[3]);
    try std.testing.expectEqualStrings("REMOTE", argv[4]);
}

test "buildArgv uses git diff in standalone terminals" {
    var argv_buf: [7][]const u8 = undefined;
    const argv = buildArgv(.standalone, "LOCAL", "REMOTE", &argv_buf);
    try std.testing.expectEqualStrings("git", argv[0]);
    try std.testing.expectEqualStrings("--no-pager", argv[1]);
    try std.testing.expectEqualStrings("diff", argv[2]);
    try std.testing.expectEqualStrings("--no-index", argv[3]);
    try std.testing.expectEqualStrings("--", argv[4]);
    try std.testing.expectEqualStrings("LOCAL", argv[5]);
    try std.testing.expectEqualStrings("REMOTE", argv[6]);
}
