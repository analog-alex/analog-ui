const std = @import("std");

pub const GlyphEntry = struct {
    codepoint: u21,
    atlas_page: u16,
    uv_min: [2]f32,
    uv_max: [2]f32,
    size_px: [2]u16,
    bearing_px: [2]i16,
    advance_px: f32,
};

pub const GlyphCache = struct {
    map: std.AutoHashMap(u21, GlyphEntry),

    pub fn init(allocator: std.mem.Allocator) GlyphCache {
        return .{ .map = std.AutoHashMap(u21, GlyphEntry).init(allocator) };
    }

    pub fn deinit(self: *GlyphCache) void {
        self.map.deinit();
    }

    pub fn put(self: *GlyphCache, entry: GlyphEntry) !void {
        try self.map.put(entry.codepoint, entry);
    }

    pub fn get(self: *const GlyphCache, cp: u21) ?GlyphEntry {
        return self.map.get(cp);
    }
};

test "GlyphCache hit/miss" {
    var cache = GlyphCache.init(std.testing.allocator);
    defer cache.deinit();

    try std.testing.expect(cache.get('A') == null);
    try cache.put(.{
        .codepoint = 'A',
        .atlas_page = 0,
        .uv_min = .{ 0, 0 },
        .uv_max = .{ 1, 1 },
        .size_px = .{ 8, 10 },
        .bearing_px = .{ 1, -2 },
        .advance_px = 7,
    });

    const found = cache.get('A');
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(f32, 7), found.?.advance_px);
}
