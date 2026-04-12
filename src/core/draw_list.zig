const std = @import("std");

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const TextAlign = enum {
    left,
    center,
    right,
};

pub const FontHandle = u16;

pub const ImageId = usize;

pub const DrawOp = union(enum) {
    clip_push: Rect,
    clip_pop: void,

    rect_filled: struct {
        rect: Rect,
        color: Color,
        radius: f32,
    },

    rect_stroke: struct {
        rect: Rect,
        color: Color,
        thickness: f32,
        radius: f32,
    },

    text_run: struct {
        rect: Rect,
        text: []const u8,
        font_handle: FontHandle,
        size_px: f32,
        color: Color,
        alignment: TextAlign,
    },

    image: struct {
        rect: Rect,
        image_id: ImageId,
        tint: Color,
    },

    custom: struct {
        id: u32,
        payload: ?*const anyopaque,
    },
};

pub const Stats = struct {
    op_count: u32 = 0,
};

pub const DrawList = struct {
    ops: []const DrawOp,
    stats: Stats,

    pub const ContractError = error{
        InvalidStatsOpCount,
        InvalidRect,
        InvalidColor,
        InvalidTextSize,
        UnbalancedClipPop,
        UnbalancedClipStack,
    };

    fn isFiniteRect(rect: Rect) bool {
        return std.math.isFinite(rect.x) and std.math.isFinite(rect.y) and std.math.isFinite(rect.w) and std.math.isFinite(rect.h);
    }

    fn isFiniteColor(color: Color) bool {
        return std.math.isFinite(color.r) and std.math.isFinite(color.g) and std.math.isFinite(color.b) and std.math.isFinite(color.a);
    }

    pub fn validateContract(self: DrawList) ContractError!void {
        if (self.stats.op_count != self.ops.len) return error.InvalidStatsOpCount;

        var clip_depth: usize = 0;
        for (self.ops) |op| {
            switch (op) {
                .clip_push => |rect| {
                    if (!isFiniteRect(rect)) return error.InvalidRect;
                    clip_depth += 1;
                },
                .clip_pop => {
                    if (clip_depth == 0) return error.UnbalancedClipPop;
                    clip_depth -= 1;
                },
                .rect_filled => |d| {
                    if (!isFiniteRect(d.rect)) return error.InvalidRect;
                    if (!isFiniteColor(d.color)) return error.InvalidColor;
                },
                .rect_stroke => |d| {
                    if (!isFiniteRect(d.rect)) return error.InvalidRect;
                    if (!isFiniteColor(d.color)) return error.InvalidColor;
                    if (!std.math.isFinite(d.thickness) or !std.math.isFinite(d.radius)) return error.InvalidRect;
                },
                .text_run => |d| {
                    if (!isFiniteRect(d.rect)) return error.InvalidRect;
                    if (!isFiniteColor(d.color)) return error.InvalidColor;
                    if (!std.math.isFinite(d.size_px) or d.size_px <= 0.0) return error.InvalidTextSize;
                },
                .image => |d| {
                    if (!isFiniteRect(d.rect)) return error.InvalidRect;
                    if (!isFiniteColor(d.tint)) return error.InvalidColor;
                },
                .custom => {},
            }
        }

        if (clip_depth != 0) return error.UnbalancedClipStack;
    }
};

pub const Builder = struct {
    allocator: std.mem.Allocator,
    ops: std.array_list.Managed(DrawOp),
    clip_depth: usize,

    pub fn init(allocator: std.mem.Allocator) Builder {
        return .{
            .allocator = allocator,
            .ops = std.array_list.Managed(DrawOp).init(allocator),
            .clip_depth = 0,
        };
    }

    pub fn deinit(self: *Builder) void {
        self.ops.deinit();
    }

    pub fn push(self: *Builder, op: DrawOp) !void {
        switch (op) {
            .clip_push => self.clip_depth += 1,
            .clip_pop => {
                if (self.clip_depth == 0) return error.UnbalancedClipPop;
                self.clip_depth -= 1;
            },
            else => {},
        }
        try self.ops.append(op);
    }

    pub fn finish(self: *Builder) !DrawList {
        if (self.clip_depth != 0) return error.UnbalancedClipStack;
        return .{
            .ops = try self.ops.toOwnedSlice(),
            .stats = .{ .op_count = @intCast(self.ops.items.len) },
        };
    }
};

test "DrawList builder validates clip stack" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();

    try builder.push(.{ .clip_push = .{ .x = 0, .y = 0, .w = 10, .h = 10 } });
    try builder.push(.{ .clip_pop = {} });
    const dl = try builder.finish();
    defer std.testing.allocator.free(dl.ops);

    try std.testing.expectEqual(@as(u32, 2), dl.stats.op_count);
}

test "DrawList builder catches unbalanced clip pop" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();

    try std.testing.expectError(error.UnbalancedClipPop, builder.push(.{ .clip_pop = {} }));
}

test "DrawList contract validation catches mismatched stats" {
    const dl = DrawList{
        .ops = &.{},
        .stats = .{ .op_count = 1 },
    };

    try std.testing.expectError(error.InvalidStatsOpCount, dl.validateContract());
}

test "DrawList contract validation catches invalid text size" {
    const dl = DrawList{
        .ops = &.{.{ .text_run = .{
            .rect = .{ .x = 0, .y = 0, .w = 40, .h = 20 },
            .text = "hello",
            .font_handle = 0,
            .size_px = 0,
            .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
            .alignment = .left,
        } }},
        .stats = .{ .op_count = 1 },
    };

    try std.testing.expectError(error.InvalidTextSize, dl.validateContract());
}

test "DrawList contract validation catches unbalanced clip stack" {
    const dl = DrawList{
        .ops = &.{.{ .clip_push = .{ .x = 0, .y = 0, .w = 10, .h = 10 } }},
        .stats = .{ .op_count = 1 },
    };

    try std.testing.expectError(error.UnbalancedClipStack, dl.validateContract());
}
