# analog_ui Wiki

Small, versioned documentation for integrating and understanding `analog_ui`.

If you only read one page, read [Get Started](Get-Started.md).

## Quick Nav

- [Get Started](Get-Started.md)
- [Frame Loop](Frame-Loop.md)
- [Host Integration](Host-Integration.md)
- [Widgets and Menus](Widgets-and-Menus.md)
- [Fonts and Text](Fonts-and-Text.md)
- [Rendering and Backends](Rendering-and-Backends.md)
- [Architecture](Architecture.md)
- [API Map](API-Map.md)
- [Roadmap and Status](Roadmap-and-Status.md)

## What This Library Is

`analog_ui` is a backend-neutral immediate-mode UI package for Zig built around Clay layout output, a custom font pipeline, and SDL-oriented rendering backends.

Today, the strongest path in this repo is:

- menu-style game UI
- `SDL_Renderer` rendering
- explicit host ownership of SDL lifecycle, fonts, and assets

## Start Here

- First run and first integration: [Get Started](Get-Started.md)
- Host ownership and SDL setup: [Host Integration](Host-Integration.md)
- The per-frame loop: [Frame Loop](Frame-Loop.md)
- Menu UI and buttons: [Widgets and Menus](Widgets-and-Menus.md)
- Rendering boundary and backend status: [Rendering and Backends](Rendering-and-Backends.md)

## Core Concepts

- `Context` and `FrameApi` orchestrate per-frame UI work.
- `FontRegistry` and `FontHandle` manage text and fallback fonts.
- `DrawList` is the renderer boundary between core UI code and backends.
- `RendererBackend` is the production baseline backend in this repo.
- `GpuBackend` exists, but is scaffold-only today.

## At A Glance

```text
host app
  -> SDL lifecycle + assets
  -> input events
  -> analog_ui frame work
  -> DrawList
  -> SDL renderer backend
```

## Suggested Reading Order

1. [Get Started](Get-Started.md)
2. [Host Integration](Host-Integration.md)
3. [Frame Loop](Frame-Loop.md)
4. [Widgets and Menus](Widgets-and-Menus.md)
5. [Fonts and Text](Fonts-and-Text.md)
6. [Rendering and Backends](Rendering-and-Backends.md)

## Best Reference Files

- `src/root.zig`
- `src/demo/window_demo.zig`
- `src/demo/menu_screens.zig`
- `docs/host_app_integration.md`
- `docs/draw_list_contract.md`

## Related Pages

- [Architecture](Architecture.md)
- [API Map](API-Map.md)
- [Roadmap and Status](Roadmap-and-Status.md)
