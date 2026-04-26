const std = @import("std");
const FontRegistry = @import("registry.zig").FontRegistry;
const FontHandle = @import("../core/draw_list.zig").FontHandle;
const utf8 = @import("utf8.zig");
pub const Size = @import("font.zig").Size;

pub const LineRange = struct {
    start: usize,
    end: usize,
    width_px: f32,
};

fn advanceFor(registry: *FontRegistry, handle: FontHandle, cp: u21) !f32 {
    const base_font = registry.getFont(handle) orelse return error.InvalidFontHandle;
    const resolved = try registry.resolveGlyph(handle, cp);
    if (resolved) |entry| return entry.glyph.advance_px;
    return base_font.base_px * 0.55;
}

/// Measures UTF-8 text in logical UI pixels.
pub fn measure(registry: *FontRegistry, handle: FontHandle, text: []const u8) !Size {
    return registry.measureText(handle, text);
}

/// Wraps UTF-8 text into logical-width lines.
/// Returned ranges are byte offsets into the original `text` slice.
pub fn wrap(
    allocator: std.mem.Allocator,
    registry: *FontRegistry,
    handle: FontHandle,
    text: []const u8,
    max_width_px: f32,
) ![]LineRange {
    if (!std.math.isFinite(max_width_px) or max_width_px <= 0.0) {
        return error.InvalidWrapWidth;
    }

    var lines = std.array_list.Managed(LineRange).init(allocator);
    errdefer lines.deinit();

    var line_start: usize = 0;
    var line_width: f32 = 0.0;
    var last_break_index: ?usize = null;
    var last_break_width: f32 = 0.0;
    var last_break_next_start: usize = 0;

    var it = utf8.Utf8Iterator.init(text);
    while (true) {
        const cp_start = it.index;
        const maybe_cp = try it.nextCodepoint();
        if (maybe_cp == null) break;

        const cp = maybe_cp.?;
        const cp_end = it.index;

        if (cp == '\n') {
            try lines.append(.{ .start = line_start, .end = cp_start, .width_px = line_width });
            line_start = cp_end;
            line_width = 0.0;
            last_break_index = null;
            continue;
        }

        const cp_advance = try advanceFor(registry, handle, cp);
        if (cp == ' ' or cp == '\t') {
            last_break_index = cp_start;
            last_break_width = line_width;
            last_break_next_start = cp_end;
        }

        if (line_width + cp_advance <= max_width_px) {
            line_width += cp_advance;
            continue;
        }

        if (last_break_index) |break_index| {
            if (break_index > line_start) {
                try lines.append(.{ .start = line_start, .end = break_index, .width_px = last_break_width });
                line_start = last_break_next_start;
                line_width = 0.0;
                last_break_index = null;
                it.index = line_start;
                continue;
            }
        }

        if (cp_start == line_start) {
            try lines.append(.{ .start = line_start, .end = cp_end, .width_px = cp_advance });
            line_start = cp_end;
            line_width = 0.0;
            last_break_index = null;
            continue;
        }

        try lines.append(.{ .start = line_start, .end = cp_start, .width_px = line_width });
        line_start = cp_start;
        line_width = 0.0;
        last_break_index = null;
        it.index = line_start;
    }

    if (line_start <= text.len) {
        try lines.append(.{ .start = line_start, .end = text.len, .width_px = line_width });
    }

    return lines.toOwnedSlice();
}

/// Truncates UTF-8 text to fit logical width and appends an ellipsis if truncated.
pub fn truncateWithEllipsis(
    allocator: std.mem.Allocator,
    registry: *FontRegistry,
    handle: FontHandle,
    text: []const u8,
    max_width_px: f32,
    ellipsis: []const u8,
) ![]u8 {
    if (!std.math.isFinite(max_width_px) or max_width_px <= 0.0) {
        return error.InvalidTruncateWidth;
    }

    const full_size = try measure(registry, handle, text);
    if (full_size.width <= max_width_px) {
        return allocator.dupe(u8, text);
    }

    const ellipsis_size = try measure(registry, handle, ellipsis);

    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();

    var width: f32 = 0.0;
    var it = utf8.Utf8Iterator.init(text);
    while (true) {
        const cp_start = it.index;
        const maybe_cp = try it.nextCodepoint();
        if (maybe_cp == null) break;
        const cp = maybe_cp.?;

        if (cp == '\n') break;

        const cp_width = try advanceFor(registry, handle, cp);
        if (width + cp_width + ellipsis_size.width > max_width_px) {
            break;
        }

        try out.appendSlice(text[cp_start..it.index]);
        width += cp_width;
    }

    if (out.items.len == 0 and ellipsis.len > 0) {
        return allocator.dupe(u8, ellipsis);
    }

    try out.appendSlice(ellipsis);
    return out.toOwnedSlice();
}

test "measure reports logical pixel width" {
    var registry = FontRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const body = try registry.addTtf("body", .{
        .ttf_bytes = "fake-font-bytes",
        .base_px = 16,
        .dynamic_glyphs = false,
    });

    const size = try measure(&registry, body, "abc");
    try std.testing.expect(size.width > 0.0);
    try std.testing.expect(size.height > 0.0);
}

test "wrap splits lines by max width" {
    var registry = FontRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const body = try registry.addTtf("body", .{
        .ttf_bytes = "fake-font-bytes",
        .base_px = 16,
        .dynamic_glyphs = false,
    });

    const lines = try wrap(std.testing.allocator, &registry, body, "alpha beta gamma", 55.0);
    defer std.testing.allocator.free(lines);

    try std.testing.expect(lines.len >= 2);
    try std.testing.expectEqualStrings("alpha", "alpha beta gamma"[lines[0].start..lines[0].end]);
}

test "truncateWithEllipsis appends suffix when truncated" {
    var registry = FontRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const body = try registry.addTtf("body", .{
        .ttf_bytes = "fake-font-bytes",
        .base_px = 16,
        .dynamic_glyphs = false,
    });

    const out = try truncateWithEllipsis(std.testing.allocator, &registry, body, "settings menu", 50.0, "...");
    defer std.testing.allocator.free(out);

    try std.testing.expect(std.mem.endsWith(u8, out, "..."));
}
