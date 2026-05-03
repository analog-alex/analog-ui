# Get Started

The fastest path from clone to a working `analog_ui` frame.

## Quick Nav

- [Home](Home.md)
- [Frame Loop](Frame-Loop.md)
- [Host Integration](Host-Integration.md)
- [Rendering and Backends](Rendering-and-Backends.md)

## Why This Matters

The quickest way to understand this repo is to run the window demo, then map its pieces onto your own host app. This page keeps that path concrete.

## Five-Minute Path

1. Build the repo: `zig build`
2. Run the window demo: `zig build run -Dwindow_demo=true`
3. Read the host loop in `src/demo/window_demo.zig`
4. Read the menu UI in `src/demo/menu_screens.zig`
5. Use [Host Integration](Host-Integration.md) when wiring the same flow into another app

```text
run demo
  -> study window_demo.zig
  -> study menu_screens.zig
  -> copy the ownership/frame-loop shape into your app
```

## Build and Run

- Build package and executable: `zig build`
- Run full tests: `zig build test`
- Run headless demo: `zig build run`
- Run SDL window demo: `zig build run -Dwindow_demo=true`

## First Run

Use the SDL window demo first:

```sh
zig build run -Dwindow_demo=true
```

The best example file is `src/demo/window_demo.zig`.

It shows:

- SDL startup and teardown
- renderer backend setup
- font registration
- DPI scale detection
- per-frame input collection
- menu rendering through `FrameApi.renderFrame`

## Quick Start Flow

For a real host app, the minimal shape is:

1. Create SDL window and renderer.
2. Initialize `ui.RendererBackend`.
3. Load fonts into `ui.FontRegistry`.
4. Poll events each frame.
5. Convert events into `ui.InputState`.
6. Build UI for the current frame.
7. Render the resulting `DrawList`.

```text
SDL setup
  -> RendererBackend.init
  -> FontRegistry setup
  -> per-frame input/UI/render loop
```

## Setup Once

The setup side of the demo lives mostly in `src/demo/window_demo.zig`.

Look for these parts:

- SDL init and teardown
- `SDL_CreateWindow`
- `SDL_CreateRenderer`
- `ui.RendererBackend.init`
- `ui.FontRegistry.init`
- theme font handle assignment

The ownership rule is simple: if the host app creates an SDL object, the host app destroys it.

## Do Every Frame

The per-frame loop should stay boring and predictable:

1. Poll SDL events into a temporary event list.
2. Update scale when SDL reports DPI/window scale changes.
3. Convert SDL events with `FrameApi.collectSdlInput`.
4. Build the current UI screen.
5. Clear the renderer.
6. Render with `FrameApi.renderFrame`.
7. Present the renderer.

In this repo, that flow is visible in the `while (menu_state.running)` loop in `src/demo/window_demo.zig`.

## Build UI

For menu-style UI, start with `src/demo/menu_screens.zig`.

It shows the practical widget pattern:

- keep persistent screen state in an app-owned struct
- call `widget_state.beginFrame()` once per frame
- use stable IDs like `ui.Id.fromStr("title_start")`
- map nav input into focus movement
- evaluate buttons and mutate screen state from button results

## Copy This Mental Template

```zig
// One-time host setup:
// - SDL window/renderer
// - ui.RendererBackend
// - ui.FontRegistry
// - ui.Theme with font handles

// Per frame:
// - collect input
// - build UI state/draw ops
// - render draw list
```

This is intentionally not a full snippet. The full, compiling version is `src/demo/window_demo.zig`.

## First Files To Read In Order

- `src/demo/window_demo.zig`
- `docs/host_app_integration.md`
- `src/demo/menu_screens.zig`
- `src/root.zig`
- `README.md`

## Current Baseline

Use `RendererBackend` if you want a working render path in this repo.

`GpuBackend` is present but not production-usable yet.

## Common First Integration Mistakes

- Do not let the library own `SDL_Init`, windows, renderers, or event polling.
- Do not skip font registration before rendering text.
- Do not retain `DrawList.ops` after the frame unless the producer explicitly says the memory is owned by you.
- Do not start with `GpuBackend`; use `RendererBackend` first.

## Related Pages

- [Frame Loop](Frame-Loop.md)
- [Host Integration](Host-Integration.md)
- [Rendering and Backends](Rendering-and-Backends.md)
