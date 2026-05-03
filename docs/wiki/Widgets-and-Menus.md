# Widgets and Menus

How the repo currently builds interactive menu-style UI.

## Quick Nav

- [Home](Home.md)
- [Get Started](Get-Started.md)
- [Frame Loop](Frame-Loop.md)
- [Fonts and Text](Fonts-and-Text.md)
- [API Map](API-Map.md)

## Why This Matters

The strongest application-level examples in this repo are menu flows. They show how `Id`, `WidgetState`, focus navigation, and core widgets fit together.

## Main Building Blocks

- `Id`
- `WidgetState`
- `FocusItem`
- `moveFocusLinear`
- `CoreWidgets`

## Stable Identity

Interactive widgets should use stable IDs.

The menu example uses explicit values like:

- `ui.Id.fromStr("title_start")`
- `ui.Id.fromStr("settings_back")`

That makes focus, hover, active state, and button press tracking stable across frames.

## Focus and Navigation

The menu example keeps ordered focus lists per screen and advances focus using navigation input.

Typical pattern:

1. Call `widget_state.beginFrame()`.
2. Choose the active focus list for the current screen.
3. React to `input.nav_up` and `input.nav_down`.
4. Call `moveFocusLinear(...)`.
5. Evaluate buttons with stable IDs.

```text
InputState
  -> WidgetState
  -> focus selection
  -> button evaluation
  -> screen state changes
```

## Screen Composition

`src/demo/menu_screens.zig` is the best end-to-end example.

It demonstrates:

- title, pause, and settings screens
- layout helpers for panel and button placement
- button styling through theme and options
- state transitions between screens
- background/theme selection state

## Quick Menu Recipe

1. Define a `State` struct for screen-level state.
2. Define stable IDs at file scope.
3. Define focus item arrays for each screen.
4. Compute rectangles with `Layout` helpers.
5. Push background/panel draw ops.
6. Use `CoreWidgets` for labels, separators, and buttons.
7. Mutate `State` only from button/nav results.

That recipe is exactly what `src/demo/menu_screens.zig` demonstrates.

## Current Widget Set

The core set exported through `src/root.zig` includes:

- `button`
- `buttonWithOptions`
- `buttonWidget`
- `label`
- `image`
- `spacer`
- `separator`

## Best Reference

- `src/demo/menu_screens.zig`
- `src/core/widgets.zig`
- `src/core/layout.zig`

## Related Pages

- [Frame Loop](Frame-Loop.md)
- [Fonts and Text](Fonts-and-Text.md)
- [API Map](API-Map.md)
