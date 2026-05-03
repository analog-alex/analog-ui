# Get Started

Build, run, and navigate the main integration path for `analog_ui`.

## Quick Nav

- [Home](Home.md)
- [Frame Loop](Frame-Loop.md)
- [Host Integration](Host-Integration.md)
- [Rendering and Backends](Rendering-and-Backends.md)

## Why This Matters

The repo already contains the intended happy path for host apps. This page keeps the entry path short and points you at the most representative files.

## Build and Run

- Build package and executable: `zig build`
- Run full tests: `zig build test`
- Run headless demo: `zig build run`
- Run SDL window demo: `zig build run -Dwindow_demo=true`

## Recommended First Run

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

## Minimal Mental Model

The main app loop is:

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

## First Files To Read

- `README.md`
- `src/root.zig`
- `src/demo/window_demo.zig`
- `docs/host_app_integration.md`

## Current Baseline

Use `RendererBackend` if you want a working render path in this repo.

`GpuBackend` is present but not production-usable yet.

## Related Pages

- [Frame Loop](Frame-Loop.md)
- [Host Integration](Host-Integration.md)
- [Rendering and Backends](Rendering-and-Backends.md)
