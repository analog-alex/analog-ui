const utf8 = @import("utf8.zig");

pub const Metrics = struct {
    line_height: f32,
    default_advance: f32,
};

pub const Size = struct {
    width: f32,
    height: f32,
};

pub fn measureText(text: []const u8, metrics: Metrics) !Size {
    var it = utf8.Utf8Iterator.init(text);
    var width: f32 = 0;
    var lines: u32 = 1;

    while (try it.nextCodepoint()) |cp| {
        if (cp == '\n') {
            lines += 1;
            continue;
        }
        width += metrics.default_advance;
    }

    return .{
        .width = width,
        .height = @as(f32, @floatFromInt(lines)) * metrics.line_height,
    };
}

test "measureText returns expected width for ascii" {
    const s = try measureText("abc", .{ .line_height = 10, .default_advance = 5 });
    try @import("std").testing.expectEqual(@as(f32, 15), s.width);
    try @import("std").testing.expectEqual(@as(f32, 10), s.height);
}

test "measureText counts lines" {
    const s = try measureText("a\nb", .{ .line_height = 12, .default_advance = 4 });
    try @import("std").testing.expectEqual(@as(f32, 24), s.height);
}
