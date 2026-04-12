# DrawList Contract

`DrawList` is the renderer boundary for `analog_ui`.

This contract defines what producers (UI/context code) and consumers (renderer backends) can rely on.

## Semantics

- Ops are ordered in final paint order.
- `clip_push` / `clip_pop` define a stack and must be balanced.
- Geometry and color fields must be finite values.
- `text_run.size_px` must be finite and greater than zero.
- `stats.op_count` must match `ops.len`.

The core validator is `DrawList.validateContract()` in `src/core/draw_list.zig`.

## Ownership and lifetime

`DrawList.ops` is borrowed memory unless a specific producer says otherwise.

- `Builder.finish()` returns an owned slice from `toOwnedSlice()`; the caller owns and frees it.
- `Context.endFrame()` returns a slice backed by `Context.draw_ops`; it remains valid until the next `Context.endFrame()` call or `Context.deinit()`.

Backends must not retain `DrawList.ops` or pointers to op payload slices after `render()` returns.

## Text and image assumptions

- `text_run.text` is expected to be UTF-8.
- `font_handle` is interpreted by backend/font integration code.
- `image.image_id` is backend-defined. For SDL renderer integration in this repo, it is an encoded `SDL_Texture` pointer value.

## Backend responsibilities

Backends are responsible for:

- validating or assuming validated draw data before issuing GPU/SDL calls,
- honoring clip nesting behavior,
- preserving draw order,
- handling text/image ops according to the backend integration contract,
- avoiding ownership surprises (no hidden long-lived references to caller-owned draw data).

The SDL renderer backend currently validates every incoming draw list at the start of `render()`.
