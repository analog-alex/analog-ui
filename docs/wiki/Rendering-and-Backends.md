# Rendering and Backends

The renderer boundary and backend status for `analog_ui`.

## Quick Nav

- [Home](Home.md)
- [Frame Loop](Frame-Loop.md)
- [Host Integration](Host-Integration.md)
- [Roadmap and Status](Roadmap-and-Status.md)

## Why This Matters

The project keeps core UI generation separate from rendering. That separation is centered on `DrawList`.

## `DrawList` Is The Boundary

`DrawList` is the backend-neutral output produced by UI code and consumed by renderers.

Important properties of the contract:

- ops are already in final paint order
- clip push and pop operations must stay balanced
- geometry and color values must be finite
- backends must not retain caller-owned op memory after render returns

```text
UI code
  -> DrawList
  -> backend validation
  -> SDL draw calls
```

The full contract is documented in `docs/draw_list_contract.md`.

## Backend Roles

### `RendererBackend`

This is the production baseline in the repo.

It is intended to render:

- rectangles
- borders
- text
- images
- clipping

### `GpuBackend`

This backend currently exists as a scaffold.

Treat it as non-production until the GPU path is implemented and documented as usable.

## Image Handle Model

For the SDL renderer path in this repo:

- `image_id` is a backend-defined handle
- in practice it is an encoded `*SDL_Texture` pointer value
- texture lifetime remains host-owned

## Validation

The SDL renderer backend validates incoming draw lists before rendering.

If you are debugging backend failures or custom draw data, the draw-list contract is the first thing to check.

## Best Reference

- `docs/draw_list_contract.md`
- `src/core/draw_list.zig`
- `src/backend/sdl_renderer.zig`

## Related Pages

- [Frame Loop](Frame-Loop.md)
- [Host Integration](Host-Integration.md)
- [Roadmap and Status](Roadmap-and-Status.md)
