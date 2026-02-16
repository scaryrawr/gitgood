//! setup-git subcommand for navigit.
//!
//! Configures global git settings so git invokes navigit for editor, diff, and merge.

const std = @import("std");
const exec_mod = @import("exec.zig");

const CORE_EDITOR_VALUE = "navigit editor";
const DIFF_TOOL_VALUE = "navigit";
const MERGE_TOOL_VALUE = "navigit";
const DIFFTOOL_NAVIGIT_CMD = "navigit diff \"$LOCAL\" \"$REMOTE\"";
const MERGETOOL_NAVIGIT_CMD = "navigit merge \"$REMOTE\" \"$LOCAL\" \"$BASE\" \"$MERGED\"";

const Summary = struct {
    created_difftool_cmd: bool = false,
    created_mergetool_cmd: bool = false,
};

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) noreturn {
    if (args.len == 1 and (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        printUsage();
        std.process.exit(0);
    }

    if (args.len != 0) {
        exec_mod.fatal("usage: navigit setup-git", .{});
    }

    const summary = setupGlobalGitConfig(allocator);
    printSummary(summary);
    std.process.exit(0);
}

fn setupGlobalGitConfig(allocator: std.mem.Allocator) Summary {
    setGlobalConfig(allocator, "core.editor", CORE_EDITOR_VALUE);
    setGlobalConfig(allocator, "diff.tool", DIFF_TOOL_VALUE);
    setGlobalConfig(allocator, "merge.tool", MERGE_TOOL_VALUE);

    var summary: Summary = .{};

    if (!hasGlobalConfig(allocator, "difftool.navigit.cmd")) {
        setGlobalConfig(allocator, "difftool.navigit.cmd", DIFFTOOL_NAVIGIT_CMD);
        summary.created_difftool_cmd = true;
    }

    if (!hasGlobalConfig(allocator, "mergetool.navigit.cmd")) {
        setGlobalConfig(allocator, "mergetool.navigit.cmd", MERGETOOL_NAVIGIT_CMD);
        summary.created_mergetool_cmd = true;
    }

    return summary;
}

fn setGlobalConfig(allocator: std.mem.Allocator, key: []const u8, value: []const u8) void {
    var argv_buf: [5][]const u8 = undefined;
    const argv = buildSetArgv(key, value, &argv_buf);
    ensureGitSuccess(allocator, argv, "setting", key);
}

fn hasGlobalConfig(allocator: std.mem.Allocator, key: []const u8) bool {
    var argv_buf: [5][]const u8 = undefined;
    const argv = buildGetArgv(key, &argv_buf);
    const term = runGit(allocator, argv);
    return switch (term) {
        .Exited => |code| switch (code) {
            0 => true,
            1 => false,
            else => exec_mod.fatal("git failed while checking {s} (exit {d})", .{ key, code }),
        },
        else => exec_mod.fatal("git did not exit normally while checking {s}", .{key}),
    };
}

fn ensureGitSuccess(allocator: std.mem.Allocator, argv: []const []const u8, action: []const u8, key: []const u8) void {
    const term = runGit(allocator, argv);
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                exec_mod.fatal("git failed while {s} {s} (exit {d})", .{ action, key, code });
            }
        },
        else => exec_mod.fatal("git did not exit normally while {s} {s}", .{ action, key }),
    }
}

fn runGit(allocator: std.mem.Allocator, argv: []const []const u8) std.process.Child.Term {
    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    return child.spawnAndWait() catch |err| exec_mod.fatal("failed to run git: {s}", .{@errorName(err)});
}

fn buildSetArgv(key: []const u8, value: []const u8, argv_buf: *[5][]const u8) []const []const u8 {
    argv_buf.* = .{ "git", "config", "--global", key, value };
    return argv_buf[0..5];
}

fn buildGetArgv(key: []const u8, argv_buf: *[5][]const u8) []const []const u8 {
    argv_buf.* = .{ "git", "config", "--global", "--get", key };
    return argv_buf[0..5];
}

fn createdSummaryText(summary: Summary) []const u8 {
    if (summary.created_difftool_cmd and summary.created_mergetool_cmd) {
        return "created: difftool.navigit.cmd, mergetool.navigit.cmd\n";
    }
    if (summary.created_difftool_cmd) {
        return "created: difftool.navigit.cmd\n";
    }
    if (summary.created_mergetool_cmd) {
        return "created: mergetool.navigit.cmd\n";
    }
    return "created: none (existing tool command definitions kept)\n";
}

fn printSummary(summary: Summary) void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("configured: core.editor, diff.tool, merge.tool\n", .{}) catch {};
    w.interface.print("{s}", .{createdSummaryText(summary)}) catch {};
    w.interface.flush() catch {};
}

fn printUsage() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("usage: navigit setup-git\n", .{}) catch {};
    w.interface.flush() catch {};
}

test "buildSetArgv uses git config --global key value" {
    var argv_buf: [5][]const u8 = undefined;
    const argv = buildSetArgv("core.editor", "navigit editor", &argv_buf);
    try std.testing.expectEqualStrings("git", argv[0]);
    try std.testing.expectEqualStrings("config", argv[1]);
    try std.testing.expectEqualStrings("--global", argv[2]);
    try std.testing.expectEqualStrings("core.editor", argv[3]);
    try std.testing.expectEqualStrings("navigit editor", argv[4]);
}

test "buildGetArgv uses git config --global --get key" {
    var argv_buf: [5][]const u8 = undefined;
    const argv = buildGetArgv("difftool.navigit.cmd", &argv_buf);
    try std.testing.expectEqualStrings("git", argv[0]);
    try std.testing.expectEqualStrings("config", argv[1]);
    try std.testing.expectEqualStrings("--global", argv[2]);
    try std.testing.expectEqualStrings("--get", argv[3]);
    try std.testing.expectEqualStrings("difftool.navigit.cmd", argv[4]);
}

test "generated tool command strings preserve git placeholders" {
    try std.testing.expectEqualStrings("navigit diff \"$LOCAL\" \"$REMOTE\"", DIFFTOOL_NAVIGIT_CMD);
    try std.testing.expectEqualStrings("navigit merge \"$REMOTE\" \"$LOCAL\" \"$BASE\" \"$MERGED\"", MERGETOOL_NAVIGIT_CMD);
}

test "createdSummaryText reports no created definitions" {
    const summary: Summary = .{};
    try std.testing.expectEqualStrings("created: none (existing tool command definitions kept)\n", createdSummaryText(summary));
}

test "createdSummaryText reports both created definitions" {
    const summary: Summary = .{
        .created_difftool_cmd = true,
        .created_mergetool_cmd = true,
    };
    try std.testing.expectEqualStrings("created: difftool.navigit.cmd, mergetool.navigit.cmd\n", createdSummaryText(summary));
}
