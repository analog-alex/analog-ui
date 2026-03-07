# Repository Guidelines

## Project Structure & Module Organization
This repository is a Zig package centered on `analog_ui`.

- `src/main.zig`: executable entry point (current app runner).
- `src/root.zig`: library root and unit tests for public module code.
- `build.zig`: build graph, app/run/test steps, install behavior.
- `build.zig.zon`: package metadata (`minimum_zig_version = 0.15.1`).
- `docs/`: design and architecture notes (for example `docs/clay_sdl3_zig_design.md`).
- `zig-out/` and `.zig-cache/`: generated artifacts/cache; do not edit manually.

Keep new modules under `src/` and expose reusable APIs via `src/root.zig`.

## Build, Test, and Development Commands
Use Zig tooling directly from repo root:

- `zig build`: compile and install artifacts to `zig-out/`.
- `zig build run`: build and run the executable (`src/main.zig`).
- `zig build test`: run all test targets defined in `build.zig`.
- `zig fmt src/**/*.zig build.zig`: format Zig sources consistently.
- `zig build -Doptimize=ReleaseSafe`: build in release-safe mode.

## Coding Style & Naming Conventions
- Use standard Zig formatting (`zig fmt`) before committing.
- Indentation: 4 spaces (as produced by `zig fmt`).
- Types and files: `snake_case` (for example `draw_list.zig`).
- Functions/variables: `camelCase` (for example `bufferedPrint`).
- Prefer explicit error unions (`!T`) and allocator-forward APIs.
- Keep `main.zig` thin; move reusable logic to library modules.

## Testing Guidelines
- Put unit tests inline using Zig `test` blocks (see `src/root.zig`).
- Name tests descriptively, e.g. `test "add returns sum for positive ints"`.
- Run `zig build test` locally before opening a PR.
- Add tests for every bug fix and new public API behavior.

## Commit & Pull Request Guidelines
Git history is not available in this workspace snapshot, so use this convention:

- Commit format: `type(scope): imperative summary`  
  Example: `feat(font): add glyph atlas cache`.
- Keep commits focused and logically grouped.
- PRs should include: purpose, key changes, test evidence (`zig build test` output), and screenshots/logs for UI-visible changes.
- Link related issues/tasks and call out any breaking API changes explicitly.
