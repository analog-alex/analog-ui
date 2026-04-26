const std = @import("std");
const DrawList = @import("draw_list.zig").DrawList;
const DrawOp = @import("draw_list.zig").DrawOp;

pub const OpBreakdown = struct {
    clip_push: u32 = 0,
    clip_pop: u32 = 0,
    rect_filled: u32 = 0,
    rect_stroke: u32 = 0,
    text_run: u32 = 0,
    image: u32 = 0,
    custom: u32 = 0,
};

pub const FramePerf = struct {
    frame_index: u64 = 0,
    op_count: u32 = 0,
    peak_clip_depth: u32 = 0,
    draw_op_capacity: usize = 0,
    draw_op_bytes_reserved: usize = 0,
    draw_op_bytes_used: usize = 0,
    draw_op_utilization: f32 = 0,
    op_breakdown: OpBreakdown = .{},

    pub fn fromDrawList(draw_list: DrawList, draw_op_capacity: usize, frame_index: u64) FramePerf {
        var out = FramePerf{
            .frame_index = frame_index,
            .op_count = draw_list.stats.op_count,
            .draw_op_capacity = draw_op_capacity,
            .draw_op_bytes_reserved = draw_op_capacity * @sizeOf(DrawOp),
            .draw_op_bytes_used = draw_list.ops.len * @sizeOf(DrawOp),
        };

        out.draw_op_utilization = if (draw_op_capacity > 0)
            @as(f32, @floatFromInt(draw_list.ops.len)) / @as(f32, @floatFromInt(draw_op_capacity))
        else
            0;

        var clip_depth: u32 = 0;
        for (draw_list.ops) |op| {
            switch (op) {
                .clip_push => {
                    out.op_breakdown.clip_push += 1;
                    clip_depth += 1;
                    out.peak_clip_depth = @max(out.peak_clip_depth, clip_depth);
                },
                .clip_pop => {
                    out.op_breakdown.clip_pop += 1;
                    if (clip_depth > 0) clip_depth -= 1;
                },
                .rect_filled => out.op_breakdown.rect_filled += 1,
                .rect_stroke => out.op_breakdown.rect_stroke += 1,
                .text_run => out.op_breakdown.text_run += 1,
                .image => out.op_breakdown.image += 1,
                .custom => out.op_breakdown.custom += 1,
            }
        }

        return out;
    }
};

test "FramePerf computes op breakdown and utilization" {
    const draw_list = DrawList{
        .ops = &.{
            .{ .clip_push = .{ .x = 0, .y = 0, .w = 10, .h = 10 } },
            .{ .rect_filled = .{ .rect = .{ .x = 0, .y = 0, .w = 1, .h = 1 }, .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 }, .radius = 0 } },
            .{ .clip_pop = {} },
        },
        .stats = .{ .op_count = 3 },
    };

    const perf = FramePerf.fromDrawList(draw_list, 8, 42);
    try std.testing.expectEqual(@as(u64, 42), perf.frame_index);
    try std.testing.expectEqual(@as(u32, 3), perf.op_count);
    try std.testing.expectEqual(@as(u32, 1), perf.op_breakdown.clip_push);
    try std.testing.expectEqual(@as(u32, 1), perf.op_breakdown.clip_pop);
    try std.testing.expectEqual(@as(u32, 1), perf.op_breakdown.rect_filled);
    try std.testing.expectEqual(@as(u32, 1), perf.peak_clip_depth);
    try std.testing.expectApproxEqAbs(@as(f32, 0.375), perf.draw_op_utilization, 0.0001);
}
