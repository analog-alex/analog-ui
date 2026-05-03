# API Map

A human-oriented guide to the public exports in `src/root.zig`.

## Quick Nav

- [Home](Home.md)
- [Architecture](Architecture.md)
- [Frame Loop](Frame-Loop.md)
- [Widgets and Menus](Widgets-and-Menus.md)

## Why This Matters

`src/root.zig` is the package surface, but raw exports are easier to navigate once grouped by responsibility.

If you are looking for the exact canonical list, read `src/root.zig` directly.

## Core Types

- `Id`
- `InputState`
- `DrawList`
- `Rect`
- `Color`
- `Builder`
- `Context`
- `Theme`
- `ScaleState`
- `WidgetState`

## Frame API

- `FrameApi.collectInput`
- `FrameApi.collectSdlInput`
- `FrameApi.beginFrame`
- `FrameApi.endFrame`
- `FrameApi.renderFrame`
- `FrameApi.framePerf`
- `FrameApi.setPerfEnabled`

## Layout and Performance Helpers

- `Layout`
- `Perf`
- `FramePerf`
- `clampUiScale`

## Fonts and Text

- `Font`
- `FontRegistry`
- `FontHandle`
- `Text`
- `FontRole`

## Widgets and Focus

- `CoreWidgets`
- `ButtonOptions`
- `ButtonInteraction`
- `FocusDirection`
- `FocusItem`
- `button`
- `buttonWithOptions`
- `buttonWidget`
- `label`
- `image`
- `spacer`
- `separator`
- `moveFocusLinear`

## SDL and Platform Input

- `SdlEvent`
- `inputFromEvents`
- `inputFromSdlEvents`
- `sdl`

## Backends

- `RendererBackend`
- `GpuBackend`

## Version

- `version`

## Best Reference

Read `src/root.zig` directly when you want the exact package export list.

## Related Pages

- [Architecture](Architecture.md)
- [Frame Loop](Frame-Loop.md)
- [Widgets and Menus](Widgets-and-Menus.md)
