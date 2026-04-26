const std = @import("std");
const FontHandle = @import("../core/draw_list.zig").FontHandle;
const Font = @import("font.zig").Font;
const InitTtfOptions = @import("font.zig").InitTtfOptions;
const utf8 = @import("utf8.zig");

pub const ResolvedGlyph = struct {
    handle: FontHandle,
    glyph: @import("glyph_cache.zig").GlyphEntry,
};

const Entry = struct {
    name: []u8,
    font: Font,
    fallback: std.array_list.Managed(FontHandle),
};

pub const FontRegistry = struct {
    allocator: std.mem.Allocator,
    entries: std.array_list.Managed(Entry),

    pub fn init(allocator: std.mem.Allocator) FontRegistry {
        return .{
            .allocator = allocator,
            .entries = std.array_list.Managed(Entry).init(allocator),
        };
    }

    pub fn deinit(self: *FontRegistry) void {
        for (self.entries.items) |*entry| {
            entry.font.deinit();
            entry.fallback.deinit();
            self.allocator.free(entry.name);
        }
        self.entries.deinit();
    }

    fn toIndex(handle: FontHandle) ?usize {
        if (handle == 0) return null;
        return @as(usize, handle - 1);
    }

    fn validateHandle(self: *const FontRegistry, handle: FontHandle) !usize {
        const index = toIndex(handle) orelse return error.InvalidFontHandle;
        if (index >= self.entries.items.len) return error.InvalidFontHandle;
        return index;
    }

    pub fn addFont(self: *FontRegistry, name: []const u8, font: Font) !FontHandle {
        if (self.entries.items.len >= std.math.maxInt(FontHandle)) {
            return error.FontHandleOverflow;
        }

        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        try self.entries.append(.{
            .name = owned_name,
            .font = font,
            .fallback = std.array_list.Managed(FontHandle).init(self.allocator),
        });

        return @intCast(self.entries.items.len);
    }

    pub fn addTtf(self: *FontRegistry, name: []const u8, opts: InitTtfOptions) !FontHandle {
        var font = try Font.initTtf(self.allocator, opts);
        errdefer font.deinit();
        return self.addFont(name, font);
    }

    pub fn setFallback(self: *FontRegistry, primary: FontHandle, fallbacks: []const FontHandle) !void {
        const index = try self.validateHandle(primary);
        var chain = &self.entries.items[index].fallback;
        chain.clearRetainingCapacity();

        for (fallbacks) |handle| {
            if (handle == primary) return error.InvalidFallbackChain;
            _ = try self.validateHandle(handle);
            try chain.append(handle);
        }
    }

    pub fn fontCount(self: *const FontRegistry) usize {
        return self.entries.items.len;
    }

    pub fn fontHandleAt(self: *const FontRegistry, index: usize) FontHandle {
        _ = self;
        return @intCast(index + 1);
    }

    pub fn getFont(self: *const FontRegistry, handle: FontHandle) ?*Font {
        const index = toIndex(handle) orelse return null;
        if (index >= self.entries.items.len) return null;
        return @constCast(&self.entries.items[index].font);
    }

    pub fn getFallback(self: *const FontRegistry, primary: FontHandle) ?[]const FontHandle {
        const index = toIndex(primary) orelse return null;
        if (index >= self.entries.items.len) return null;
        return self.entries.items[index].fallback.items;
    }

    fn resolveGlyphInHandle(self: *FontRegistry, handle: FontHandle, codepoint: u21) !?ResolvedGlyph {
        const font = self.getFont(handle) orelse return null;
        const glyph = try font.ensureGlyph(codepoint);
        return .{ .handle = handle, .glyph = glyph };
    }

    pub fn resolveGlyph(self: *FontRegistry, primary: FontHandle, codepoint: u21) !?ResolvedGlyph {
        if (primary == 0) return null;

        var first: ?ResolvedGlyph = null;
        if (try self.resolveGlyphInHandle(primary, codepoint)) |resolved| {
            if (!resolved.glyph.is_missing) return resolved;
            first = resolved;
        }

        const fallback = self.getFallback(primary) orelse return first;
        for (fallback) |handle| {
            if (try self.resolveGlyphInHandle(handle, codepoint)) |resolved| {
                if (!resolved.glyph.is_missing) return resolved;
                if (first == null) first = resolved;
            }
        }

        return first;
    }

    pub fn ensureText(self: *FontRegistry, primary: FontHandle, text: []const u8) !void {
        if (primary == 0) return;

        var it = utf8.Utf8Iterator.init(text);
        while (try it.nextCodepoint()) |cp| {
            if (cp == '\n') continue;
            _ = try self.resolveGlyph(primary, cp);
        }
    }

    pub fn measureText(self: *FontRegistry, primary: FontHandle, text: []const u8) !@import("font.zig").Size {
        if (primary == 0) {
            return .{ .width = 0, .height = 0 };
        }

        const primary_font = self.getFont(primary) orelse return error.InvalidFontHandle;
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

            const resolved = try self.resolveGlyph(primary, cp);
            if (resolved) |item| {
                line_width += item.glyph.advance_px;
            } else {
                line_width += primary_font.base_px * 0.55;
            }
        }
        max_width = @max(max_width, line_width);

        return .{
            .width = max_width,
            .height = @as(f32, @floatFromInt(line_count)) * (primary_font.base_px * 1.2),
        };
    }
};

test "FontRegistry add and fallback chain" {
    var registry = FontRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const body = try registry.addTtf("body", .{
        .ttf_bytes = "fake-font-bytes",
        .base_px = 16,
        .dynamic_glyphs = false,
    });
    const cjk = try registry.addTtf("cjk", .{
        .ttf_bytes = "fake-font-bytes",
        .base_px = 16,
        .dynamic_glyphs = false,
    });

    try std.testing.expect(body != cjk);
    try registry.setFallback(body, &.{cjk});

    const chain = registry.getFallback(body) orelse unreachable;
    try std.testing.expectEqual(@as(usize, 1), chain.len);
    try std.testing.expectEqual(cjk, chain[0]);
}
