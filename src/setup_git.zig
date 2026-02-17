//! setup-git subcommand for navigit.
//!
//! Configures global git settings so git invokes navigit for editor, diff, and merge.

const std = @import("std");
const exec_mod = @import("exec.zig");

const DIFF_TOOL_VALUE = "navigit";
const MERGE_TOOL_VALUE = "navigit";

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) noreturn {
    if (args.len == 1 and (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        printUsage();
        std.process.exit(0);
    }

    if (args.len != 0) {
        exec_mod.fatal("usage: navigit setup-git", .{});
    }

    setupGlobalGitConfig(allocator);
    printSummary();
    std.process.exit(0);
}

/// Resolves the absolute path of the currently running executable.
fn selfExePath(buf: *[std.fs.max_path_bytes]u8) []const u8 {
    return std.fs.selfExePath(buf) catch |err|
        exec_mod.fatal("failed to resolve self exe path: {s}", .{@errorName(err)});
}

fn setupGlobalGitConfig(allocator: std.mem.Allocator) void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const exe_path = selfExePath(&path_buf);

    // Build config values with the absolute path so git can find navigit
    // even when it's not on $PATH.
    // Single-quote the exe path to prevent shell expansion of $, `, and \
    // when git evaluates these config values via `sh -c`.
    const escaped_exe = shellEscape(allocator, exe_path);
    defer allocator.free(escaped_exe);
    const core_editor_value = std.fmt.allocPrint(allocator, "{s} editor", .{escaped_exe}) catch |err|
        exec_mod.fatal("alloc failed: {s}", .{@errorName(err)});
    defer allocator.free(core_editor_value);
    const difftool_cmd = std.fmt.allocPrint(allocator, "{s} diff \"$LOCAL\" \"$REMOTE\"", .{escaped_exe}) catch |err|
        exec_mod.fatal("alloc failed: {s}", .{@errorName(err)});
    defer allocator.free(difftool_cmd);
    const mergetool_cmd = std.fmt.allocPrint(allocator, "{s} merge \"$REMOTE\" \"$LOCAL\" \"$BASE\" \"$MERGED\"", .{escaped_exe}) catch |err|
        exec_mod.fatal("alloc failed: {s}", .{@errorName(err)});
    defer allocator.free(mergetool_cmd);

    setGlobalConfig(allocator, "core.editor", core_editor_value);
    setGlobalConfig(allocator, "diff.tool", DIFF_TOOL_VALUE);
    setGlobalConfig(allocator, "merge.tool", MERGE_TOOL_VALUE);
    setGlobalConfig(allocator, "difftool.navigit.cmd", difftool_cmd);
    setGlobalConfig(allocator, "mergetool.navigit.cmd", mergetool_cmd);
}

fn setGlobalConfig(allocator: std.mem.Allocator, key: []const u8, value: []const u8) void {
    var argv_buf: [5][]const u8 = undefined;
    const argv = buildSetArgv(key, value, &argv_buf);
    ensureGitSuccess(allocator, argv, "setting", key);
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

fn printSummary() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("configured: core.editor, diff.tool, merge.tool, difftool.navigit.cmd, mergetool.navigit.cmd\n", .{}) catch {};
    w.interface.flush() catch {};
}

/// POSIX single-quote escaping: wraps `input` in single quotes,
/// replacing each embedded `'` with `'\''` so the shell never
/// interprets `$`, backtick, or `\` inside the value.
fn shellEscape(allocator: std.mem.Allocator, input: []const u8) []const u8 {
    // Count single quotes to size the output buffer exactly.
    var quotes: usize = 0;
    for (input) |c| {
        if (c == '\'') quotes += 1;
    }
    // Output: opening ' + body (each ' replaced by 4 chars '\'' minus original 1 = +3) + closing '
    const len = 2 + input.len + quotes * 3;
    const buf = allocator.alloc(u8, len) catch |err|
        exec_mod.fatal("alloc failed: {s}", .{@errorName(err)});
    var i: usize = 0;
    buf[i] = '\'';
    i += 1;
    for (input) |c| {
        if (c == '\'') {
            @memcpy(buf[i..][0..4], "'\\''");
            i += 4;
        } else {
            buf[i] = c;
            i += 1;
        }
    }
    buf[i] = '\'';
    return buf;
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

test "selfExePath returns a non-empty absolute path" {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = selfExePath(&buf);
    try std.testing.expect(path.len > 0);
    try std.testing.expect(std.fs.path.isAbsolute(path));
}

test "formatted config values contain git placeholders" {
    const allocator = std.testing.allocator;
    const exe = "/usr/local/bin/navigit";
    const escaped_exe = shellEscape(allocator, exe);
    defer allocator.free(escaped_exe);
    const diff_cmd = try std.fmt.allocPrint(allocator, "{s} diff \"$LOCAL\" \"$REMOTE\"", .{escaped_exe});
    defer allocator.free(diff_cmd);
    const merge_cmd = try std.fmt.allocPrint(allocator, "{s} merge \"$REMOTE\" \"$LOCAL\" \"$BASE\" \"$MERGED\"", .{escaped_exe});
    defer allocator.free(merge_cmd);
    try std.testing.expect(std.mem.indexOf(u8, diff_cmd, "$LOCAL") != null);
    try std.testing.expect(std.mem.indexOf(u8, diff_cmd, "$REMOTE") != null);
    try std.testing.expect(std.mem.indexOf(u8, merge_cmd, "$REMOTE") != null);
    try std.testing.expect(std.mem.indexOf(u8, merge_cmd, "$LOCAL") != null);
    try std.testing.expect(std.mem.indexOf(u8, merge_cmd, "$BASE") != null);
    try std.testing.expect(std.mem.indexOf(u8, merge_cmd, "$MERGED") != null);
    try std.testing.expect(std.mem.startsWith(u8, diff_cmd, "'" ++ exe ++ "'"));
    try std.testing.expect(std.mem.startsWith(u8, merge_cmd, "'" ++ exe ++ "'"));
}

test "shellEscape" {
    const allocator = std.testing.allocator;

    // Simple path: no special characters
    const simple = shellEscape(allocator, "/usr/bin/foo");
    defer allocator.free(simple);
    try std.testing.expectEqualStrings("'/usr/bin/foo'", simple);

    // Path containing a single quote
    const with_quote = shellEscape(allocator, "/tmp/it's here");
    defer allocator.free(with_quote);
    try std.testing.expectEqualStrings("'/tmp/it'\\''s here'", with_quote);

    // Path with $ — must NOT be expanded inside single quotes
    const with_dollar = shellEscape(allocator, "/home/$USER/bin");
    defer allocator.free(with_dollar);
    try std.testing.expectEqualStrings("'/home/$USER/bin'", with_dollar);
}
