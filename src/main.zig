//! gitgood — context-aware git tool dispatcher.
//!
//! Parses the first positional argument as a subcommand (`editor`, `diff`,
//! `merge`) and dispatches to the corresponding module.

const std = @import("std");

const diff = @import("diff.zig");
const editor = @import("editor.zig");
const exec_mod = @import("exec.zig");
const merge = @import("merge.zig");

const HelpTopic = enum {
    editor,
    diff,
    merge,
};

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

    if (isGlobalHelpFlag(cmd)) {
        printGlobalHelp();
        return;
    }

    if (std.mem.eql(u8, cmd, "help")) {
        handleHelpCommand(args[2..]);
        return;
    }

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

fn isGlobalHelpFlag(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h");
}

fn handleHelpCommand(args: []const []const u8) void {
    if (args.len == 0) {
        printGlobalHelp();
        return;
    }
    if (args.len != 1) {
        exec_mod.fatal("usage: gitgood help [editor|diff|merge]", .{});
    }

    const topic = parseHelpTopic(args[0]) orelse exec_mod.fatal("invalid help topic: {s}", .{args[0]});
    printCommandHelp(topic);
}

fn parseHelpTopic(arg: []const u8) ?HelpTopic {
    if (std.mem.eql(u8, arg, "editor")) return .editor;
    if (std.mem.eql(u8, arg, "diff")) return .diff;
    if (std.mem.eql(u8, arg, "merge")) return .merge;
    return null;
}

fn globalHelpText() []const u8 {
    return 
    \\gitgood — context-aware git tool dispatcher
    \\
    \\Usage:
    \\    gitgood editor <file>
    \\    gitgood diff <LOCAL> <REMOTE>
    \\    gitgood merge <REMOTE> <LOCAL> <BASE> <MERGED>
    \\    gitgood help [editor|diff|merge]
    \\
    \\Automatically detects VS Code integrated terminal and dispatches
    \\to the appropriate editor or tool.
    \\
    ;
}

fn commandHelpText(topic: HelpTopic) []const u8 {
    return switch (topic) {
        .editor =>
        \\Usage: gitgood editor <file>
        \\
        \\Open a file in VS Code (or configured standalone editor).
        \\
        ,
        .diff =>
        \\Usage: gitgood diff <LOCAL> <REMOTE>
        \\
        \\Open a VS Code visual diff, or run git diff in standalone terminals.
        \\
        ,
        .merge =>
        \\Usage: gitgood merge <REMOTE> <LOCAL> <BASE> <MERGED>
        \\
        \\Open a 3-way merge view and write the result to MERGED.
        \\
        ,
    };
}

fn printGlobalHelp() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("{s}", .{globalHelpText()}) catch {};
    w.interface.flush() catch {};
}

fn printCommandHelp(topic: HelpTopic) void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    w.interface.print("{s}", .{commandHelpText(topic)}) catch {};
    w.interface.flush() catch {};
}

/// Prints usage information to stderr.
fn printUsage() void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    w.interface.print("{s}", .{globalHelpText()}) catch {};
    w.interface.flush() catch {};
}

test "isGlobalHelpFlag recognizes short and long help flags" {
    try std.testing.expect(isGlobalHelpFlag("-h"));
    try std.testing.expect(isGlobalHelpFlag("--help"));
    try std.testing.expect(!isGlobalHelpFlag("help"));
}

test "parseHelpTopic supports known topics and rejects invalid target" {
    try std.testing.expectEqual(@as(?HelpTopic, .editor), parseHelpTopic("editor"));
    try std.testing.expectEqual(@as(?HelpTopic, .diff), parseHelpTopic("diff"));
    try std.testing.expectEqual(@as(?HelpTopic, .merge), parseHelpTopic("merge"));
    try std.testing.expect(parseHelpTopic("invalid") == null);
}

test "globalHelpText includes help command usage line" {
    const text = globalHelpText();
    try std.testing.expect(std.mem.indexOf(u8, text, "Usage:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "gitgood help [editor|diff|merge]") != null);
}

test "commandHelpText includes usage for each subcommand" {
    try std.testing.expect(std.mem.indexOf(u8, commandHelpText(.editor), "Usage: gitgood editor <file>") != null);
    try std.testing.expect(std.mem.indexOf(u8, commandHelpText(.diff), "Usage: gitgood diff <LOCAL> <REMOTE>") != null);
    try std.testing.expect(std.mem.indexOf(u8, commandHelpText(.merge), "Usage: gitgood merge <REMOTE> <LOCAL> <BASE> <MERGED>") != null);
}

test {
    _ = @import("detect.zig");
    _ = @import("editor.zig");
    _ = @import("diff.zig");
    _ = @import("merge.zig");
    _ = @import("exec.zig");
}
