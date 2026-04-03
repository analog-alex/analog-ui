# UI Roadmap

## Vision

Long-term target:

- React-like expressivity for authoring UI in Zig
- High-performance rendering with a real GPU-first backend
- Eventual removal of the Clay dependency once internal layout/runtime reach parity

The library should progress in phases so it becomes useful early for game menus, then robust enough for hub screens, then capable enough for internal editor tooling.

## Principles

- Ship usable layers incrementally
- Prefer explicit ownership and predictable performance
- Keep backend-neutral draw data stable while renderer implementations evolve
- Avoid rewriting Clay integration until the library owns enough layout and widget behavior to replace it safely

## Milestones

### 1. Menu-Ready Foundation

Goal: make the library solid for title screens, pause menus, settings, and other straightforward game UI.

Tasks:

- Define a stable public frame API around `Context`, input, fonts, and rendering
- Stabilize the `DrawList` contract and document backend expectations
- Complete SDL renderer support for rect, border, text, image, and clipping behavior
- Add a proper interaction model for hover, active, focus, and disabled states
- Add a small core widget set: label, button, image, spacer, separator
- Add menu-focused examples: title screen, pause screen, settings screen
- Add integration tests for menu interaction and rendering
- Document host app lifecycle, ownership boundaries, and asset loading expectations

Exit criteria:

- Menus can be built without touching raw draw ops
- Rendering and interaction are deterministic across frames
- Examples and docs are enough for a first real integration

### 2. Hub UI Kit

Goal: support richer in-game screens such as inventory, map, codex, quest log, and upgrade hubs.

Tasks:

- Add scroll containers and clipped regions
- Add list, grid, and tab primitives
- Add card, panel, and row composition helpers
- Add gamepad-first focus traversal and navigation
- Add image and icon workflow for atlas-backed UI assets
- Add optional animation hooks for hover, selection, and transitions
- Expand theming tokens for spacing, color, radius, and typography
- Add sample hub screens: inventory, mission board, codex

Exit criteria:

- Hub-style screens can be built from reusable pieces
- Mouse, keyboard, and gamepad all work cleanly
- Screen styling is mostly theme-driven instead of one-off code

### 3. GPU-Native Rendering

Goal: make the performance story real by implementing and validating a proper GPU path.

Tasks:

- Implement a functional `SDL_GPU` backend for the current draw model
- Add GPU-side font atlas upload and dirty-rect synchronization
- Batch rect, border, text, and image ops for efficient submission
- Define backend capability and parity expectations
- Measure frame time and allocation behavior under UI load
- Remove steady-state hot-path allocations where possible
- Add stress and profiling harnesses for large screens
- Document backend tradeoffs: `SDL_Renderer` vs `SDL_GPU`

Exit criteria:

- `GpuBackend` is production-usable, not a scaffold
- Performance characteristics are measured and documented
- Large UI screens render predictably on the GPU path

### 4. React-Like Authoring Layer

Goal: make authoring feel declarative and composable instead of manual and low-level.

Tasks:

- Design a declarative Zig UI builder API on top of the current core
- Add component-style composition patterns for reusable screens and sections
- Add local state helpers for transient and persistent widget state
- Add row, column, stack, overlay, and spacing helpers
- Add keyed child identity patterns for dynamic lists
- Build complex screen examples without direct `DrawList` construction
- Document composition, state hoisting, and side-effect patterns
- Evaluate the ergonomics tradeoffs needed to feel React-like in Zig

Exit criteria:

- Typical screens are authored as composable functions
- Stable identity and local state are easy to use
- Most users do not need to write raw draw ops

### 5. Tooling-Grade Widgets

Goal: cross from game menu UI into practical internal editor UI.

Tasks:

- Add text input, caret movement, selection, and clipboard support
- Add numeric input, checkbox, toggle, slider, and dropdown widgets
- Add split views and resizable panels
- Add tables, trees, and inspector-style rows
- Add scrollbars and large-list virtualization
- Add drag interactions for sliders, panes, and reordering
- Add focus ring and keyboard traversal semantics
- Build a sample editor shell with hierarchy, inspector, and viewport chrome

Exit criteria:

- Internal tools can be built without reinventing standard controls
- Keyboard-heavy workflows are viable
- Large datasets and inspector-like editing are practical

### 6. Clay Independence

Goal: make Clay optional and eventually removable.

Tasks:

- Define an internal layout IR independent from Clay commands
- Put layout and widget translation behind an engine interface
- Port current Clay-backed flow onto the internal IR boundary
- Implement first-party stack, row, grid, and overlay primitives
- Add a compatibility layer for existing examples and integrations
- Compare correctness and performance against the Clay-backed path
- Decide and document the deprecation plan for Clay
- Remove Clay as a required dependency once parity is reached

Exit criteria:

- Public API no longer depends conceptually on Clay
- Layout and interaction are owned by this library
- Clay can be retained as an adapter or removed entirely

## Recommended Sequencing

1. Menu-Ready Foundation
2. Hub UI Kit
3. GPU-Native Rendering
4. React-Like Authoring Layer
5. Tooling-Grade Widgets
6. Clay Independence

This order keeps the project useful early, validates the performance direction before making strong claims, and delays the Clay rewrite until the library has enough of its own layout and widget model to replace it safely.
