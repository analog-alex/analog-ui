# analog_ui

Backend-neutral Zig UI package using Clay, with SDL3 backend scaffolding.

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

### Build helpers for host integration

This package now exposes build helpers in `build.zig`:

- `addTo(b, module, opts)` adds C sources/includes for Clay + stb
- `link(b, step, target, optimize, opts)` optionally links SDL3 artifact

Use them from your host build script only when needed. This keeps SDL linkage explicit.

## SDL3 lifetime and ownership

`analog_ui` is designed so your app owns SDL lifecycle objects.

Your app should own:

- `SDL_Init` / `SDL_Quit`
- window creation/destruction
- `SDL_Renderer` or `SDL_GPUDevice`
- event pump and frame loop

The library should only receive SDL handles and render against them.

### Important: avoid double-linking SDL

If your host app already links SDL3, keep linking SDL3 in the host executable only once.

- Good: host app links SDL3, imports `analog_ui` module
- Bad: host app links SDL3, and also forces a second SDL3 artifact path

For this repository itself, SDL3 linking is only done for the local window demo (`-Dwindow_demo=true`).

If your host app already links SDL3, keep `with_sdl3_link = false` in helper options.

## Notes

- Clay and stb implementations are compiled as C sources through the `analog_ui` module.
- API is still evolving toward the full v1 scope in the design document.
