//! Environment detection for gitgood.
//!
//! Detects whether the user is running inside VS Code's integrated terminal
//! or a standalone terminal, and resolves which editor to launch for diffs.

const std = @import("std");

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
pub fn detectTerminal() Terminal {
    const term_program = std.posix.getenvZ("TERM_PROGRAM") orelse return .standalone;

    if (std.mem.eql(u8, term_program, "vscode-insiders")) return .vscode_insiders;
    if (std.mem.eql(u8, term_program, "vscode")) {
        return if (isExecutableOnPath("code-insiders")) .vscode_insiders else .vscode;
    }

    return .standalone;
}

/// Checks whether an executable with the given `name` exists in any
/// directory listed in the `PATH` environment variable.
pub fn isExecutableOnPath(name: []const u8) bool {
    const path_env = std.posix.getenvZ("PATH") orelse return false;
    var it = std.mem.tokenizeScalar(u8, path_env, ':');
    while (it.next()) |dir_path| {
        var dir = std.fs.cwd().openDir(dir_path, .{}) catch continue;
        defer dir.close();
        dir.access(name, .{}) catch continue;
        return true;
    }
    return false;
}

/// Resolves the editor command for standalone terminal mode.
/// Checks `$EDITOR`, then `$VISUAL`, then falls back to `"vi"` so
/// there is always a usable command even on minimal systems.
pub fn resolveEditor() [:0]const u8 {
    return std.posix.getenvZ("EDITOR") orelse
        std.posix.getenvZ("VISUAL") orelse
        "vi";
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
    const editor_cmd = resolveEditor();
    try std.testing.expect(editor_cmd.len > 0);
}

test "isExecutableOnPath finds a known executable" {
    // "zig" must be on PATH for us to be running this test.
    try std.testing.expect(isExecutableOnPath("zig"));
}

test "isExecutableOnPath returns false for a nonsense name" {
    try std.testing.expect(!isExecutableOnPath("this-executable-definitely-does-not-exist-xyz"));
}
