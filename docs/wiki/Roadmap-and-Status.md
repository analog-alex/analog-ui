# Roadmap and Status

Current maturity and forward direction for `analog_ui`.

## Quick Nav

- [Home](Home.md)
- [Architecture](Architecture.md)
- [Rendering and Backends](Rendering-and-Backends.md)
- [API Map](API-Map.md)

## Current Status

The repo is past raw scaffolding and already supports a meaningful menu-oriented integration path.

Current implemented baseline includes:

- core module layout and public API surface
- Clay command translation into `DrawList`
- font atlas, glyph cache, UTF-8 measurement, and dirty-rect tracking
- SDL renderer backend for clip, rect, border, text, and image ops
- headless and SDL window demo paths

## What Is Production-Like Today

- `RendererBackend`
- host-owned SDL lifecycle
- multi-font registry model
- menu-style UI flows shown in demos

## What Is Still Early

- `GpuBackend`
- broader widget coverage beyond the core menu set
- richer composition layers
- non-menu tooling-grade UI

## Snapshot

```text
strongest today: menus + SDL_Renderer + explicit host integration
still early: GPU backend + broader widget/tooling coverage
```

## Main References

- `README.md`
- `docs/ui_roadmap.md`
- `docs/clay_sdl3_zig_design.md`

## Roadmap Themes

The roadmap currently focuses on:

1. menu-ready foundation
2. richer hub UI pieces
3. real GPU rendering
4. more declarative authoring
5. tooling-grade widgets
6. eventual Clay independence

See `docs/ui_roadmap.md` for the detailed milestone breakdown.

## Related Pages

- [Architecture](Architecture.md)
- [Rendering and Backends](Rendering-and-Backends.md)
- [Home](Home.md)
