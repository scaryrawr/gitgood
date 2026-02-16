//! Environment detection for gitgood.
//!
//! Detects whether the user is running inside VS Code's integrated terminal
//! or a standalone terminal, and resolves which editor to launch for diffs.

const std = @import("std");
const builtin = @import("builtin");

pub const Terminal = enum {
    vscode,
    vscode_insiders,
    standalone,
};

/// Returns the detected terminal type by inspecting `TERM_PROGRAM`.
///
/// Both VS Code Stable and Insiders set `TERM_PROGRAM` to `"vscode"`,
/// so the value alone is not enough to distinguish them. When we see
/// `"vscode"`, we disambiguate by checking whether `code-insiders` is
/// on `PATH` — if it is, we assume Insiders is the active installation.
///
/// The `"vscode-insiders"` check is kept as a fast-path in case a
/// future VS Code release starts setting a distinct value.
pub fn detectTerminal(allocator: std.mem.Allocator) Terminal {
    const term_program = std.process.getEnvVarOwned(allocator, "TERM_PROGRAM") catch return .standalone;
    defer allocator.free(term_program);

    if (std.mem.eql(u8, term_program, "vscode-insiders")) return .vscode_insiders;
    if (std.mem.eql(u8, term_program, "vscode")) {
        return if (isExecutableOnPath(allocator, "code-insiders")) .vscode_insiders else .vscode;
    }

    return .standalone;
}

/// Checks whether an executable with the given `name` exists in any
/// directory listed in the `PATH` environment variable.
pub fn isExecutableOnPath(allocator: std.mem.Allocator, name: []const u8) bool {
    const path_env = std.process.getEnvVarOwned(allocator, "PATH") catch return false;
    defer allocator.free(path_env);

    var it = std.mem.tokenizeScalar(u8, path_env, std.fs.path.delimiter);
    while (it.next()) |dir_path| {
        var dir = std.fs.cwd().openDir(dir_path, .{}) catch continue;
        defer dir.close();

        if (dir.access(name, .{})) |_| {
            return true;
        } else |_| {}

        if (builtin.os.tag == .windows) {
            const suffixes = [_][]const u8{ ".exe", ".cmd", ".bat" };
            for (suffixes) |suffix| {
                var candidate_buf: [512]u8 = undefined;
                const candidate = std.fmt.bufPrint(&candidate_buf, "{s}{s}", .{ name, suffix }) catch continue;
                if (dir.access(candidate, .{})) |_| {
                    return true;
                } else |_| {}
            }
        }
    }
    return false;
}

/// Resolves the editor command for standalone terminal mode.
/// Checks `$EDITOR`, then `$VISUAL`, then falls back to `"vi"` so
/// there is always a usable command even on minimal systems.
pub fn resolveEditor(allocator: std.mem.Allocator) ![]const u8 {
    return std.process.getEnvVarOwned(allocator, "EDITOR") catch |editor_err| switch (editor_err) {
        error.EnvironmentVariableNotFound => std.process.getEnvVarOwned(allocator, "VISUAL") catch |visual_err| switch (visual_err) {
            error.EnvironmentVariableNotFound => try allocator.dupe(u8, "vi"),
            else => visual_err,
        },
        else => editor_err,
    };
}

test "Terminal enum has expected variants" {
    const t: Terminal = .standalone;
    try std.testing.expect(t == .standalone);
    const v: Terminal = .vscode;
    try std.testing.expect(v == .vscode);
    const vi: Terminal = .vscode_insiders;
    try std.testing.expect(vi == .vscode_insiders);
}

test "resolveEditor returns a non-empty string" {
    const editor_cmd = try resolveEditor(std.testing.allocator);
    defer std.testing.allocator.free(editor_cmd);
    try std.testing.expect(editor_cmd.len > 0);
}

test "isExecutableOnPath finds a known executable" {
    // "zig" must be on PATH for us to be running this test.
    try std.testing.expect(isExecutableOnPath(std.testing.allocator, "zig"));
}

test "isExecutableOnPath returns false for a nonsense name" {
    try std.testing.expect(!isExecutableOnPath(std.testing.allocator, "this-executable-definitely-does-not-exist-xyz"));
}
