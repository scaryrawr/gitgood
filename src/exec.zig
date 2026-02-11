//! Process execution helpers.
//!
//! Provides utilities for replacing the current process with another command
//! and for reporting fatal errors to stderr.

const std = @import("std");

pub const ExecError = std.process.ExecvError;

/// Replaces the current process with the given command.
///
/// `argv` is a slice of argument strings where `argv[0]` is the executable name/path.
/// Uses PATH resolution via the underlying `execvpe` implementation.
/// On success, this function never returns (the process is replaced).
/// On failure, returns an error.
pub fn exec(argv: []const []const u8) ExecError {
    return std.process.execv(std.heap.page_allocator, argv);
}

/// Prints a fatal error message to stderr and exits with code 1.
///
/// Used when exec fails (e.g., command not found).
pub fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    w.interface.print("gitgood: " ++ fmt ++ "\n", args) catch {};
    w.interface.flush() catch {};
    std.process.exit(1);
}

test "ExecError is a valid error set" {
    const E = ExecError;
    _ = E;
}
