# analog_ui

Backend-neutral Zig UI package using [Clay](https://github.com/nicbarker/clay), with SDL3 backend scaffolding.

## Status

This project is an active implementation of the design in `docs/clay_sdl3_zig_design.md`.

Current state:

- Core types and module layout are in place
- Clay C bridge is wired and render commands are translated to `DrawList`
- Font atlas pages, glyph cache, UTF-8 measurement, and dirty-rect tracking are implemented
- SDL renderer backend renders clip/rect/border/text/image draw ops (GPU backend remains scaffold)
- Headless and SDL window demo paths exist in `src/main.zig`

## Build and Run

- Build library/exe: `zig build`
- Run tests: `zig build test`
- Run headless demo: `zig build run`
- Run SDL window demo: `zig build run -Dwindow_demo=true`

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

- **Core Types**: `Id`, `InputState`, `DrawList`, `Rect`, `Builder`, `Context`, `Theme`, `WidgetState`
- **Fonts**: `Font`
- **Widgets**: `button`, `buttonWithOptions`, `moveFocusLinear`, `ButtonInteraction`, `ButtonOptions`, `FocusItem`
- **Input**: `inputFromEvents(events: []SdlEvent, prev: InputState) InputState`
- **Backends**: `RendererBackend` (SDL3 renderer), `GpuBackend` (SDL GPU)

### Example Usage

One-time setup (outside your frame loop):

```zig
const std = @import("std");
const ui = @import("analog_ui");
const sdl = ui.sdl;

var backend = try ui.RendererBackend.init(alloc, renderer);
defer backend.deinit();

const ttf_bytes = try std.fs.cwd().readFileAlloc(alloc, "assets/Roboto-Bold.ttf", std.math.maxInt(usize));
defer alloc.free(ttf_bytes);

var font = try ui.Font.initTtf(alloc, .{
    .ttf_bytes = ttf_bytes,
    .base_px = 16,
    .charset = .ascii,
    .dynamic_glyphs = true,
});
defer font.deinit();
```

Per-frame pass (input -> widget logic -> draw list -> render):

```zig
fn pointInRect(r: ui.Rect, x: f32, y: f32) bool {
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h;
}

fn renderFrame(
    alloc: std.mem.Allocator,
    backend: *ui.RendererBackend,
    font: *ui.Font,
    events: []const sdl.SDL_Event,
    input: *ui.InputState,
    widgets: *ui.WidgetState,
) !void {
    input.* = ui.inputFromSdlEvents(events, input.*);
    widgets.beginFrame();

    const button_rect = ui.Rect{ .x = 48, .y = 40, .w = 220, .h = 56 };
    const hovered = pointInRect(button_rect, input.mouse_pos.x, input.mouse_pos.y);
    const button_id = ui.Id.fromStr("play_button");

    const interaction = ui.buttonWithOptions(widgets, button_id, input.*, .{ .hovered = hovered });
    if (interaction.pressed) {
        std.debug.print("Play pressed\n", .{});
    }

    var builder = ui.Builder.init(alloc);
    defer builder.deinit();

    try builder.push(.{ .rect_filled = .{
        .rect = button_rect,
        .color = .{ .r = 0.16, .g = 0.49, .b = 0.76, .a = 1.0 },
        .radius = 8,
    } });
    try builder.push(.{ .text_run = .{
        .rect = button_rect,
        .text = "Play",
        .font_handle = 0,
        .size_px = 16,
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        .alignment = .center,
    } });

    const draw_list = try builder.finish();
    defer alloc.free(draw_list.ops);

    try backend.syncFont(font);
    try backend.render(draw_list, .{ .dpi_scale = 1.0, .font_atlas_scale = 1.0 });
}
```

See `src/demo/headless_demo.zig` and `src/demo/window_demo.zig` for full demos. Version: `0.0.0`.

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
- Clay and stb implementations are compiled as C sources through the `analog_ui` module.
- API is still evolving toward the full v1 scope in the design document.
