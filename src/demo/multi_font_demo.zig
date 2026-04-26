const std = @import("std");
const ui = @import("../root.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const fake_ttf = "not-a-real-ttf";

    var fonts = ui.FontRegistry.init(allocator);
    defer fonts.deinit();

    const body = try fonts.addTtf("Body", .{
        .ttf_bytes = fake_ttf,
        .base_px = 16,
        .dynamic_glyphs = false,
    });
    const cjk = try fonts.addTtf("NotoSansCJK", .{
        .ttf_bytes = fake_ttf,
        .base_px = 16,
        .dynamic_glyphs = false,
    });
    try fonts.setFallback(body, &.{cjk});

    const measured = try ui.Text.measure(&fonts, body, "Menu 設定");
    if (!(measured.width > 0 and measured.height > 0)) {
        return error.InvalidTextMeasurement;
    }
}

test "multi font demo compiles and runs" {
    try run(std.testing.allocator);
}
