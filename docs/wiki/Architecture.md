# Architecture

High-level structure of `analog_ui` and how data moves through the library.

## Quick Nav

- [Home](Home.md)
- [Frame Loop](Frame-Loop.md)
- [API Map](API-Map.md)
- [Roadmap and Status](Roadmap-and-Status.md)

## Why This Matters

The repo is intentionally split so core logic stays testable and backend code stays thin.

## Source Layout

### `src/core/`

Backend-neutral UI logic:

- context and frame orchestration
- input state
- theme and scale
- layout helpers
- widget interaction and focus
- Clay translation
- `DrawList` generation

Important files:

- `src/core/context.zig`
- `src/core/frame_api.zig`
- `src/core/widgets.zig`
- `src/core/draw_list.zig`

### `src/font/`

Font and text subsystem:

- TTF loading and ownership
- glyph cache and atlas pages
- UTF-8 helpers
- measurement, wrapping, truncation
- fallback chains

Important files:

- `src/font/font.zig`
- `src/font/registry.zig`
- `src/font/text.zig`

### `src/backend/`

Renderer implementations and shared backend helpers:

- `src/backend/sdl_renderer.zig`
- `src/backend/sdl_gpu.zig`
- `src/backend/sdl_shared.zig`

### `src/platform/`

SDL event mapping into backend-neutral input types:

- `src/platform/sdl_events.zig`
- `src/platform/sdl_keys.zig`
- `src/platform/sdl_gamepad.zig`

### `src/demo/`

Reference examples for intended usage:

- `src/demo/window_demo.zig`
- `src/demo/menu_screens.zig`
- `src/demo/headless_demo.zig`
- `src/demo/multi_font_demo.zig`

## Main Data Flow

```text
SDL events
  -> InputState
  -> Context / WidgetState / UI code
  -> DrawList
  -> RendererBackend.render(...)
```

## Layer View

```text
core UI
  -> font subsystem
  -> DrawList boundary
  -> backend implementation
```

Or, with the higher-level orchestration surface:

```text
events
  -> FrameApi.collectSdlInput
  -> FrameApi.beginFrame
  -> build UI
  -> FrameApi.endFrame
  -> FrameApi.renderFrame
```

## Public Surface

`src/root.zig` is the package entry point and re-exports the supported API surface.

If you are unsure where to look first, start there.

## Design Reference

The deeper rationale and long-form design goals live in `docs/clay_sdl3_zig_design.md`.

## Related Pages

- [Frame Loop](Frame-Loop.md)
- [API Map](API-Map.md)
- [Roadmap and Status](Roadmap-and-Status.md)
