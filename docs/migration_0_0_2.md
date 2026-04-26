# Migration Notes (0.0.1 -> 0.0.2)

This release intentionally introduces breaking API changes around fonts and scale handling.

## Font API changes

- Removed single-font frame wiring (`default_font`, `sync_font`).
- Added `FontRegistry` + stable `FontHandle` model.
- Added fallback chains through `FontRegistry.setFallback(primary, fallbacks)`.

### Before

```zig
var font = try ui.Font.initTtf(alloc, .{ ... });
defer font.deinit();

ui.FrameApi.beginFrame(ctx, .{
    .screen = .{ .w = w, .h = h },
    .input = input,
    .default_font = &font,
});

try ui.FrameApi.renderFrame(&backend, draw_list, .{
    .sync_font = &font,
    .dpi_scale = dpi,
    .font_atlas_scale = dpi,
});
```

### After

```zig
var fonts = ui.FontRegistry.init(alloc);
defer fonts.deinit();

const body = try fonts.addTtf("Body", .{ ... });
const fallback = try fonts.addTtf("Fallback", .{ ... });
try fonts.setFallback(body, &.{fallback});

var theme = ui.Theme.default;
theme.font_body = body;
theme.font_heading = body;
theme.font_mono = body;

ui.FrameApi.beginFrame(ctx, .{
    .screen = .{ .w = w, .h = h },
    .input = input,
    .font_registry = &fonts,
    .theme = theme,
});

try ui.FrameApi.renderFrame(&backend, draw_list, .{
    .font_registry = &fonts,
    .scale = .{
        .dpi_scale = dpi,
        .user_scale = settings.ui_scale,
        .app_scale = app_scale,
    },
    .font_atlas_scale = dpi,
});
```

## Scale API changes

- Added `ScaleState` with explicit formula:

`effective_scale = dpi_scale * user_scale * app_scale`

- Added helpers:
  - `FrameApi.computeDpiScale(window)`
  - `FrameApi.clampUiScale(value)`

## Theme tokens

- Added theme font tokens:
  - `Theme.font_body`
  - `Theme.font_heading`
  - `Theme.font_mono`

Widgets now default to the configured theme role and still allow per-widget font override.
