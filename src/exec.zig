//! Process execution helpers.
//!
//! Provides utilities for replacing the current process with another command
//! and for reporting fatal errors to stderr.

const std = @import("std");
const builtin = @import("builtin");

/// Replaces the current process with the given command.
///
/// `argv` is a slice of argument strings where `argv[0]` is the executable name/path.
/// Uses PATH resolution via the underlying implementation.
/// On POSIX this replaces the current process, and on Windows it spawns and waits.
pub fn execOrExit(allocator: std.mem.Allocator, argv: []const []const u8) noreturn {
    if (builtin.os.tag == .windows) {
        var child = std.process.Child.init(argv, allocator);
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
        const term = child.spawnAndWait() catch |err| fatal("exec failed: {s}", .{@errorName(err)});
        switch (term) {
            .Exited => |code| std.process.exit(code),
            else => fatal("process did not exit normally", .{}),
        }
    }

    const err = std.process.execv(allocator, argv);
    fatal("exec failed: {s}", .{@errorName(err)});
}

/// Prints a fatal error message to stderr and exits with code 1.
///
/// Used when exec fails (e.g., command not found).
pub fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    w.interface.print("navigit: " ++ fmt ++ "\n", args) catch {};
    w.interface.flush() catch {};
    std.process.exit(1);
}
