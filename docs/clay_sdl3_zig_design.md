# Design Document: Zig UI Library for Clay + SDL3

## Status
Draft v1

## Working Name
`clay_sdl3_ui`

## Goal
Build a high-performance Zig library that wraps Clay, loads fonts from TTF, renders UI through SDL3, and supports both SDL3 rendering paths:

- `SDL_Renderer`
- `SDL_GPU`

The library must target **Zig 0.15.x** and follow modern Zig library design practices: explicit allocators, minimal hidden work, strong error modeling, no ownership confusion, deterministic teardown, testability, and clear separation between platform, layout, font, and backend layers.

---

## 1. Problem Statement
Clay is a high-performance 2D UI layout library that is **renderer agnostic** and outputs a sorted list of render primitives rather than owning rendering itself. Clay also relies on user-provided text measurement and integration code for rendering, images, clipping, and platform input. That makes Clay an excellent fit for games, but it leaves a substantial amount of integration work to the host application.

This library will provide a reusable Zig-native integration layer that:

1. wraps Clay in a Zig-friendly API,
2. owns a text/font pipeline,
3. translates Clay output into backend-neutral draw operations,
4. renders those operations with either SDL3 backend,
5. is safe to embed in projects that already initialize and use SDL3.

---

## 2. Goals

### Functional goals
- Provide a Zig-first wrapper over Clay.
- Load TTF fonts and build glyph atlases.
- Measure UTF-8 text for Clay layout.
- Render UI through:
  - `SDL_Renderer`
  - `SDL_GPU`
- Support game menus and in-game HUDs.
- Support dynamic text and dynamic glyph caching.
- Support mouse, keyboard, and gamepad navigation.
- Support clipping/scissoring and z-ordered drawing.
- Be usable by applications that already own SDL lifecycle objects.

### Non-functional goals
- No global mutable state.
- No hidden heap allocation inside hot paths unless explicitly documented.
- Stable frame-to-frame performance.
- Strong separation of core logic from backend code.
- Easy unit testing without needing a window or GPU.
- Integration testing for both renderer paths.
- Predictable resource ownership.

### Non-goals for v1
- Rich text editing.
- Text shaping for complex scripts.
- Emoji fallback chains.
- Automatic asset hot reload.
- A fully general retained-mode scene graph.

---

## 3. External Constraints and Design Implications

### Zig version
The current latest stable Zig release is **0.15.2**, published on **2025-10-11**, and Zig 0.15.1 is also available. Designing for Zig 0.15.x is appropriate and up to date. citeturn1view0

### Clay constraints
Clay is explicitly renderer agnostic and outputs rendering primitives. It also requires a user-supplied text measurement function and uses a user-managed arena for its memory. Clay render commands include element IDs, support clipping via scissor start/end commands, and perform visibility culling by default. citeturn2view0turn2view3turn2view4turn2view1

### SDL3 constraints
SDL3 exposes two materially different rendering paths:
- `SDL_Renderer`, an immediate-style 2D rendering API
- `SDL_GPU`, a lower-level modern GPU API intended to resemble Metal, Vulkan, and D3D12 workflows

The library should not attempt to hide those differences completely; it should instead share a common core and provide separate backend implementations. citeturn1view3

### Zig library design constraints
Zig emphasizes explicit allocator passing, manual resource management, and low hidden behavior. The Zig build system is intended for reusable packages, and Zig’s testing model encourages ordinary code to be compiled and exercised directly through `zig test`. `std.heap.GeneralPurposeAllocator` can also be used to detect leaks during tests. citeturn3search5turn3search1turn3search0turn3search3

---

## 4. High-Level Architecture

The library should be split into four layers:

1. **Core UI layer**
   - Wraps Clay
   - Builds layout
   - Converts Clay commands into backend-neutral draw ops
   - Owns interaction state

2. **Font subsystem**
   - Loads TTF
   - Rasterizes glyphs
   - Packs atlas pages
   - Measures text
   - Supports dynamic glyph cache updates

3. **Backend-neutral render model**
   - `DrawList`
   - `DrawOp`
   - Texture handles abstracted via backend-owned IDs

4. **SDL3 backends**
   - `renderer_backend` for `SDL_Renderer`
   - `gpu_backend` for `SDL_GPU`

### Architectural rule
The UI core and font subsystem must be testable **without SDL window creation** and ideally without any SDL dependency beyond optional image/font helpers. Backend code should be the thinnest layer possible.

---

## 5. Module Layout

Recommended source tree:

```text
src/
  root.zig
  version.zig

  core/
    context.zig
    input.zig
    ids.zig
    theme.zig
    draw_list.zig
    widgets.zig
    clay_bridge.zig
    frame_arena.zig

  font/
    font.zig
    atlas.zig
    glyph_cache.zig
    rasterizer.zig
    measure.zig
    utf8.zig
    fallback.zig

  backend/
    common.zig
    sdl_renderer.zig
    sdl_gpu.zig
    sdl_shared.zig

  platform/
    sdl_events.zig
    sdl_keys.zig
    sdl_gamepad.zig

  c/
    clay.h
    clay_impl.c
    stb_truetype.h
    stb_truetype_impl.c

tests/
  unit/
  integration/
  golden/
  fixtures/
examples/
  menu_renderer/
  menu_gpu/
  hud_renderer/
  hud_gpu/
```

### Rationale
- Keeps Clay bridge separate from public widgets.
- Allows font logic to be reused independently.
- Keeps SDL-specific code out of core logic.
- Makes test boundaries obvious.

---

## 6. Core Design Principles

### 6.1 Explicit ownership
The application owns:
- SDL initialization and shutdown
- SDL window creation/destruction
- `SDL_Renderer` or `SDL_GPUDevice`
- frame loop timing
- asset loading policy

The library owns:
- Clay state
- UI interaction state
- font atlas state
- backend-specific UI rendering resources created through explicit init calls

### 6.2 Allocator-first APIs
Any API that allocates must take a `std.mem.Allocator`.

Rules:
- `init()` takes allocator explicitly.
- per-frame methods should not allocate from a general-purpose allocator in steady state.
- dynamic glyph insertion may allocate only if a new atlas page or metadata capacity is needed.
- all allocations must have matching teardown.

### 6.3 Zero hidden SDL lifecycle
Never call:
- `SDL_Init`
- `SDL_Quit`
- `SDL_CreateWindow`
- `SDL_CreateRenderer`
- `SDL_CreateGPUDevice`
inside the library.

### 6.4 Data-oriented frame processing
Each frame:
1. gather input
2. begin frame
3. build UI
4. ask Clay for commands
5. translate commands to `DrawList`
6. backend renders `DrawList`

No retained widget tree is required.

### 6.5 Stable IDs
All interactive widgets must use stable IDs. Clay render commands include IDs, which makes dirty checking and persistent mapping practical. This should be surfaced in Zig as either explicit `Id` values or string-based helper constructors. citeturn2view1

---

## 7. Public API Proposal

### 7.1 Core types

```zig
pub const Context = struct { ... };
pub const Font = struct { ... };
pub const DrawList = struct { ... };
pub const RendererBackend = struct { ... };
pub const GpuBackend = struct { ... };
pub const InputState = struct { ... };
pub const Theme = struct { ... };
pub const Id = packed struct(u64) { value: u64 };
```

### 7.2 Suggested user-facing API

```zig
var ctx = try ui.Context.init(alloc, .{
    .dpi_scale = 1.0,
    .theme = ui.Theme.default,
});
defer ctx.deinit();

var font = try ui.Font.initTtf(alloc, .{
    .ttf_bytes = ttf_bytes,
    .base_px = 24,
    .charset = .latin_1,
    .dynamic_glyphs = true,
});
defer font.deinit();

ctx.setDefaultFont(&font);

var backend = try ui.RendererBackend.init(alloc, sdl_renderer);
defer backend.deinit();

while (running) {
    const input = ui.InputState.fromSdlEvents(events, .{ .w = w, .h = h });

    ctx.beginFrame(.{
        .screen = .{ .w = w, .h = h },
        .input = input,
    });

    if (ctx.beginCenteredColumn(.{ .max_w = 420, .gap = 12 })) {
        defer ctx.endLayout();

        ctx.text("MY GAME", .{ .size = 42 });
        if (ctx.button(.fromStr("play"), "Play", .{})) startGame();
        if (ctx.button(.fromStr("quit"), "Quit", .{})) running = false;
    }

    const draw_list = try ctx.endFrame();
    try backend.syncFont(&font);
    try backend.render(draw_list, .{});
}
```

### 7.3 API design guidelines
- Prefer explicit option structs over long parameter lists.
- Prefer result-returning widget helpers (`bool` for pressed, etc.).
- Use small value types for draw ops.
- Keep backend-neutral interfaces free from SDL handles.

---

## 8. UI Core Design

## 8.1 Responsibilities
- Hold Clay memory arena and initialization state.
- Accept `InputState`.
- Expose ergonomic layout and widget helpers.
- Provide raw access for advanced Clay usage.
- Convert Clay commands to `DrawList`.
- Track interaction state:
  - hot item
  - active item
  - focused item
  - nav group state

### 8.2 Context internals

```text
Context
├── allocator
├── clay arena memory
├── clay state wrapper
├── input snapshot
├── frame scratch arena
├── draw list builder
├── theme
├── font registry
├── interaction state
└── metrics / debug counters
```

### 8.3 Recommended wrappers
Two API layers should coexist:

1. **Thin Clay bridge**
   - close to Clay semantics
   - useful for advanced users

2. **Opinionated helpers**
   - `button`
   - `label`
   - `panel`
   - `progressBar`
   - `anchor`
   - `menuColumn`
   - `hudBox`

This keeps the library useful both as a bridge and as a practical game UI toolkit.

### 8.4 Error handling
`beginFrame` should be infallible if initialization succeeded.
`endFrame` may fail only on library-owned transient resource issues such as scratch overflow or formatting failure.

Avoid using `panic` for recoverable library errors.

---

## 9. Font Subsystem Design

## 9.1 Requirements
- Load fonts from TTF bytes.
- Measure UTF-8 text for Clay.
- Render glyphs through atlas textures.
- Support Latin menu/HUD use cases in v1.
- Support dynamic glyph insertion.
- Avoid re-rasterizing common glyphs every frame.

## 9.2 Rasterizer choice
Recommended v1 rasterizer: **stb_truetype**.

Reasons:
- lightweight and widely used,
- easy C interop,
- no additional SDL font dependency required,
- straightforward atlas generation.

Alternative: optional future backend using `SDL_ttf` for users who prefer SDL-managed font parsing.

### 9.3 Font model

```text
Font
├── font source bytes
├── font metrics
├── glyph map: codepoint -> GlyphEntry
├── atlas pages[]
├── dirty regions per page
├── fallback chain[]
└── policy flags
```

### 9.4 Glyph entry

```zig
pub const GlyphEntry = struct {
    codepoint: u21,
    atlas_page: u16,
    uv_min: [2]f32,
    uv_max: [2]f32,
    size_px: [2]u16,
    bearing_px: [2]i16,
    advance_px: f32,
};
```

### 9.5 Atlas strategy
Recommended design:
- support **multiple atlas pages**,
- grayscale alpha atlas in CPU memory,
- backend-specific upload cache per page,
- skyline or shelf packing algorithm,
- track dirty rectangles for incremental upload.

### 9.6 Dynamic glyph caching
Policy:
- preload a configurable charset (`ascii`, `latin_1`, custom ranges),
- lazily insert missing glyphs on demand,
- if page full, allocate a new page,
- if allocation prohibited by runtime policy, substitute missing-glyph box.

### 9.7 Text measurement
Measurement must be backend-neutral and independent of SDL rendering.

Implementation details:
- decode UTF-8,
- map codepoints to glyphs,
- sum advances,
- support kerning if available,
- compute line height from font metrics,
- optionally cache measured spans for static strings.

### 9.8 v1 text shaping scope
v1 should support:
- UTF-8 decoding,
- simple left-to-right layout,
- line wrapping,
- kerning where practical.

v1 should not claim full complex script shaping.

---

## 10. Draw Model

## 10.1 DrawList
`DrawList` is the stable boundary between UI generation and rendering.

```zig
pub const DrawList = struct {
    ops: []const DrawOp,
    stats: Stats,
};
```

### 10.2 DrawOp

```zig
pub const DrawOp = union(enum) {
    clip_push: Rect,
    clip_pop: void,

    rect_filled: struct {
        rect: Rect,
        color: Color,
        radius: f32,
    },

    rect_stroke: struct {
        rect: Rect,
        color: Color,
        thickness: f32,
        radius: f32,
    },

    text_run: struct {
        rect: Rect,
        text: []const u8,
        font_handle: FontHandle,
        size_px: f32,
        color: Color,
        align: TextAlign,
    },

    image: struct {
        rect: Rect,
        image_id: ImageId,
        tint: Color,
    },

    custom: struct {
        id: Id,
        payload: ?*const anyopaque,
    },
};
```

### 10.3 DrawList invariants
- Ordered by final paint order.
- Clip nesting must be balanced.
- No backend pointers in ops.
- Slices must remain valid until backend render completes.

---

## 11. SDL_Renderer Backend Design

## 11.1 Responsibilities
- Own SDL textures for atlas pages.
- Upload dirty atlas regions.
- Render rects, borders, text quads, images, and clip rects.
- Avoid per-glyph texture creation.

## 11.2 Rendering model
- Translate text runs into textured quad draws from atlas textures.
- Use SDL clip rect calls for `clip_push` / `clip_pop`.
- Batch where possible, but do not overcomplicate v1 if SDL_Renderer backend already performs adequately for menus and HUD.

## 11.3 Performance notes
- Atlas uploads should be incremental.
- Rendering text from one atlas texture is significantly better than creating surfaces/textures for every label every frame.
- State changes should be minimized by ordering backend work by draw order while caching last bound texture and clip state.

## 11.4 Backend API

```zig
pub const RendererBackend = struct {
    pub fn init(alloc: Allocator, renderer: *SDL_Renderer) !RendererBackend;
    pub fn deinit(self: *RendererBackend) void;
    pub fn syncFont(self: *RendererBackend, font: *Font) !void;
    pub fn render(self: *RendererBackend, draw_list: DrawList, opts: RenderOptions) !void;
};
```

---

## 12. SDL_GPU Backend Design

## 12.1 Responsibilities
- Own GPU textures for atlas pages.
- Own pipeline, shader resources, buffers, and per-frame transient vertex/index storage.
- Translate draw ops into a batched quad renderer.

## 12.2 Rendering model
Recommended v1 strategy:
- convert rects and glyphs into quads,
- pack vertices into a transient mapped/upload buffer,
- issue batched draws grouped by texture and clip state,
- use SDL_GPU scissor state for clip ops.

## 12.3 Shader model
A minimal shader pair is sufficient:
- vertex shader: transform pixel coordinates to clip space,
- fragment shader: sample atlas alpha and multiply by vertex color.

Rounded corners can be approximated in v1 using extra geometry or deferred to future work. For v1, use plain rects first and add optional rounded-rect support later.

## 12.4 Per-frame resources
Use frame-cycled transient resources to avoid stalls. The SDL community’s published material on the SDL GPU API emphasizes modern explicit GPU workflows and includes dedicated discussions around transfer and cycling concepts. citeturn1view3turn0search12

## 12.5 Backend API

```zig
pub const GpuBackend = struct {
    pub fn init(alloc: Allocator, device: *SDL_GPUDevice, opts: InitOptions) !GpuBackend;
    pub fn deinit(self: *GpuBackend) void;
    pub fn syncFont(self: *GpuBackend, font: *Font, cmd: *SDL_GPUCommandBuffer) !void;
    pub fn render(
        self: *GpuBackend,
        draw_list: DrawList,
        cmd: *SDL_GPUCommandBuffer,
        target: RenderTarget,
        opts: RenderOptions,
    ) !void;
};
```

---

## 13. Input and Navigation Design

## 13.1 InputState
`InputState` should be backend-neutral and easy to populate from SDL events.

```zig
pub const InputState = struct {
    mouse_pos: Vec2,
    mouse_down: bool,
    mouse_pressed: bool,
    mouse_released: bool,
    scroll_x: f32,
    scroll_y: f32,

    nav_up: bool,
    nav_down: bool,
    nav_left: bool,
    nav_right: bool,
    nav_accept: bool,
    nav_back: bool,
};
```

## 13.2 SDL conversion layer
Provide helpers in `platform/sdl_events.zig` to:
- consume SDL event slices,
- normalize coordinates,
- map keyboard/gamepad events into nav actions,
- avoid exposing SDL types to core UI modules.

## 13.3 Focus policy
- menu widgets participate in directional navigation,
- HUD widgets generally do not,
- explicit focus groups should be supported.

---

## 14. Memory Management Strategy

## 14.1 Allocators by subsystem
Use distinct allocator roles:

- **long-lived allocator**: `Context`, `Font`, backend objects
- **frame arena**: draw list building, temporary formatting, transient command conversion
- **GPU transient buffers**: frame-cycled backend resources

## 14.2 No allocation in the hot path target
Steady-state frame target:
- no heap allocations in `beginFrame`, widget calls, `endFrame`, or backend `render`
- exceptions only for first-seen dynamic glyphs or controlled capacity growth

## 14.3 Clay arena
Clay requires a caller-provided memory arena sized from `Clay_MinMemorySize()` and initialized through a user-provided memory block. The Zig wrapper should allocate this once at initialization and keep it owned by `Context`. citeturn2view4

## 14.4 Failure policy
- capacity growth returns `error.OutOfMemory`
- atlas page creation returns `error.OutOfMemory`
- glyph rasterization failures return explicit font errors
- backend resource init failures return SDL-specific wrapped errors

---

## 15. C Interop Strategy

## 15.1 C dependencies
Recommended v1 C dependencies:
- `clay.h`
- `stb_truetype.h`

Compile implementation in exactly one translation unit each:
- `clay_impl.c`
- `stb_truetype_impl.c`

## 15.2 Why not expose C directly
Do not make end users call Clay macros from Zig-facing APIs. Instead:
- use internal bridge helpers,
- expose Zig wrappers that preserve performance but reduce macro awkwardness,
- optionally offer an `advanced` namespace for lower-level operations.

## 15.3 Build integration
Provide a package helper:

```zig
pub fn addTo(module: *std.Build.Module, opts: Options) void
```

and optionally:

```zig
pub fn link(step: *std.Build.Step.Compile, opts: Options) void
```

Important:
- document clearly that SDL linkage must happen once at the top level,
- avoid surprising transitive ownership of SDL system libraries.

The Zig build system is designed for reusable packages and explicit build graph modeling, which aligns well with this approach. citeturn3search1turn1view6

---

## 16. Performance Plan

## 16.1 Main targets
For common menu/HUD workloads:
- stable frame time
- O(number of visible draw ops)
- no per-label texture creation
- minimal clip state churn
- minimal atlas uploads after warm-up

Clay already performs visibility culling by default, so the backend should preserve and benefit from that behavior rather than rebuilding hidden work. citeturn2view1

## 16.2 Optimization priorities
Priority order:
1. eliminate hot-path allocations
2. eliminate repeated glyph rasterization
3. incremental atlas uploads
4. backend batching
5. reduce UTF-8 decode and measure churn for repeated strings

## 16.3 Metrics to collect
Expose debug counters:
- draw op count
- text run count
- glyph misses this frame
- atlas uploads this frame
- scissor changes
- backend draw calls
- frame scratch high-water mark

---

## 17. Best Practices Checklist

### Zig best practices
- explicit allocator parameters
- `defer` and `errdefer` for cleanup
- no hidden allocations
- return typed errors
- separate policy from mechanism
- keep public API small and composable
- avoid unnecessary global state
- make tests first-class

These practices align with Zig’s documented emphasis on explicit allocation, explicit error handling, and reusable package design. citeturn3search5turn3search0

### Library best practices
- do not own host lifecycle
- do not expose backend-specific state from core modules
- do not mix UI construction with rendering backend concerns
- expose predictable teardown semantics
- keep examples minimal but complete

### Rendering best practices
- backend-neutral draw model
- texture-atlas-based text rendering
- clip stack balancing assertions in debug builds
- frame-cycled transient buffers for GPU path

---

## 18. Testing Strategy

Testing must be split into three layers:

1. **pure unit tests**
2. **headless integration tests**
3. **interactive/manual verification examples**

A fourth optional layer is **golden tests** for draw-list output.

---

## 19. Unit Tests

Unit tests should avoid window creation and backend initialization whenever possible.

## 19.1 Core unit tests
Test modules:
- `ids.zig`
- `utf8.zig`
- `measure.zig`
- `glyph_cache.zig`
- `atlas.zig`
- `draw_list.zig`
- `input.zig`
- `theme.zig`

### Required unit cases
- stable ID hashing
- UTF-8 decode success/failure cases
- text measurement for ASCII and Latin-1
- wrapping logic
- atlas packer insertions and overflow behavior
- glyph cache hit/miss behavior
- dirty rect coalescing
- draw list clip balancing
- widget interaction transitions
- focus navigation transitions

## 19.2 Error-path tests
Specifically test:
- allocator failure injection
- atlas full policy
- invalid TTF bytes
- missing glyph fallback
- oversized text input
- frame scratch exhaustion

## 19.3 Memory-safety tests
Run core tests under `std.testing.allocator` where possible and also add a build mode using `GeneralPurposeAllocator` leak checks. Zig documents GPA-based leak detection explicitly, and `zig test` naturally compiles and runs test code. citeturn3search3turn3search0

---

## 20. Golden Tests

Golden tests are especially valuable for a UI library because they validate output stability without requiring a real renderer.

## 20.1 Golden test target
Golden tests should compare:
- serialized `DrawList`
- serialized glyph atlas metadata
- serialized text measurement results

### Example approach
- run a fixed widget tree,
- serialize `DrawOp`s into a stable textual form,
- compare against checked-in fixtures,
- update intentionally through a dedicated script.

## 20.2 Benefits
- catches layout regressions,
- backend-neutral,
- easy to review in code review,
- useful across operating systems.

---

## 21. Integration Tests

Integration tests should verify that the library works end-to-end with SDL3.

## 21.1 Renderer integration tests
Create an offscreen or hidden-window path where possible and verify:
- backend init succeeds,
- font sync succeeds,
- menu draw list renders without SDL errors,
- multiple frames render correctly,
- clip stack behaves correctly,
- texture updates occur when adding glyphs.

## 21.2 GPU integration tests
Create small SDL_GPU tests that:
- initialize device and window claim path,
- create backend,
- upload atlas,
- render a known draw list,
- submit command buffer successfully,
- repeat for multiple frames.

SDL’s GPU API is explicitly command-buffer oriented and structured around a device plus claimed window flow, so integration tests should mirror that shape. citeturn1view3

## 21.3 Platform considerations
Mark GPU integration tests as optional on environments lacking a compatible driver. The CI matrix should distinguish:
- always-run unit tests
- maybe-run renderer integration tests
- opt-in GPU integration tests

## 21.4 Headless verification pattern
Prefer asserting on:
- successful resource creation,
- pixel readback checks when feasible,
- expected draw counts,
- no SDL error string,
- no leaks.

If reliable pixel readback is difficult on all targets, fall back to backend event/stat assertions and keep pixel checks to a narrow supported matrix.

---

## 22. Manual and Visual Test Apps

Ship examples as test surfaces:
- `examples/menu_renderer`
- `examples/menu_gpu`
- `examples/hud_renderer`
- `examples/hud_gpu`
- `examples/font_stress`
- `examples/navigation_demo`

Each example should be tiny, deterministic, and useful for smoke testing.

### Recommended manual scenarios
- window resize stress
- DPI scale changes
- long text wrapping
- rapid glyph cache growth
- controller-only menu navigation
- mixed HUD + pause menu overlay
- font fallback chain behavior

---

## 23. CI Strategy

## 23.1 CI lanes
Recommended lanes:

1. **format + lint lane**
   - `zig fmt --check`
   - package build validation

2. **unit test lane**
   - Linux/macOS/Windows if practical
   - Debug and ReleaseSafe

3. **golden test lane**
   - deterministic fixture comparison

4. **renderer integration lane**
   - hidden window where supported

5. **GPU integration lane**
   - opt-in or limited supported runners

## 23.2 Artifact matrix
Run at least:
- latest Zig 0.15.x
- x86_64-linux
- x86_64-windows
- aarch64-macos if available

Use Zig’s supported target matrix pragmatically; 0.15.x includes tiered target support guidance that can inform CI coverage choices. citeturn3search2turn1view1

---

## 24. Build System Design

## 24.1 Package outputs
Expose:
- Zig module `clay_sdl3_ui`
- optional static library target for non-Zig consumers later
- examples
- tests

## 24.2 Build options
Recommended options:
- `use_sdl_gpu: bool`
- `use_sdl_renderer: bool`
- `enable_tracy: bool = false`
- `enable_examples: bool = true`
- `enable_integration_tests: bool = false`
- `font_backend: enum { stb }`

## 24.3 Test steps
Add explicit build steps:
- `zig build test-unit`
- `zig build test-golden`
- `zig build test-integration-renderer`
- `zig build test-integration-gpu`
- `zig build examples`

---

## 25. Security and Robustness Notes

- Treat all font bytes as untrusted input.
- Bounds-check all atlas writes.
- Validate UTF-8 before glyph lookup where necessary.
- Never trust clip stack balance from external callers; assert internally.
- Limit maximum glyph size and atlas page size.
- Limit formatted temporary text length in widget helpers.

---

## 26. Roadmap by Milestone

## Milestone 1: Core foundation
Deliverables:
- buildable package
- Clay bridge
- `Context`
- `DrawList`
- stable IDs
- theme and input basics
- unit tests for core modules

## Milestone 2: Font subsystem
Deliverables:
- TTF load from bytes
- atlas packer
- text measure
- static preload charset
- unit and golden tests

## Milestone 3: SDL_Renderer backend
Deliverables:
- atlas upload
- text quad rendering
- clip support
- menu example
- renderer integration tests

## Milestone 4: SDL_GPU backend
Deliverables:
- GPU atlas textures
- transient buffers
- text and rect batch rendering
- HUD example
- GPU smoke tests

## Milestone 5: Dynamic glyphs and navigation
Deliverables:
- dynamic glyph insertion
- keyboard/gamepad navigation
- HUD helpers
- stress examples

## Milestone 6: polish
Deliverables:
- docs
- performance counters
- CI expansion
- fallback chain support
- package release checklist

---

## 27. Task Breakdown

## Phase A: Project scaffolding
1. Create package skeleton and module layout.
2. Add C interop build steps for Clay and stb_truetype.
3. Add top-level build options and test steps.
4. Add `zig fmt` and CI skeleton.

## Phase B: Core UI layer
5. Implement `Id` generation and tests.
6. Implement `InputState` and SDL event translation.
7. Implement `DrawList` and `DrawOp` builder.
8. Implement `Context` initialization and Clay arena management.
9. Implement thin Clay bridge wrappers.
10. Implement interaction state machine.
11. Implement basic widgets: label, button, panel, anchor.
12. Add core unit tests and draw-list golden tests.

## Phase C: Font subsystem
13. Implement font loading from byte slice.
14. Implement UTF-8 decoding helpers.
15. Implement glyph metadata structures.
16. Implement atlas packer.
17. Implement stb rasterizer bridge.
18. Implement text measurement.
19. Implement preload charset support.
20. Implement missing-glyph fallback.
21. Add allocator-failure and malformed-font tests.
22. Add font golden fixtures.

## Phase D: SDL_Renderer backend
23. Implement backend init/deinit.
24. Implement atlas page upload and dirty rect sync.
25. Implement rect rendering.
26. Implement text run rendering from atlas.
27. Implement image rendering hooks.
28. Implement clip stack handling.
29. Add renderer smoke test example.
30. Add renderer integration tests.

## Phase E: SDL_GPU backend
31. Implement pipeline setup.
32. Implement texture upload path.
33. Implement transient vertex/index buffer system.
34. Implement quad batching.
35. Implement scissor state handling.
36. Add GPU smoke test example.
37. Add GPU integration tests.

## Phase F: Navigation and polish
38. Implement keyboard/gamepad navigation.
39. Implement focus groups.
40. Add menu and HUD helpers.
41. Add debug counters.
42. Add docs and API examples.
43. Add performance benchmarks.
44. Expand CI matrix.

---

## 28. Effort Estimate

The effort depends on how polished v1 must be.

### Lean v1
Includes:
- core wrapper
- static font atlas
- SDL_Renderer backend
- basic tests

Estimated effort: **3 to 5 weeks** for one experienced Zig/graphics developer.

### Full v1
Includes:
- dynamic glyph cache
- SDL_GPU backend
- integration tests
- examples and CI

Estimated effort: **6 to 10 weeks** for one experienced Zig/graphics developer.

### Major risk multipliers
- first-time SDL_GPU pipeline work,
- cross-platform CI for GPU,
- Unicode/shaping expectations expanding beyond v1 scope,
- over-generalizing the public API too early.

---

## 29. Recommended Implementation Order

Build in this exact order:

1. backend-neutral `DrawList`
2. `Context` + Clay bridge
3. static font atlas + measurement
4. `SDL_Renderer` backend
5. golden tests
6. dynamic glyph cache
7. `SDL_GPU` backend
8. integration tests
9. navigation and HUD helpers

This order minimizes risk because the GPU backend and dynamic glyph system both benefit from a stable draw model and stable font abstractions.

---

## 30. Recommended v1 Scope Decision

For the best chance of shipping a high-quality first release:

- ship `SDL_Renderer` first,
- keep `SDL_GPU` in the same repository but behind a feature/build option,
- support UTF-8 decoding but only simple shaping/layout,
- focus examples on menu and HUD,
- make golden tests a hard requirement before adding many widgets.

That yields a practical package quickly while preserving the architecture needed for the more advanced backend.

---

## 31. Final Recommendation

The library should be built as a **backend-neutral Zig UI package** with:
- Clay as the layout engine,
- a Zig-managed TTF atlas subsystem,
- one shared draw-list abstraction,
- two SDL3 rendering backends.

That structure matches Clay’s renderer-agnostic design, respects SDL3’s split rendering models, and follows Zig’s strengths around explicit ownership, allocator-driven APIs, and direct testability. citeturn2view0turn1view3turn3search5

It is a strong fit for:
- main menus,
- pause menus,
- settings screens,
- in-game HUD,
- controller-friendly game UI.

