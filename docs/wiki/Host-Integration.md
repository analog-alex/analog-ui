# Host Integration

The practical contract between a host app and `analog_ui`.

## Quick Nav

- [Home](Home.md)
- [Get Started](Get-Started.md)
- [Frame Loop](Frame-Loop.md)
- [Rendering and Backends](Rendering-and-Backends.md)

## Why This Matters

This library is explicit about ownership. If your app already owns SDL setup and lifetime, this is the page that tells you where the library begins and ends.

## Host Owns

- `SDL_Init` and `SDL_Quit`
- window creation and destruction
- `SDL_Renderer` or `SDL_GPUDevice`
- event pump and frame pacing
- asset discovery and file I/O
- image texture lifetime

## Library Owns

- `Context` internals
- `WidgetState` and input-related UI state
- font registry and atlas metadata
- backend-owned transient resources created by explicit init calls

## Recommended SDL Renderer Startup

1. Initialize SDL video.
2. Create the window.
3. Create `SDL_Renderer`.
4. Initialize `ui.RendererBackend`.
5. Load and register fonts.
6. Sync fonts before first text rendering.

```text
SDL init
  -> window
  -> renderer
  -> RendererBackend
  -> fonts
  -> frame loop
```

The full walkthrough is already documented in `docs/host_app_integration.md`.

## Per-Frame Responsibilities

1. Poll events.
2. Update `InputState`.
3. Build UI.
4. Produce or obtain a `DrawList`.
5. Sync dirty fonts when needed.
6. Render.
7. Present.

## Integration Notes

- Keep scale explicit through `ScaleState`.
- Keep `font_atlas_scale` aligned with atlas rasterization scale.
- Deinit backend resources before tearing down the underlying SDL renderer or device.
- Avoid double-linking SDL in host projects.

## Best Reference

- `docs/host_app_integration.md`
- `src/demo/window_demo.zig`
- `README.md`

## Related Pages

- [Get Started](Get-Started.md)
- [Frame Loop](Frame-Loop.md)
- [Rendering and Backends](Rendering-and-Backends.md)
