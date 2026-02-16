---
name: validate
description: Runs the full build, test, and format check pipeline for navigit.
---

# Validate Skill

Run the full validation pipeline to ensure the project builds, tests pass, and code is formatted:

```bash
zig build test
```

This single command:
1. Compiles all source files
2. Runs all inline tests (registered via `src/main.zig` test block)
3. Checks formatting with `zig fmt`

If validation fails, report the specific errors and suggest fixes following the project's code style from `AGENTS.md`.
