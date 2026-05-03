# Frame Loop

The per-frame orchestration model for `analog_ui`.

## Quick Nav

- [Get Started](Get-Started.md)
- [Host Integration](Host-Integration.md)
- [Widgets and Menus](Widgets-and-Menus.md)
- [Rendering and Backends](Rendering-and-Backends.md)

## Why This Matters

Most host integrations either wire this flow manually or use `FrameApi` as the stable boundary. Understanding this page makes the rest of the repo easier to read.

## Core Flow

Per frame, the host app should do this:

1. Poll SDL events.
2. Convert events into `InputState`.
3. Begin a UI frame.
4. Build widgets or draw ops.
5. Finish the frame into a `DrawList`.
6. Sync fonts if needed.
7. Render the draw list.

```text
poll
  -> collect
  -> build
  -> finish
  -> render
  -> present
```

## `FrameApi` Surface

The main helpers are:

- `FrameApi.collectInput`
- `FrameApi.collectSdlInput`
- `FrameApi.beginFrame`
- `FrameApi.endFrame`
- `FrameApi.renderFrame`
- `FrameApi.framePerf`
- `FrameApi.setPerfEnabled`

## Real Example

`src/demo/window_demo.zig` is the best concrete reference in this repo.

Its flow is roughly:

```text
poll SDL events
  -> collect input
  -> update scale state
  -> build menu frame
  -> render via FrameApi.renderFrame
  -> present renderer
```

For the fastest onboarding path, read this page after [Get Started](Get-Started.md).

## Scale Handling

Scaling is explicit.

The current formula is:

```text
effective_scale = dpi_scale * user_scale * app_scale
```

Useful helpers:

- `FrameApi.computeDpiScale(window)`
- `clampUiScale(value)`

The window demo also shows runtime DPI changes and user-controlled UI scaling.

## Performance Note

Per-frame perf collection can be disabled when you do not need diagnostics:

- `FrameApi.setPerfEnabled(context, false)`

That avoids the extra bookkeeping path used for diagnostics.

## Best Reference

- `src/demo/window_demo.zig`
- `src/core/frame_api.zig`
- `docs/host_app_integration.md`

## Related Pages

- [Get Started](Get-Started.md)
- [Host Integration](Host-Integration.md)
- [Rendering and Backends](Rendering-and-Backends.md)
