# navigit

`navigit` is a context-aware Git tool dispatcher written in Zig.

It detects whether you’re running inside a VS Code integrated terminal and routes common Git “tool” entrypoints (editor, difftool, mergetool) to:

- VS Code (`code` or `code-insiders`) when you’re in the VS Code terminal
- Your standalone `$EDITOR`/`$VISUAL` (fallback: `vi`) when you’re not

## Requirements

- Zig (this repo is currently built with Zig 0.15.2)
- Git
- Optional (recommended): VS Code and the `code`/`code-insiders` shell command on your `PATH`

To install the VS Code shell command: in VS Code, open the Command Palette and run “Shell Command: Install 'code' command in PATH”.

## Quick start

Build and install into the repo’s default prefix (`zig-out/`):

```bash
zig build -Doptimize=ReleaseSafe

# binary will be at:
#   ./zig-out/bin/navigit
```

Optionally install to a custom prefix (example: `~/.local/bin`):

```bash
zig build -Doptimize=ReleaseSafe -p ~/.local install
```

Then configure Git to use `navigit` globally:

```bash
navigit setup-git
```

After that:

- `git commit` will use `navigit editor ...` (which opens VS Code in the VS Code terminal, otherwise `$EDITOR`)
- `git difftool` will use `navigit diff ...`
- `git mergetool` will use `navigit merge ...`

## Usage

```text
navigit editor <file>
navigit diff <LOCAL> <REMOTE>
navigit merge <REMOTE> <LOCAL> <BASE> <MERGED>
navigit setup-git
navigit help [editor|diff|merge|setup-git]
```

## Configuration

### 1) Standalone editor selection

When you’re not in a VS Code integrated terminal, `navigit` uses:

1. `$EDITOR`
2. `$VISUAL`
3. `vi` (fallback)

Note: on Windows, this fallback is still `vi`; set `EDITOR` or `VISUAL` if `vi` is not available.

Example:

```bash
export EDITOR=vim
```

### 2) Git configuration (`navigit setup-git`)

`navigit setup-git` applies these global Git settings:

- `core.editor = navigit editor`
- `diff.tool = navigit`
- `merge.tool = navigit`

And it will create these tool command definitions only if they don’t already exist:

- `difftool.navigit.cmd = navigit diff "$LOCAL" "$REMOTE"`
- `mergetool.navigit.cmd = navigit merge "$REMOTE" "$LOCAL" "$BASE" "$MERGED"`

To inspect what was set:

```bash
git config --global --get core.editor
git config --global --get diff.tool
git config --global --get merge.tool
git config --global --get difftool.navigit.cmd
git config --global --get mergetool.navigit.cmd
```

To undo (example):

```bash
git config --global --unset core.editor
git config --global --unset diff.tool
git config --global --unset merge.tool
# and optionally:
git config --global --unset difftool.navigit.cmd
git config --global --unset mergetool.navigit.cmd
```

## How dispatch works

### Terminal detection

`navigit` detects VS Code by reading `TERM_PROGRAM`:

- `TERM_PROGRAM=vscode` → VS Code mode
- `TERM_PROGRAM=vscode-insiders` → VS Code Insiders mode
- otherwise → standalone mode

If `TERM_PROGRAM=vscode`, it further checks whether `code-insiders` is on `PATH`; if so, it assumes Insiders.

On POSIX, `navigit` uses process replacement (`exec`); on Windows, it spawns the target process and exits with that child process’s status code.

### Subcommands

- `editor`:
  - VS Code: `code --wait <file>`
  - standalone: `$EDITOR <file>`

- `diff`:
  - VS Code: `code --wait --diff <LOCAL> <REMOTE>`
  - standalone: `git --no-pager diff --no-index -- <LOCAL> <REMOTE>`

- `merge`:
  - VS Code: `code --wait --merge <REMOTE> <LOCAL> <BASE> <MERGED>`
  - standalone: `$EDITOR -d <MERGED> <LOCAL> <REMOTE>`

## Development

```bash
# Run tests (also runs zig fmt check via the build)
zig build test

# Format check only
zig fmt --check src/ build.zig build.zig.zon
```
