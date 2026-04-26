# Host App Integration Guide

This guide defines integration expectations between your app and `analog_ui`.

It focuses on:

- SDL lifecycle ownership
- backend setup and teardown order
- font registration/fallback and image asset loading responsibilities
- frame loop expectations and common pitfalls

## Ownership Boundaries

`analog_ui` is intentionally explicit about ownership.

Host app owns:

- `SDL_Init` / `SDL_Quit`
- SDL window and renderer/device creation and destruction
- OS event pump and frame pacing
- file I/O and asset discovery paths
- image texture creation and lifetime

`analog_ui` owns:

- UI state types (`InputState`, `WidgetState`, `Context` internals)
- font atlas metadata, glyph cache, and registry state (`Font`, `FontRegistry`)
- backend-owned transient resources created by `RendererBackend.init`

Rule of thumb: if a resource comes from an SDL constructor in your code, your code tears it down.

## Startup Sequence (SDL Renderer Path)

Typical startup order:

1. Initialize SDL video
2. Create window
3. Create `SDL_Renderer`
4. Initialize `ui.RendererBackend`
5. Load TTF bytes and register fonts in `ui.FontRegistry`
6. Provide the registry to `FrameApi.renderFrame` (or `backend.syncFonts`) before drawing text

```zig
const std = @import("std");
const ui = @import("analog_ui");
const sdl = ui.sdl;

if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) return error.SdlInitFailed;
defer sdl.SDL_Quit();

const window = sdl.SDL_CreateWindow("my app", 1280, 720, sdl.SDL_WINDOW_RESIZABLE) orelse {
    return error.SdlCreateWindowFailed;
};
defer sdl.SDL_DestroyWindow(window);

const renderer = sdl.SDL_CreateRenderer(window, null) orelse {
    return error.SdlCreateRendererFailed;
};
defer sdl.SDL_DestroyRenderer(renderer);

var backend = try ui.RendererBackend.init(alloc, renderer);
defer backend.deinit();

const ttf_bytes = try std.fs.cwd().readFileAlloc(alloc, "assets/Roboto-Bold.ttf", std.math.maxInt(usize));
defer alloc.free(ttf_bytes);

var fonts = ui.FontRegistry.init(alloc);
defer fonts.deinit();

const body = try fonts.addTtf("Body", .{
    .ttf_bytes = ttf_bytes,
    .base_px = 18,
    .charset = .ascii,
    .dynamic_glyphs = true,
});

var theme = ui.Theme.default;
theme.font_body = body;
theme.font_heading = body;
theme.font_mono = body;

try backend.syncFonts(&fonts);
```

## Frame Loop Responsibilities

Per frame, the host app should:

1. Poll SDL events
2. Update `InputState` from events
3. Build UI/widget state
4. Build or obtain `DrawList`
5. Call `backend.syncFonts(&fonts)` when glyph pages may be dirty
6. Call `backend.render(draw_list, .{ ... })`
7. Present the renderer
8. (Optional) Read `FrameApi.framePerf` for per-frame diagnostics

Notes:

- Call `widget_state.beginFrame()` once at frame start before evaluating widgets.
- `RendererBackend.render` validates `DrawList` contract and returns errors for invalid input or SDL failures.
- Scale is explicit via `ScaleState`: `effective_scale = dpi_scale * user_scale * app_scale`.
- Keep `font_atlas_scale` aligned with how font atlases were rasterized.

If you want a stable orchestration surface instead of wiring each piece manually, use `ui.FrameApi`:

- `FrameApi.collectInput` / `FrameApi.collectSdlInput`
- `FrameApi.beginFrame`
- `FrameApi.endFrame`
- `FrameApi.framePerf`
- `FrameApi.renderFrame`

## Font Loading Expectations

`ui.Font.initTtf` duplicates `ttf_bytes` into owned memory, so your original byte slice may be freed after registration.

Key expectations:

- Pass a valid allocator and call `font.deinit()`.
- Keep the `FontRegistry` alive for as long as any backend render path reads it.
- If dynamic glyphs are enabled and new text appears, call `backend.syncFonts(&fonts)` again (or use `FrameApi.renderFrame` with `.font_registry = &fonts`) before rendering text that needs those glyphs.
- The backend does not hot-reload font files from disk; your app decides if and when fonts are reloaded.

### Text helpers and units

`ui.Text` helpers (`measure`, `wrap`, `truncateWithEllipsis`) operate in logical UI pixels.

- `measure`: returns logical width/height.
- `wrap`: returns line ranges with logical `width_px` values.
- `truncateWithEllipsis`: truncates a logical-width line and appends a suffix.

## Image Loading Expectations

The SDL renderer backend treats `DrawOp.image.image_id` as a backend-defined handle.

For this repository's SDL renderer implementation:

- `image_id` is an encoded `*SDL_Texture` pointer (`usize`)
- `image_id == 0` is treated as null/no-op
- texture allocation/destruction is host-owned

Example when building draw ops manually:

```zig
const image_id: usize = @intFromPtr(texture_ptr);

try builder.push(.{ .image = .{
    .rect = .{ .x = 20, .y = 20, .w = 64, .h = 64 },
    .image_id = image_id,
    .tint = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
} });
```

The backend applies tint/alpha modulation during rendering and restores previous texture modulation state.

## Teardown Order

Recommended shutdown order:

1. Stop frame loop
2. Destroy/deinit UI resources (`RendererBackend`, `Font`, `Context`, etc.)
3. Destroy SDL renderer/device
4. Destroy window
5. Call `SDL_Quit`

Deinit backend resources before destroying the underlying SDL renderer/device they reference.

## Current Backend Status

- `RendererBackend` (`SDL_Renderer`) is the production baseline path in this repo.
- `GpuBackend` currently returns `error.GpuBackendNotImplemented` for rendering APIs.

If you integrate the GPU path today, treat it as scaffold-only and guard with feature flags.
