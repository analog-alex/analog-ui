# Fonts and Text

How `analog_ui` handles font registration, fallback chains, and text helpers.

## Quick Nav

- [Home](Home.md)
- [Frame Loop](Frame-Loop.md)
- [Widgets and Menus](Widgets-and-Menus.md)
- [API Map](API-Map.md)

## Why This Matters

Recent API changes moved the library away from a single-font model. Fonts now flow through `FontRegistry` and stable `FontHandle` values.

## Key Types

- `Font`
- `FontRegistry`
- `FontHandle`
- `Text`

## Main Model

Register fonts once, hold onto the registry, and refer to fonts through handles.

Typical flow:

1. Create `FontRegistry`.
2. Add one or more TTF fonts.
3. Set fallback chains if needed.
4. Store handles in `Theme`.
5. Pass the registry into frame and render calls.

```text
TTF bytes
  -> FontRegistry
  -> FontHandle in Theme
  -> Text helpers + rendering
```

## Current Expectations

- `Font.initTtf` duplicates TTF bytes into owned memory.
- Keep `FontRegistry` alive for as long as rendering needs it.
- If dynamic glyphs add new atlas content, sync fonts again before rendering.

## Text Helpers

`ui.Text` currently exposes helpers for:

- measuring text
- wrapping text
- truncating with ellipsis

These helpers operate in logical UI pixels.

## Fallback Fonts

Fallback chains are configured through `FontRegistry.setFallback(primary, fallbacks)`.

Good reference files:

- `src/demo/multi_font_demo.zig`
- `src/demo/headless_demo.zig`

## Migration Context

If you are upgrading older code, see `docs/migration_0_0_2.md`.

The important change was replacing single-font frame wiring with registry-driven font access.

## Best Reference

- `src/font/registry.zig`
- `src/font/text.zig`
- `docs/migration_0_0_2.md`

## Related Pages

- [Get Started](Get-Started.md)
- [Frame Loop](Frame-Loop.md)
- [API Map](API-Map.md)
