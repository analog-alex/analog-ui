const std = @import("std");
const DrawList = @import("../core/draw_list.zig").DrawList;
const Color = @import("../core/draw_list.zig").Color;
const Rect = @import("../core/draw_list.zig").Rect;
const TextAlign = @import("../core/draw_list.zig").TextAlign;
const Font = @import("../font/font.zig").Font;
const utf8 = @import("../font/utf8.zig");
const RenderOptions = @import("common.zig").RenderOptions;
const sdl = @import("sdl_shared.zig");

const TexturePage = struct {
    width: u16,
    height: u16,
    texture: *sdl.SDL_Texture,
};

pub const RendererBackend = struct {
    allocator: std.mem.Allocator,
    renderer: *sdl.SDL_Renderer,
    clip_stack: std.array_list.Managed(sdl.SDL_Rect),
    atlas_pages: std.array_list.Managed(TexturePage),
    font: ?*Font,

    pub fn init(allocator: std.mem.Allocator, renderer: *sdl.SDL_Renderer) !RendererBackend {
        return .{
            .allocator = allocator,
            .renderer = renderer,
            .clip_stack = std.array_list.Managed(sdl.SDL_Rect).init(allocator),
            .atlas_pages = std.array_list.Managed(TexturePage).init(allocator),
            .font = null,
        };
    }

    pub fn deinit(self: *RendererBackend) void {
        for (self.atlas_pages.items) |page| {
            sdl.SDL_DestroyTexture(page.texture);
        }
        self.atlas_pages.deinit();
        self.clip_stack.deinit();
    }

    fn toU8(v: f32) u8 {
        const normalized = if (v <= 1.0) v * 255.0 else v;
        const clamped = std.math.clamp(normalized, 0.0, 255.0);
        return @intFromFloat(clamped);
    }

    fn setColor(self: *RendererBackend, c: Color) !void {
        if (!sdl.SDL_SetRenderDrawColor(self.renderer, toU8(c.r), toU8(c.g), toU8(c.b), toU8(c.a))) {
            return error.SdlRendererError;
        }
    }

    fn toFRect(rect: Rect) sdl.SDL_FRect {
        return .{ .x = rect.x, .y = rect.y, .w = rect.w, .h = rect.h };
    }

    fn fillFRect(self: *RendererBackend, rect: sdl.SDL_FRect) !void {
        if (rect.w <= 0 or rect.h <= 0) return;
        var mutable = rect;
        if (!sdl.SDL_RenderFillRect(self.renderer, &mutable)) {
            return error.SdlRendererError;
        }
    }

    fn clampRoundRadius(rect: Rect, radius: f32) f32 {
        const min_side = @min(rect.w, rect.h);
        if (!std.math.isFinite(radius) or radius <= 0.0 or min_side <= 0.0) {
            return 0.0;
        }
        return std.math.clamp(radius, 0.0, min_side * 0.5);
    }

    fn drawRoundedFilledRect(self: *RendererBackend, rect: Rect, radius: f32) !void {
        if (rect.w <= 0 or rect.h <= 0) return;

        const r = clampRoundRadius(rect, radius);
        if (r <= 0.5) {
            try self.fillFRect(toFRect(rect));
            return;
        }

        const center_w = rect.w - 2.0 * r;
        if (center_w > 0) {
            try self.fillFRect(.{ .x = rect.x + r, .y = rect.y, .w = center_w, .h = rect.h });
        }

        const middle_h = rect.h - 2.0 * r;
        if (middle_h > 0) {
            try self.fillFRect(.{ .x = rect.x, .y = rect.y + r, .w = rect.w, .h = middle_h });
        }

        const steps: i32 = @max(1, @as(i32, @intFromFloat(@ceil(r))));
        var yi: i32 = 0;
        while (yi < steps) : (yi += 1) {
            const sample_y = @as(f32, @floatFromInt(yi)) + 0.5;
            if (sample_y > r) break;

            const dy = r - sample_y;
            const dx = @sqrt(@max(0.0, r * r - dy * dy));
            const strip_x = rect.x + r - dx;
            const strip_w = rect.w - 2.0 * (r - dx);
            if (strip_w <= 0) continue;

            const top_y = rect.y + @as(f32, @floatFromInt(yi));
            const bottom_y = rect.y + rect.h - @as(f32, @floatFromInt(yi)) - 1.0;

            try self.fillFRect(.{ .x = strip_x, .y = top_y, .w = strip_w, .h = 1.0 });
            if (bottom_y > top_y) {
                try self.fillFRect(.{ .x = strip_x, .y = bottom_y, .w = strip_w, .h = 1.0 });
            }
        }
    }

    fn drawRectStroke(self: *RendererBackend, rect: Rect, thickness: f32) !void {
        const t = @max(thickness, 1.0);
        try self.fillFRect(.{ .x = rect.x, .y = rect.y, .w = rect.w, .h = t });
        try self.fillFRect(.{ .x = rect.x, .y = rect.y + rect.h - t, .w = rect.w, .h = t });
        try self.fillFRect(.{ .x = rect.x, .y = rect.y, .w = t, .h = rect.h });
        try self.fillFRect(.{ .x = rect.x + rect.w - t, .y = rect.y, .w = t, .h = rect.h });
    }

    fn drawRoundedStrokeRect(self: *RendererBackend, rect: Rect, thickness: f32, radius: f32) !void {
        if (rect.w <= 0 or rect.h <= 0) return;

        const t = @max(thickness, 1.0);
        const r = clampRoundRadius(rect, radius);
        if (r <= 0.5) {
            try self.drawRectStroke(rect, t);
            return;
        }

        const min_side = @min(rect.w, rect.h);
        if (t >= min_side * 0.5) {
            try self.drawRoundedFilledRect(rect, r);
            return;
        }

        const inner_r = @max(r - t, 0.0);

        const top_w = rect.w - 2.0 * r;
        if (top_w > 0) {
            try self.fillFRect(.{ .x = rect.x + r, .y = rect.y, .w = top_w, .h = t });
            try self.fillFRect(.{ .x = rect.x + r, .y = rect.y + rect.h - t, .w = top_w, .h = t });
        }

        const side_h = rect.h - 2.0 * r;
        if (side_h > 0) {
            try self.fillFRect(.{ .x = rect.x, .y = rect.y + r, .w = t, .h = side_h });
            try self.fillFRect(.{ .x = rect.x + rect.w - t, .y = rect.y + r, .w = t, .h = side_h });
        }

        const steps: i32 = @max(1, @as(i32, @intFromFloat(@ceil(r))));
        var yi: i32 = 0;
        while (yi < steps) : (yi += 1) {
            const sample_y = @as(f32, @floatFromInt(yi)) + 0.5;
            if (sample_y > r) break;

            const dy = r - sample_y;
            const outer_dx = @sqrt(@max(0.0, r * r - dy * dy));
            const inner_dx = if (dy < inner_r)
                @sqrt(@max(0.0, inner_r * inner_r - dy * dy))
            else
                0.0;

            const left_outer = rect.x + r - outer_dx;
            const left_inner = rect.x + r - inner_dx;
            const right_inner = rect.x + rect.w - r + inner_dx;
            const right_outer = rect.x + rect.w - r + outer_dx;

            const top_y = rect.y + @as(f32, @floatFromInt(yi));
            const bottom_y = rect.y + rect.h - @as(f32, @floatFromInt(yi)) - 1.0;

            if (left_inner > left_outer) {
                try self.fillFRect(.{ .x = left_outer, .y = top_y, .w = left_inner - left_outer, .h = 1.0 });
                if (bottom_y > top_y) {
                    try self.fillFRect(.{ .x = left_outer, .y = bottom_y, .w = left_inner - left_outer, .h = 1.0 });
                }
            }

            if (right_outer > right_inner) {
                try self.fillFRect(.{ .x = right_inner, .y = top_y, .w = right_outer - right_inner, .h = 1.0 });
                if (bottom_y > top_y) {
                    try self.fillFRect(.{ .x = right_inner, .y = bottom_y, .w = right_outer - right_inner, .h = 1.0 });
                }
            }
        }
    }

    fn toIRect(rect: Rect) sdl.SDL_Rect {
        return .{
            .x = @intFromFloat(rect.x),
            .y = @intFromFloat(rect.y),
            .w = @intFromFloat(rect.w),
            .h = @intFromFloat(rect.h),
        };
    }

    fn applyTopClip(self: *RendererBackend) !void {
        const maybe_top = if (self.clip_stack.items.len > 0)
            &self.clip_stack.items[self.clip_stack.items.len - 1]
        else
            null;

        if (!sdl.SDL_SetRenderClipRect(self.renderer, maybe_top)) {
            return error.SdlRendererError;
        }
    }

    fn ensurePageTexture(self: *RendererBackend, page_index: usize, width: u16, height: u16) !*sdl.SDL_Texture {
        if (page_index < self.atlas_pages.items.len) {
            const existing = &self.atlas_pages.items[page_index];
            if (existing.width == width and existing.height == height) {
                return existing.texture;
            }

            sdl.SDL_DestroyTexture(existing.texture);
            const recreated = sdl.SDL_CreateTexture(self.renderer, sdl.SDL_PIXELFORMAT_RGBA32, sdl.SDL_TEXTUREACCESS_STATIC, width, height) orelse {
                return error.SdlRendererError;
            };
            if (!sdl.SDL_SetTextureBlendMode(recreated, sdl.SDL_BLENDMODE_BLEND)) {
                sdl.SDL_DestroyTexture(recreated);
                return error.SdlRendererError;
            }
            existing.* = .{ .width = width, .height = height, .texture = recreated };
            return recreated;
        }

        const texture = sdl.SDL_CreateTexture(self.renderer, sdl.SDL_PIXELFORMAT_RGBA32, sdl.SDL_TEXTUREACCESS_STATIC, width, height) orelse {
            return error.SdlRendererError;
        };
        if (!sdl.SDL_SetTextureBlendMode(texture, sdl.SDL_BLENDMODE_BLEND)) {
            sdl.SDL_DestroyTexture(texture);
            return error.SdlRendererError;
        }

        try self.atlas_pages.append(.{ .width = width, .height = height, .texture = texture });
        return texture;
    }

    fn uploadDirtyRect(self: *RendererBackend, texture: *sdl.SDL_Texture, page_pixels: []const u8, page_width: u16, dirty: anytype) !void {
        const w = @as(usize, dirty.w);
        const h = @as(usize, dirty.h);
        if (w == 0 or h == 0) return;

        const rgba_len = w * h * 4;
        const rgba = try self.allocator.alloc(u8, rgba_len);
        defer self.allocator.free(rgba);

        var row: usize = 0;
        while (row < h) : (row += 1) {
            var col: usize = 0;
            while (col < w) : (col += 1) {
                const src_x = @as(usize, dirty.x) + col;
                const src_y = @as(usize, dirty.y) + row;
                const alpha = page_pixels[src_y * @as(usize, page_width) + src_x];
                const dst = (row * w + col) * 4;
                rgba[dst + 0] = 255;
                rgba[dst + 1] = 255;
                rgba[dst + 2] = 255;
                rgba[dst + 3] = alpha;
            }
        }

        var rect = sdl.SDL_Rect{
            .x = dirty.x,
            .y = dirty.y,
            .w = dirty.w,
            .h = dirty.h,
        };
        const pitch: c_int = @intCast(w * 4);
        if (!sdl.SDL_UpdateTexture(texture, &rect, rgba.ptr, pitch)) {
            return error.SdlRendererError;
        }
    }

    pub fn syncFont(self: *RendererBackend, font: *Font) !void {
        self.font = font;

        var page_index: usize = 0;
        while (page_index < font.pageCount()) : (page_index += 1) {
            const size = font.pageSize(page_index);
            const texture = try self.ensurePageTexture(page_index, size[0], size[1]);
            const page_pixels = font.pagePixels(page_index);
            const dirty = font.pageDirtyRects(page_index);

            for (dirty) |rect| {
                try self.uploadDirtyRect(texture, page_pixels, size[0], rect);
            }
            font.clearPageDirtyRects(page_index);
        }
    }

    fn drawGlyph(self: *RendererBackend, font: *const Font, codepoint: u21, x: *f32, baseline: f32, color: Color, inv_font_scale: f32) !void {
        const glyph = font.getGlyph(codepoint) orelse {
            x.* += (font.base_px * 0.55) * inv_font_scale;
            return;
        };

        if (glyph.size_px[0] == 0 or glyph.size_px[1] == 0) {
            x.* += glyph.advance_px * inv_font_scale;
            return;
        }

        const page_index: usize = glyph.atlas_page;
        if (page_index >= self.atlas_pages.items.len) {
            x.* += glyph.advance_px * inv_font_scale;
            return;
        }

        const texture_page = self.atlas_pages.items[page_index];
        try self.setColor(color);

        var src = sdl.SDL_FRect{
            .x = glyph.uv_min[0] * @as(f32, @floatFromInt(texture_page.width)),
            .y = glyph.uv_min[1] * @as(f32, @floatFromInt(texture_page.height)),
            .w = @as(f32, @floatFromInt(glyph.size_px[0])),
            .h = @as(f32, @floatFromInt(glyph.size_px[1])),
        };
        var dst = sdl.SDL_FRect{
            .x = x.* + @as(f32, @floatFromInt(glyph.bearing_px[0])) * inv_font_scale,
            .y = baseline + @as(f32, @floatFromInt(glyph.bearing_px[1])) * inv_font_scale,
            .w = @as(f32, @floatFromInt(glyph.size_px[0])) * inv_font_scale,
            .h = @as(f32, @floatFromInt(glyph.size_px[1])) * inv_font_scale,
        };

        if (!sdl.SDL_RenderTexture(self.renderer, texture_page.texture, &src, &dst)) {
            return error.SdlRendererError;
        }

        x.* += glyph.advance_px * inv_font_scale;
    }

    fn drawTextRun(self: *RendererBackend, rect: Rect, text: []const u8, alignment: TextAlign, color: Color, font_atlas_scale: f32) !void {
        const font = self.font orelse {
            return;
        };

        const inv_font_scale = if (std.math.isFinite(font_atlas_scale) and font_atlas_scale > 0.0)
            1.0 / font_atlas_scale
        else
            1.0;

        const measured = try font.measure(text);
        const measured_width = measured.width * inv_font_scale;
        var pen_x = rect.x;
        switch (alignment) {
            .left => {},
            .center => pen_x = rect.x + (rect.w - measured_width) * 0.5,
            .right => pen_x = rect.x + (rect.w - measured_width),
        }
        var pen_y = rect.y;

        var it = utf8.Utf8Iterator.init(text);
        while (try it.nextCodepoint()) |cp| {
            if (cp == '\n') {
                pen_x = rect.x;
                pen_y += (font.base_px * 1.2) * inv_font_scale;
                continue;
            }
            try self.drawGlyph(font, cp, &pen_x, pen_y, color, inv_font_scale);
        }
    }

    pub fn render(self: *RendererBackend, draw_list: DrawList, opts: RenderOptions) !void {
        try draw_list.validateContract();

        const dpi_scale = if (std.math.isFinite(opts.dpi_scale) and opts.dpi_scale > 0.0)
            opts.dpi_scale
        else
            1.0;
        const font_atlas_scale = if (std.math.isFinite(opts.font_atlas_scale) and opts.font_atlas_scale > 0.0)
            opts.font_atlas_scale
        else
            1.0;
        if (@hasDecl(sdl.c, "SDL_SetRenderScale")) {
            if (!sdl.c.SDL_SetRenderScale(self.renderer, dpi_scale, dpi_scale)) {
                return error.SdlRendererError;
            }
        }

        self.clip_stack.clearRetainingCapacity();
        try self.applyTopClip();

        for (draw_list.ops) |op| {
            switch (op) {
                .clip_push => |r| {
                    try self.clip_stack.append(toIRect(r));
                    try self.applyTopClip();
                },
                .clip_pop => {
                    if (self.clip_stack.items.len > 0) _ = self.clip_stack.pop();
                    try self.applyTopClip();
                },
                .rect_filled => |d| {
                    try self.setColor(d.color);
                    try self.drawRoundedFilledRect(d.rect, d.radius);
                },
                .rect_stroke => |d| {
                    try self.setColor(d.color);
                    try self.drawRoundedStrokeRect(d.rect, d.thickness, d.radius);
                },
                .text_run => |d| {
                    try self.drawTextRun(d.rect, d.text, d.alignment, d.color, font_atlas_scale);
                },
                .image => |d| {
                    const tex_ptr = @as(?*sdl.SDL_Texture, if (d.image_id == 0) null else @ptrFromInt(d.image_id));
                    if (tex_ptr) |texture| {
                        var dst = toFRect(d.rect);
                        if (!sdl.SDL_RenderTexture(self.renderer, texture, null, &dst)) return error.SdlRendererError;
                    }
                },
                .custom => {},
            }
        }

        self.clip_stack.clearRetainingCapacity();
        try self.applyTopClip();
    }
};

test "toU8 converts normalized and byte-range colors" {
    try std.testing.expectEqual(@as(u8, 255), RendererBackend.toU8(1.0));
    try std.testing.expectEqual(@as(u8, 128), RendererBackend.toU8(128.0));
}

test "clampRoundRadius clamps to half shortest side" {
    const rect = Rect{ .x = 0, .y = 0, .w = 120, .h = 40 };
    try std.testing.expectEqual(@as(f32, 20), RendererBackend.clampRoundRadius(rect, 999));
    try std.testing.expectEqual(@as(f32, 0), RendererBackend.clampRoundRadius(rect, -4));
}
