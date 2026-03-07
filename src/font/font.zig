const std = @import("std");
const utf8 = @import("utf8.zig");
const rasterizer_mod = @import("rasterizer.zig");
const glyph_cache_mod = @import("glyph_cache.zig");
const atlas_mod = @import("atlas.zig");

pub const Charset = enum {
    ascii,
    latin_1,
};

pub const Size = struct {
    width: f32,
    height: f32,
};

pub const InitTtfOptions = struct {
    ttf_bytes: []const u8,
    base_px: f32,
    charset: Charset = .ascii,
    dynamic_glyphs: bool = true,
    atlas_page_size: u16 = 512,
};

pub const Font = struct {
    allocator: std.mem.Allocator,
    ttf_bytes: []u8,
    base_px: f32,
    dynamic_glyphs: bool,
    rasterizer: rasterizer_mod.Rasterizer,
    cache: glyph_cache_mod.GlyphCache,
    pages: std.array_list.Managed(atlas_mod.Page),

    fn looksLikeTtf(bytes: []const u8) bool {
        if (bytes.len < 4) return false;
        const tag = bytes[0..4];
        return std.mem.eql(u8, tag, "\x00\x01\x00\x00") or
            std.mem.eql(u8, tag, "OTTO") or
            std.mem.eql(u8, tag, "ttcf") or
            std.mem.eql(u8, tag, "true");
    }

    pub fn initTtf(allocator: std.mem.Allocator, opts: InitTtfOptions) !Font {
        if (opts.ttf_bytes.len == 0) return error.InvalidFontData;
        if (opts.base_px <= 0) return error.InvalidFontSize;
        if (opts.atlas_page_size == 0) return error.InvalidAtlasSize;

        const bytes = try allocator.dupe(u8, opts.ttf_bytes);
        var font = Font{
            .allocator = allocator,
            .ttf_bytes = bytes,
            .base_px = opts.base_px,
            .dynamic_glyphs = opts.dynamic_glyphs and looksLikeTtf(opts.ttf_bytes),
            .rasterizer = rasterizer_mod.Rasterizer.init(allocator),
            .cache = glyph_cache_mod.GlyphCache.init(allocator),
            .pages = std.array_list.Managed(atlas_mod.Page).init(allocator),
        };
        errdefer font.deinit();

        try font.pages.append(try atlas_mod.Page.init(allocator, opts.atlas_page_size, opts.atlas_page_size));
        try font.preloadCharset(opts.charset);

        return font;
    }

    pub fn deinit(self: *Font) void {
        for (self.pages.items) |*page| page.deinit();
        self.pages.deinit();
        self.cache.deinit();
        self.allocator.free(self.ttf_bytes);
    }

    pub fn pageCount(self: *const Font) usize {
        return self.pages.items.len;
    }

    pub fn pageSize(self: *const Font, page_index: usize) [2]u16 {
        const p = self.pages.items[page_index];
        return .{ p.width, p.height };
    }

    pub fn pagePixels(self: *const Font, page_index: usize) []const u8 {
        return self.pages.items[page_index].pixels;
    }

    pub fn pageDirtyRects(self: *const Font, page_index: usize) []const atlas_mod.Rect {
        return self.pages.items[page_index].dirtyRects();
    }

    pub fn clearPageDirtyRects(self: *Font, page_index: usize) void {
        self.pages.items[page_index].clearDirtyRects();
    }

    pub fn getGlyph(self: *const Font, codepoint: u21) ?glyph_cache_mod.GlyphEntry {
        return self.cache.get(codepoint);
    }

    fn preloadCharset(self: *Font, charset: Charset) !void {
        switch (charset) {
            .ascii => {
                var cp: u21 = 32;
                while (cp <= 126) : (cp += 1) {
                    _ = self.ensureGlyph(cp) catch {};
                }
            },
            .latin_1 => {
                var cp: u21 = 32;
                while (cp <= 255) : (cp += 1) {
                    _ = self.ensureGlyph(cp) catch {};
                }
            },
        }
    }

    fn insertBitmap(self: *Font, alpha: []const u8, w: u16, h: u16) !struct { page: u16, rect: atlas_mod.Rect } {
        var page_index: usize = 0;
        while (page_index < self.pages.items.len) : (page_index += 1) {
            const rect = self.pages.items[page_index].insert(alpha, w, h) catch |err| switch (err) {
                error.AtlasFull => continue,
                else => return err,
            };
            return .{ .page = @intCast(page_index), .rect = rect };
        }

        const size = self.pages.items[0].width;
        try self.pages.append(try atlas_mod.Page.init(self.allocator, size, size));
        const new_page_idx = self.pages.items.len - 1;
        const rect = try self.pages.items[new_page_idx].insert(alpha, w, h);
        return .{ .page = @intCast(new_page_idx), .rect = rect };
    }

    fn ensureGlyph(self: *Font, codepoint: u21) !glyph_cache_mod.GlyphEntry {
        if (self.cache.get(codepoint)) |entry| {
            return entry;
        }

        if (!self.dynamic_glyphs) {
            return .{
                .codepoint = codepoint,
                .atlas_page = 0,
                .uv_min = .{ 0, 0 },
                .uv_max = .{ 0, 0 },
                .size_px = .{ 0, 0 },
                .bearing_px = .{ 0, 0 },
                .advance_px = self.base_px * 0.55,
            };
        }

        var bitmap = self.rasterizer.rasterizeCodepoint(self.ttf_bytes, codepoint, self.base_px) catch {
            return .{
                .codepoint = codepoint,
                .atlas_page = 0,
                .uv_min = .{ 0, 0 },
                .uv_max = .{ 0, 0 },
                .size_px = .{ 0, 0 },
                .bearing_px = .{ 0, 0 },
                .advance_px = self.base_px * 0.55,
            };
        };
        defer if (bitmap.alpha.len > 0) bitmap.deinit(self.allocator);

        var page: u16 = 0;
        var uv_min: [2]f32 = .{ 0, 0 };
        var uv_max: [2]f32 = .{ 0, 0 };

        if (bitmap.width > 0 and bitmap.height > 0) {
            const inserted = try self.insertBitmap(bitmap.alpha, bitmap.width, bitmap.height);
            page = inserted.page;
            const page_info = self.pages.items[inserted.page];

            uv_min = .{
                @as(f32, @floatFromInt(inserted.rect.x)) / @as(f32, @floatFromInt(page_info.width)),
                @as(f32, @floatFromInt(inserted.rect.y)) / @as(f32, @floatFromInt(page_info.height)),
            };
            uv_max = .{
                @as(f32, @floatFromInt(inserted.rect.x + inserted.rect.w)) / @as(f32, @floatFromInt(page_info.width)),
                @as(f32, @floatFromInt(inserted.rect.y + inserted.rect.h)) / @as(f32, @floatFromInt(page_info.height)),
            };
        }

        const entry = glyph_cache_mod.GlyphEntry{
            .codepoint = codepoint,
            .atlas_page = page,
            .uv_min = uv_min,
            .uv_max = uv_max,
            .size_px = .{ bitmap.width, bitmap.height },
            .bearing_px = .{ bitmap.bearing_x, bitmap.bearing_y },
            .advance_px = bitmap.advance_px,
        };

        try self.cache.put(entry);
        return entry;
    }

    pub fn measure(self: *Font, text: []const u8) !Size {
        var it = utf8.Utf8Iterator.init(text);
        var line_width: f32 = 0;
        var max_width: f32 = 0;
        var line_count: u32 = 1;

        while (try it.nextCodepoint()) |cp| {
            if (cp == '\n') {
                max_width = @max(max_width, line_width);
                line_width = 0;
                line_count += 1;
                continue;
            }

            const glyph = try self.ensureGlyph(cp);
            line_width += glyph.advance_px;
        }
        max_width = @max(max_width, line_width);

        return .{
            .width = max_width,
            .height = @as(f32, @floatFromInt(line_count)) * (self.base_px * 1.2),
        };
    }
};

test "Font.initTtf rejects empty bytes" {
    try std.testing.expectError(error.InvalidFontData, Font.initTtf(std.testing.allocator, .{
        .ttf_bytes = "",
        .base_px = 16,
    }));
}

test "Font.measure returns positive width for plain text" {
    var font = try Font.initTtf(std.testing.allocator, .{
        .ttf_bytes = "fake-font-bytes",
        .base_px = 16,
        .dynamic_glyphs = false,
    });
    defer font.deinit();

    const s = try font.measure("abc");
    try std.testing.expect(s.width > 0);
}
