//! Diff subcommand — opens a visual diff between two files.

const detect = @import("detect.zig");
const exec_mod = @import("exec.zig");

/// Runs the diff subcommand.
/// `args` contains the arguments after "diff" (LOCAL and REMOTE file paths).
pub fn run(args: []const []const u8) noreturn {
    if (args.len != 2) {
        exec_mod.fatal("expected 2 arguments (LOCAL, REMOTE), got {d}", .{args.len});
    }

    const local = args[0];
    const remote = args[1];

    const argv: []const []const u8 = switch (detect.detectTerminal()) {
        .vscode => &.{ "code", "--wait", "--diff", local, remote },
        .vscode_insiders => &.{ "code-insiders", "--wait", "--diff", local, remote },
        .standalone => &.{ detect.resolveEditor(), "-d", local, remote },
    };

    const err = exec_mod.exec(argv);
    exec_mod.fatal("exec failed: {s}", .{@errorName(err)});
}
