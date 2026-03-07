const std = @import("std");

pub const Rect = struct {
    x: u16,
    y: u16,
    w: u16,
    h: u16,
};

pub const Page = struct {
    allocator: std.mem.Allocator,
    width: u16,
    height: u16,
    pixels: []u8,
    dirty_rects: std.array_list.Managed(Rect),
    shelf_x: u16,
    shelf_y: u16,
    shelf_h: u16,

    pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !Page {
        const pixels = try allocator.alloc(u8, @as(usize, width) * @as(usize, height));
        @memset(pixels, 0);

        var dirty_rects = std.array_list.Managed(Rect).init(allocator);
        try dirty_rects.append(.{ .x = 0, .y = 0, .w = width, .h = height });

        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = pixels,
            .dirty_rects = dirty_rects,
            .shelf_x = 0,
            .shelf_y = 0,
            .shelf_h = 0,
        };
    }

    pub fn deinit(self: *Page) void {
        self.dirty_rects.deinit();
        self.allocator.free(self.pixels);
    }

    pub fn insert(self: *Page, alpha: []const u8, w: u16, h: u16) !Rect {
        if (w == 0 or h == 0) return .{ .x = 0, .y = 0, .w = 0, .h = 0 };
        if (w > self.width or h > self.height) return error.AtlasTooSmall;
        if (alpha.len != @as(usize, w) * @as(usize, h)) return error.InvalidGlyphBitmap;

        if (self.shelf_x + w > self.width) {
            self.shelf_x = 0;
            self.shelf_y += self.shelf_h;
            self.shelf_h = 0;
        }

        if (self.shelf_y + h > self.height) return error.AtlasFull;

        const rect = Rect{
            .x = self.shelf_x,
            .y = self.shelf_y,
            .w = w,
            .h = h,
        };

        var row: usize = 0;
        while (row < h) : (row += 1) {
            const src_off = row * @as(usize, w);
            const dst_off = (@as(usize, rect.y) + row) * @as(usize, self.width) + @as(usize, rect.x);
            @memcpy(self.pixels[dst_off .. dst_off + @as(usize, w)], alpha[src_off .. src_off + @as(usize, w)]);
        }

        try self.dirty_rects.append(rect);

        self.shelf_x += w;
        if (h > self.shelf_h) self.shelf_h = h;
        return rect;
    }

    pub fn dirtyRects(self: *const Page) []const Rect {
        return self.dirty_rects.items;
    }

    pub fn clearDirtyRects(self: *Page) void {
        self.dirty_rects.clearRetainingCapacity();
    }
};

test "Page insert marks dirty and copies alpha" {
    var page = try Page.init(std.testing.allocator, 8, 8);
    defer page.deinit();

    const bitmap = [_]u8{ 10, 20, 30, 40 };
    const r = try page.insert(&bitmap, 2, 2);
    try std.testing.expectEqual(@as(u16, 2), r.w);
    try std.testing.expect(page.dirtyRects().len >= 1);

    const p0 = page.pixels[@as(usize, r.y) * 8 + @as(usize, r.x)];
    try std.testing.expectEqual(@as(u8, 10), p0);
}

test "Page reports full when out of room" {
    var page = try Page.init(std.testing.allocator, 4, 4);
    defer page.deinit();

    const bitmap = [_]u8{0} ** 16;
    _ = try page.insert(&bitmap, 4, 4);
    try std.testing.expectError(error.AtlasFull, page.insert(&[_]u8{1}, 1, 1));
}
