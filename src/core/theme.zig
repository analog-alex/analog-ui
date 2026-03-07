pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const Theme = struct {
    text: Color,
    background: Color,
    panel: Color,
    accent: Color,

    pub const default = Theme{
        .text = .{ .r = 0.95, .g = 0.95, .b = 0.95, .a = 1.0 },
        .background = .{ .r = 0.08, .g = 0.09, .b = 0.1, .a = 1.0 },
        .panel = .{ .r = 0.14, .g = 0.15, .b = 0.17, .a = 1.0 },
        .accent = .{ .r = 0.2, .g = 0.65, .b = 0.9, .a = 1.0 },
    };
};

test "Theme.default has opaque colors" {
    const t = Theme.default;
    try @import("std").testing.expectEqual(@as(f32, 1.0), t.text.a);
    try @import("std").testing.expectEqual(@as(f32, 1.0), t.background.a);
}
