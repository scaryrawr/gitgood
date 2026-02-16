# Copilot Instructions

## Project Overview

**navigit** is a context-aware git tool dispatcher written in Zig. It detects whether the user is inside a VS Code integrated terminal (Stable or Insiders) or a standalone terminal, then dispatches `editor`, `diff`, and `merge` subcommands to the appropriate tool (`code`, `code-insiders`, or `$EDITOR`/`vi`).

### Architecture

```
src/
├── main.zig     — Entry point: parses subcommands/help and dispatches to modules
├── detect.zig   — Terminal detection (VS Code vs standalone) and editor resolution
├── editor.zig   — "editor" subcommand: opens a file in the detected editor
├── diff.zig     — "diff" subcommand: opens a visual diff between two files
├── merge.zig    — "merge" subcommand: opens a 3-way merge view
├── setup_git.zig — "setup-git" subcommand: configures global git tool integration
└── exec.zig     — Process execution helpers (execv wrapper, fatal error reporting)
```

The dispatch pattern is consistent: `editor`, `diff`, and `merge` export `run(allocator, args) noreturn`, build argv from `detect.detectTerminal()`, then call `exec_mod.exec()`. `setup-git` also exports `run(allocator, args) noreturn`, but executes `git config --global` commands via `std.process.Child`.

## Build, Test, and Lint

```bash
# Build
zig build

# Run
zig build run -- <subcommand> [args...]

# Run all tests (includes zig fmt check)
zig build test

# Run a single test by name
zig build test -- --test-filter "test name"

# Format check only
zig fmt --check src/ build.zig build.zig.zon

# Auto-format
zig fmt src/ build.zig build.zig.zon
```

Tests are inline in each source file and registered via `src/main.zig`'s top-level `test` block. The build system also runs `zig fmt` as part of the test step.

## Code Style

Follow the conventions documented in `AGENTS.md`. Key points:

- **Naming:** `camelCase` functions, `snake_case` variables, `PascalCase` types, `SCREAMING_SNAKE_CASE` constants
- **Struct init:** Prefer `const foo: Type = .{ ... };` over `const foo = Type{ ... };`
- **File structure:** `//!` doc comment → imports (`std` → `builtin` → project) → public API → private helpers
- **Method order:** `init` → `deinit` → public API → private helpers
- **Memory:** Pass allocators explicitly, use `errdefer` for cleanup
- **Docs:** `///` for public API, `//` for implementation notes. Explain *why*, not *what*.
- **Tests:** Inline in the same file, register in `src/main.zig` test block
- **Function size:** Soft limit of 70 lines; centralize control flow in parent functions
- **Assertions:** Focus on API boundaries and state transitions, not trivially true statements

## Path-Specific Guidance

### `src/`

- Keep CLI routing and help text centralized in `src/main.zig`; when adding a subcommand, update dispatch, help topic parsing, and help usage strings together.
- Subcommand modules should expose `pub fn run(allocator: std.mem.Allocator, args: []const []const u8) noreturn`.
- Preserve cross-platform behavior by following existing patterns in `detect.zig` and `exec.zig` (notably OS guards and process execution behavior).

### `.github/workflows/`

- CI should continue using `zig build test` as the canonical validation step because it runs both tests and `zig fmt` checks.

## API Discovery

Always use `zigdoc` to discover APIs for the Zig standard library and dependencies:

```bash
zigdoc std.fs
zigdoc std.process
zigdoc std.mem
```

## Adding a New Subcommand

1. Create `src/<name>.zig` with a `pub fn run(allocator: std.mem.Allocator, args: []const []const u8) noreturn` function
2. Follow the dispatch pattern: build argv based on `detect.detectTerminal()`, call `exec_mod.exec()`
3. Import and dispatch in `src/main.zig`
4. Add `_ = @import("<name>.zig");` to the test block in `src/main.zig`
5. Add inline tests in the new file
