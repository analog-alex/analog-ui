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
