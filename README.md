# analog_ui

Backend-neutral Zig UI package using [Clay](https://github.com/nicbarker/clay), with SDL3 backend scaffolding.

## Status

This project is an active implementation of the design in `docs/clay_sdl3_zig_design.md`.

Current state:

- Core types and module layout are in place
- Clay C bridge is wired and render commands are translated to `DrawList`
- Font atlas pages, glyph cache, UTF-8 measurement, and dirty-rect tracking are implemented
- SDL renderer backend renders clip/rect/border/text/image draw ops (GPU backend remains scaffold)
- Headless and SDL window demo paths exist in `src/main.zig`, including title/pause/settings menu examples

## Build and Run

- Build library/exe: `zig build`
- Run tests: `zig build test`
- Run headless demo: `zig build run`
- Run SDL window demo: `zig build run -Dwindow_demo=true`

## Dependencies

Core dependencies used by this project:

- [Clay](https://github.com/nicbarker/clay) for layout and command generation
- [stb_truetype](https://github.com/nothings/stb/blob/master/stb_truetype.h) for TTF rasterization and glyph metrics
- SDL3 Zig package dependency (`.sdl` in `build.zig.zon`) for SDL headers/library integration in this repository

In this repository, Clay and `stb_truetype` are compiled via vendored C implementation units wired in `build.zig`, while SDL3 comes from the Zig package dependency.

## Using `analog_ui` in another project

Add this package to your `build.zig.zon`, then in your app `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const analog_dep = b.dependency("analog_ui", .{
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "my_game",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "analog_ui", .module = analog_dep.module("analog_ui") },
            },
        }),
    });

    b.installArtifact(exe);
}
```

## API Overview

`analog_ui` is an immediate-mode GUI library powered by [Clay](https://github.com/nicbarker/clay) for layout, with custom vector rendering via `DrawList` ops.

`DrawList` semantics, ownership, and backend responsibilities are documented in `docs/draw_list_contract.md`.

Host app lifecycle, ownership boundaries, backend setup, and asset-loading expectations are documented in `docs/host_app_integration.md`.

### Key Exports (`src/root.zig`)

- **Core Types**: `Id`, `InputState`, `DrawList`, `Rect`, `Builder`, `Context`, `Theme`, `ScaleState`, `WidgetState`
- **Frame API**: `FrameApi.collectInput`, `FrameApi.collectSdlInput`, `FrameApi.beginFrame`, `FrameApi.endFrame`, `FrameApi.framePerf`, `FrameApi.setPerfEnabled`, `FrameApi.renderFrame`
- **Fonts**: `Font`, `FontRegistry`, `FontHandle`
- **Text Helpers**: `Text.measure`, `Text.wrap`, `Text.truncateWithEllipsis`
- **Layout Helpers**: `Layout.splitRow`, `Layout.splitColumn`, `Layout.stack`, `Layout.inset`, `Layout.alignRect`
- **Perf**: `FrameApi.framePerf`, `FramePerf`, `Perf.OpBreakdown`
- **Widgets**: `button`, `buttonWithOptions`, `buttonWidget`, `label`, `image`, `spacer`, `separator`, `CoreWidgets`, `moveFocusLinear`, `ButtonInteraction`, `ButtonOptions`, `FocusItem`
- **Input**: `inputFromEvents(events: []SdlEvent, prev: InputState) InputState`
- **Backends**: `RendererBackend` (SDL3 renderer), `GpuBackend` (SDL GPU)

### Breaking API note

Recent API updates intentionally removed the single-font frame API in favor of `FontRegistry` + `FontHandle`.

Migration notes: `docs/migration_0_0_2.md`.

### Frame API Surface

`FrameApi` provides the stable per-frame orchestration layer around context/input/fonts/rendering:

- `collectInput` / `collectSdlInput`: map events into `InputState`
- `computeDpiScale`: helper for SDL window DPI detection
- `clampUiScale`: helper to clamp user-controlled UI scale values
- `beginFrame`: starts a context frame with screen size, input snapshot, and optional per-frame theme/scale/registry overrides
- `endFrame`: returns the `DrawList` for the frame
- `setPerfEnabled`: enable/disable per-frame perf breakdown collection (disable to remove the extra op scan)
- `framePerf`: returns per-frame perf stats (op breakdown, clip depth, draw-op buffer usage)
- `renderFrame`: optional registry sync + backend render in one call

Text metrics returned by `Text.measure` and `Text.wrap` are in logical UI pixels (the same space used by `DrawList` geometry).

`Layout` helpers also operate in logical UI pixels and are intended to replace repeated manual rect math in app code.

### Example Usage

One-time setup (outside your frame loop):

```zig
const std = @import("std");
const ui = @import("analog_ui");
const sdl = ui.sdl;

var backend = try ui.RendererBackend.init(alloc, renderer);
defer backend.deinit();

var io_instance: std.Io.Threaded = .init(alloc, .{});
defer io_instance.deinit();
const io = io_instance.io();

const cwd = std.Io.Dir.cwd();
const ttf_bytes = try cwd.readFileAlloc(io, "assets/Roboto-Bold.ttf", alloc, .limited(std.math.maxInt(usize)));
defer alloc.free(ttf_bytes);

var fonts = ui.FontRegistry.init(alloc);
defer fonts.deinit();

const body = try fonts.addTtf("Body", .{
    .ttf_bytes = ttf_bytes,
    .base_px = 16,
    .charset = .ascii,
    .dynamic_glyphs = true,
});

var theme = ui.Theme.default;
theme.font_body = body;
theme.font_heading = body;
theme.font_mono = body;
```

Per-frame pass (input -> widget logic -> draw list -> render):

```zig
fn renderFrame(
    ctx: *ui.Context,
    backend: *ui.RendererBackend,
    fonts: *ui.FontRegistry,
    theme: ui.Theme,
    events: []const sdl.SDL_Event,
    input_prev: *ui.InputState,
    dpi_scale: f32,
) !void {
    const input = ui.FrameApi.collectSdlInput(events, input_prev.*);
    input_prev.* = input;

    ui.FrameApi.beginFrame(ctx, .{
        .screen = .{ .w = 1280, .h = 720 },
        .input = input,
        .font_registry = fonts,
        .theme = theme,
    });

    // Build Clay/UI layout for this frame here.

    const draw_list = try ui.FrameApi.endFrame(ctx);

    try ui.FrameApi.renderFrame(backend, draw_list, .{
        .font_registry = fonts,
        .scale = .{
            .dpi_scale = dpi_scale,
            .user_scale = 1.0,
            .app_scale = 1.0,
        },
        .font_atlas_scale = dpi_scale,
    });
}
```

See `src/demo/headless_demo.zig` and `src/demo/window_demo.zig` for full demos. Version: `0.0.1`.

`src/demo/headless_demo.zig` includes a minimal multi-font fallback sample, and `src/demo/window_demo.zig` shows runtime DPI/user/app scaling through `ScaleState`.

## SDL3 lifetime and ownership

`analog_ui` is designed so your app owns SDL lifecycle objects.

Your app should own:

- `SDL_Init` / `SDL_Quit`
- window creation/destruction
- `SDL_Renderer` or `SDL_GPUDevice`
- event pump and frame loop

The library should only receive SDL handles and render against them.

For practical startup/frame/teardown guidance (including font and image asset responsibilities), see `docs/host_app_integration.md`.

### Important: avoid double-linking SDL

If your host app already links SDL3, keep linking SDL3 in the host executable only once.

- Good: host app links SDL3, imports `analog_ui` module
- Bad: host app links SDL3, and also forces a second SDL3 artifact path

For this repository itself, SDL3 linking is only done for the local window demo (`-Dwindow_demo=true`).

## Notes

- Clay is developed upstream at [nicbarker/clay](https://github.com/nicbarker/clay).
- Clay and `stb_truetype` implementations are compiled as C sources through the `analog_ui` module.
- API is still evolving toward the full v1 scope in the design document.

## Wiki

For a small, repo-versioned documentation set, start here:

- `docs/wiki/Get-Started.md`
- `docs/wiki/Home.md`

Recommended entry pages:

- `docs/wiki/Frame-Loop.md`
- `docs/wiki/Host-Integration.md`
- `docs/wiki/Widgets-and-Menus.md`
