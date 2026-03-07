const std = @import("std");

const c = @cImport({
    @cInclude("stb_truetype.h");
});

pub const GlyphBitmap = struct {
    width: u16,
    height: u16,
    bearing_x: i16,
    bearing_y: i16,
    advance_px: f32,
    alpha: []u8,

    pub fn deinit(self: *GlyphBitmap, allocator: std.mem.Allocator) void {
        allocator.free(self.alpha);
        self.* = undefined;
    }
};

pub const Rasterizer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Rasterizer {
        return .{ .allocator = allocator };
    }

    pub fn rasterizeCodepoint(self: *Rasterizer, ttf_bytes: []const u8, codepoint: u21, size_px: f32) !GlyphBitmap {
        if (ttf_bytes.len == 0) return error.InvalidFontData;
        if (size_px <= 0) return error.InvalidFontSize;

        var font_info: c.stbtt_fontinfo = undefined;
        if (c.stbtt_InitFont(&font_info, @ptrCast(ttf_bytes.ptr), 0) == 0) {
            return error.InvalidFontData;
        }

        const scale = c.stbtt_ScaleForPixelHeight(&font_info, size_px);

        var advance: c_int = 0;
        var left_bearing: c_int = 0;
        c.stbtt_GetCodepointHMetrics(&font_info, @intCast(codepoint), &advance, &left_bearing);

        var x0: c_int = 0;
        var y0: c_int = 0;
        var x1: c_int = 0;
        var y1: c_int = 0;
        c.stbtt_GetCodepointBitmapBox(&font_info, @intCast(codepoint), scale, scale, &x0, &y0, &x1, &y1);

        const w_i = x1 - x0;
        const h_i = y1 - y0;
        if (w_i <= 0 or h_i <= 0) {
            return .{
                .width = 0,
                .height = 0,
                .bearing_x = @intCast(x0),
                .bearing_y = @intCast(y0),
                .advance_px = @as(f32, @floatFromInt(advance)) * scale,
                .alpha = &.{},
            };
        }

        var bw: c_int = 0;
        var bh: c_int = 0;
        var xoff: c_int = 0;
        var yoff: c_int = 0;
        const bitmap_ptr = c.stbtt_GetCodepointBitmap(&font_info, scale, scale, @intCast(codepoint), &bw, &bh, &xoff, &yoff) orelse {
            return error.RasterizationFailed;
        };
        defer c.stbtt_FreeBitmap(bitmap_ptr, null);

        const pixel_count: usize = @intCast(bw * bh);
        const alpha = try self.allocator.alloc(u8, pixel_count);
        @memcpy(alpha, bitmap_ptr[0..pixel_count]);

        return .{
            .width = @intCast(bw),
            .height = @intCast(bh),
            .bearing_x = @intCast(xoff),
            .bearing_y = @intCast(yoff),
            .advance_px = @as(f32, @floatFromInt(advance)) * scale,
            .alpha = alpha,
        };
    }
};

test "Rasterizer rejects invalid inputs" {
    var r = Rasterizer.init(std.testing.allocator);
    try std.testing.expectError(error.InvalidFontData, r.rasterizeCodepoint("", 'A', 16));
    try std.testing.expectError(error.InvalidFontSize, r.rasterizeCodepoint("abc", 'A', 0));
}
