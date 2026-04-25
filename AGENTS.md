# AGENTS.md

## Scope
This file is for coding agents working in `/Users/miguelalexandre/Documents/zig/analog-ui`.
Target Zig version: `0.16.0` from `build.zig.zon`.

Current external agent-rule files:
- No `.cursor/rules/` files were found.
- No `.cursorrules` file was found.
- No `.github/copilot-instructions.md` file was found.

If any of those files are added later, treat them as additional repository instructions.

## Repository Overview
This repository is a Zig package named `analog_ui`.
Key paths:
- `build.zig`: canonical build graph, executable wiring, test steps, and `window_demo` option.
- `build.zig.zon`: package metadata and dependency declarations.
- `src/root.zig`: public library root; re-exports package API.
- `src/main.zig`: executable entry point; switches between headless and window demo.
- `src/core/`: backend-neutral UI state, layout translation, widgets.
- `src/font/`: TTF loading, rasterization, glyph cache, atlas, UTF-8 helpers, measurement.
- `src/backend/`: SDL renderer/GPU backends and thin C bridge wrappers.
- `src/platform/`: SDL input/event mapping helpers.
- `src/demo/`: demo runners.
- `docs/`: architecture/design notes.
- `docs/host_app_integration.md`: host lifecycle, ownership, backend setup, and asset-loading expectations.
- `vendor/`: third-party C headers and implementation files.
- `zig-out/`, `.zig-cache/`: generated output; do not edit manually.

Important build facts:
- `build.zig` creates the `analog_ui` module rooted at `src/root.zig`.
- The build graph adds include paths for `vendor/`, `vendor/truetype/`, and SDL's emitted include tree.
- The build graph compiles `vendor/truetype/stb_truetype_impl.c` and `vendor/clay/clay_impl.c`.
- The executable imports the library module instead of duplicating logic.
## Canonical Commands
Run commands from the repository root.
Build:
- `zig build`
- `zig build -Doptimize=ReleaseSafe`
- `zig build -Doptimize=ReleaseFast`
Run:
- `zig build run`
- `zig build run -Dwindow_demo=true`
Test:
- `zig build test`
- `zig build test-unit`
Formatting:
- `zig fmt src build.zig`
- `zig fmt --check src build.zig`
- `zig fmt build.zig.zon --zon`
- `zig fmt --check build.zig.zon --zon`
Build discovery: `zig build --help`

There is no separate linter configured here. Treat `zig fmt --check`, `zig build`, and `zig build test` as the validation baseline.

## Single-Test Guidance
Use `zig build test` for the full suite.
For a single inline test in a self-contained leaf module, use raw `zig test` with `--test-filter`.
Known working example:
- `zig test src/core/widgets.zig --test-filter "button press requires press and release while hovered"`
Important limitations:
- `build.zig` does not forward `b.args` to the test run steps, so `zig build test -- --test-filter ...` is not wired up.
- Raw `zig test path/to/file.zig` is not universally reliable in this repo.
- Files that import `../...` outside their immediate module root can fail with `import of file outside module path`.
- Files that rely on build.zig-added C sources can fail to link when run directly.
Examples that need build-graph context or extra wiring:
- `src/core/context.zig`
- `src/font/rasterizer.zig`
- `src/backend/sdl_renderer.zig`
- `src/backend/sdl_gpu.zig`
Practical rule:
- Use raw `zig test` only for leaf modules that stay within their local import subtree and avoid extra C link requirements.
- Use `zig build test` or `zig build test-unit` for package-wide confidence.
- If you need filtered execution for a non-leaf module, add or adjust build steps instead of guessing CLI flags.

## Architecture Expectations
Follow the existing split of responsibilities:
- Keep reusable library logic under `src/`.
- Keep `src/main.zig` thin.
- Re-export stable public APIs from `src/root.zig`.
- Keep backend-neutral logic in `src/core/` and `src/font/`.
- Keep SDL-specific logic in `src/backend/` and `src/platform/`.
- Keep demo-only code in `src/demo/`.
The design doc in `docs/clay_sdl3_zig_design.md` reinforces these repo goals: explicit allocators, deterministic teardown, minimal hidden work, testable core logic, thin backend layers, and no global mutable state.
For host-app integration behavior, treat `docs/host_app_integration.md` as the practical contract for SDL ownership boundaries, startup/frame/teardown order, and font/image asset responsibilities.

## Import Conventions
- Put imports at the top of the file.
- Import `std` first when the file uses it.
- Then import local modules with one `const` binding per line.
- Prefer direct symbol imports when only one symbol is needed.
- Prefer short aliases for broad module use, such as `ui`, `sdl`, `utf8`, or `clay`.
Current examples:
- `const std = @import("std");`
- `const ui = @import("analog_ui");`
- `const Font = @import("../font/font.zig").Font;`
## Formatting And Layout
- Always run `zig fmt` after editing Zig code.
- Use the formatter's default 4-space indentation.
- Let `zig fmt` handle wrapping and trailing commas.
- Keep blank lines purposeful.
- Keep top-level declarations first and tests near the bottom.
- Keep functions compact, but prefer readability over squeezing lines.

## Naming Conventions
- Files and directories: `snake_case`
- Types: `PascalCase`
- Functions and variables: `camelCase`
- Enum tags: lowercase or `snake_case`
- Error tags: `PascalCase`
- Test names: descriptive sentence-style strings

Examples in this repo: `Context`, `DrawList`, `RendererBackend`, `GpuBackend`, `beginFrame`, `clearFrameDeltas`, `latin_1`, `mouse_button_down`, `InvalidFontData`, `SdlRendererError`.

## Types And API Design
- Prefer explicit, concrete types.
- Use fixed-width integers where the domain is known: `u16`, `u32`, `u64`, `i16`.
- Use `usize` for lengths and indexing.
- Use `f32` for geometry, font sizing, and render-space values.
- Use `u21` where Unicode codepoints are involved.
- Prefer small option structs instead of long parameter lists.
- Use explicit casts at boundaries with `@as`, `@intCast`, `@floatFromInt`, and `@intFromFloat`.
## Memory Management And Ownership
- Any API that allocates should take a `std.mem.Allocator` directly.
- Pair every resource-owning `init` with a `deinit`.
- Use `defer` for cleanup and `errdefer` for partial initialization failures.
- Free owned slices created by `toOwnedSlice()`.
- Avoid hidden allocations in hot paths unless the API clearly documents them.
Common patterns already used here: `std.array_list.Managed(...)`, `allocator.dupe(...)`, `std.testing.allocator`, and `std.heap.GeneralPurposeAllocator(.{}){}`.

## Error Handling
- Prefer explicit Zig errors and straightforward propagation.
- Use `!T` for fallible APIs.
- Propagate with `try` by default.
- Map failed C calls to explicit Zig errors near the callsite.
- Use precise error names instead of generic catch-all errors.
- Only swallow errors when the fallback behavior is deliberate and local.
Examples worth following: `error.SdlRendererError`, `error.InvalidFontData`, `error.UnbalancedClipPop`, and best-effort preload with `catch {}` when missing glyphs are acceptable.

## C Interop And Vendor Code
- Keep `@cImport` in narrow bridge modules.
- Prefer thin wrappers like `src/backend/sdl_shared.zig` and `src/core/clay_bridge.zig`.
- Do not edit `vendor/` unless the task is explicitly about vendored code.
- If C implementation objects are required, wire them through `build.zig` rather than ad hoc shell commands.

## Testing Style
- Tests live inline in the Zig source files.
- Put `test "..."` blocks near the bottom of the file.
- Keep test names descriptive and behavior-oriented.
- Use `std.testing.expect`, `expectEqual`, `expectApproxEqAbs`, and `expectError`.
- Use `std.testing.allocator` unless a test needs something else.
- Clean up allocations in tests with `defer`.
- Add tests for bug fixes, new public APIs, new error behavior, and ownership-sensitive code paths.

## Change Strategy For Agents
- Prefer the smallest correct change.
- Preserve the current module boundaries.
- Keep demos separate from reusable library logic.
- Avoid new abstractions unless the duplication is real.
- Do not add compatibility layers without a concrete need.
- After non-trivial edits, run `zig fmt src build.zig` and `zig build test`.
