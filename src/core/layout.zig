const std = @import("std");
const Rect = @import("draw_list.zig").Rect;

pub const Align = enum {
    start,
    center,
    end,
};

pub const Size = struct {
    w: f32,
    h: f32,
};

pub const Padding = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn all(value: f32) Padding {
        return .{ .top = value, .right = value, .bottom = value, .left = value };
    }

    pub fn symmetric(horizontal: f32, vertical: f32) Padding {
        return .{ .top = vertical, .right = horizontal, .bottom = vertical, .left = horizontal };
    }
};

pub const SplitOptions = struct {
    gap: f32 = 0,
    padding: Padding = .{},
    item_size: ?f32 = null,
    alignment: Align = .start,
};

pub fn inset(rect: Rect, padding: Padding) Rect {
    return .{
        .x = rect.x + padding.left,
        .y = rect.y + padding.top,
        .w = @max(0, rect.w - padding.left - padding.right),
        .h = @max(0, rect.h - padding.top - padding.bottom),
    };
}

fn alignOffset(extra_space: f32, alignment: Align) f32 {
    return switch (alignment) {
        .start => 0,
        .center => extra_space * 0.5,
        .end => extra_space,
    };
}

pub fn alignRect(container: Rect, size: Size, horizontal: Align, vertical: Align) Rect {
    const w = @min(@max(size.w, 0), container.w);
    const h = @min(@max(size.h, 0), container.h);
    return .{
        .x = container.x + alignOffset(container.w - w, horizontal),
        .y = container.y + alignOffset(container.h - h, vertical),
        .w = w,
        .h = h,
    };
}

pub fn splitRow(out: []Rect, container: Rect, opts: SplitOptions) void {
    if (out.len == 0) return;

    const content = inset(container, opts.padding);
    const count_f = @as(f32, @floatFromInt(out.len));
    const gap = @max(opts.gap, 0);
    const total_gap = if (out.len > 1) @as(f32, @floatFromInt(out.len - 1)) * gap else 0;
    const item_w = if (opts.item_size) |w|
        @max(w, 0)
    else
        @max(0, (content.w - total_gap) / count_f);
    const used_w = item_w * count_f + total_gap;
    const start_x = content.x + alignOffset(@max(0, content.w - used_w), opts.alignment);

    for (out, 0..) |*slot, i| {
        slot.* = .{
            .x = start_x + @as(f32, @floatFromInt(i)) * (item_w + gap),
            .y = content.y,
            .w = item_w,
            .h = content.h,
        };
    }
}

pub fn splitColumn(out: []Rect, container: Rect, opts: SplitOptions) void {
    if (out.len == 0) return;

    const content = inset(container, opts.padding);
    const count_f = @as(f32, @floatFromInt(out.len));
    const gap = @max(opts.gap, 0);
    const total_gap = if (out.len > 1) @as(f32, @floatFromInt(out.len - 1)) * gap else 0;
    const item_h = if (opts.item_size) |h|
        @max(h, 0)
    else
        @max(0, (content.h - total_gap) / count_f);
    const used_h = item_h * count_f + total_gap;
    const start_y = content.y + alignOffset(@max(0, content.h - used_h), opts.alignment);

    for (out, 0..) |*slot, i| {
        slot.* = .{
            .x = content.x,
            .y = start_y + @as(f32, @floatFromInt(i)) * (item_h + gap),
            .w = content.w,
            .h = item_h,
        };
    }
}

pub fn stack(out: []Rect, container: Rect, padding: Padding) void {
    const content = inset(container, padding);
    for (out) |*slot| {
        slot.* = content;
    }
}

test "splitColumn builds bottom-aligned button column" {
    var slots: [3]Rect = undefined;
    splitColumn(slots[0..], .{ .x = 100, .y = 100, .w = 300, .h = 300 }, .{
        .padding = Padding.symmetric(20, 20),
        .gap = 10,
        .item_size = 40,
        .alignment = .end,
    });

    try std.testing.expectApproxEqAbs(@as(f32, 120), slots[0].x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 220), slots[0].y, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 260), slots[0].w, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 40), slots[0].h, 0.0001);
}

test "splitRow distributes equal cells" {
    var slots: [2]Rect = undefined;
    splitRow(slots[0..], .{ .x = 0, .y = 0, .w = 110, .h = 20 }, .{ .gap = 10 });

    try std.testing.expectApproxEqAbs(@as(f32, 50), slots[0].w, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 60), slots[1].x, 0.0001);
}

test "alignRect centers fixed-size content" {
    const out = alignRect(.{ .x = 10, .y = 20, .w = 100, .h = 50 }, .{ .w = 40, .h = 10 }, .center, .center);
    try std.testing.expectApproxEqAbs(@as(f32, 40), out.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 40), out.y, 0.0001);
}
