const std = @import("std");
const clay = @import("clay_bridge.zig");
const InputState = @import("input.zig").InputState;
const DrawOp = @import("draw_list.zig").DrawOp;
const DrawList = @import("draw_list.zig").DrawList;
const Rect = @import("draw_list.zig").Rect;
const Color = @import("draw_list.zig").Color;
const FramePerf = @import("perf.zig").FramePerf;
const Theme = @import("theme.zig").Theme;
const FontRegistry = @import("../font/registry.zig").FontRegistry;
const ScaleState = @import("scale.zig").ScaleState;
const utf8 = @import("../font/utf8.zig");

pub const Context = struct {
    allocator: std.mem.Allocator,
    clay_context: ?*clay.Clay_Context,
    arena: clay.Clay_Arena,
    layout_dims: clay.Clay_Dimensions,
    theme: Theme,
    scale: ScaleState,
    font_registry: ?*FontRegistry,
    draw_ops: std.array_list.Managed(DrawOp),
    frame_index: u64,
    last_perf: FramePerf,

    pub fn init(allocator: std.mem.Allocator, options: struct {
        theme: Theme = Theme.default,
        scale: ScaleState = .{},
        font_registry: ?*FontRegistry = null,
    }) !Context {
        const arena_size = clay.Clay_MinMemorySize();
        const memory = try allocator.alloc(u8, arena_size);
        const arena = clay.Clay_Arena{
            .nextAllocation = 0,
            .capacity = arena_size,
            .memory = memory.ptr,
        };
        const error_handler = clay.Clay_ErrorHandler{
            .errorHandlerFunction = errorCallback,
            .userData = null,
        };
        const layout_dims = clay.Clay_Dimensions{
            .width = 800,
            .height = 600,
        };
        const clay_context = clay.Clay_Initialize(arena, layout_dims, error_handler);
        if (clay_context == null) return error.ClayInitializationFailed;

        return Context{
            .allocator = allocator,
            .clay_context = clay_context,
            .arena = arena,
            .layout_dims = layout_dims,
            .theme = options.theme,
            .scale = options.scale,
            .font_registry = options.font_registry,
            .draw_ops = std.array_list.Managed(DrawOp).init(allocator),
            .frame_index = 0,
            .last_perf = .{},
        };
    }

    pub fn deinit(self: *Context) void {
        self.draw_ops.deinit();
        self.allocator.free(self.arena.memory[0..self.arena.capacity]);
    }

    fn errorCallback(error_data: clay.Clay_ErrorData) callconv(.c) void {
        const msg_len: usize = @intCast(@max(error_data.errorText.length, 0));
        if (msg_len == 0) {
            std.log.err("Clay reported an error type={d}", .{error_data.errorType});
            return;
        }
        const ptr: [*]const u8 = @ptrCast(error_data.errorText.chars);
        const msg = ptr[0..msg_len];
        std.log.err("Clay error type={d}: {s}", .{ error_data.errorType, msg });
    }

    fn toColor(c: clay.c.Clay_Color) Color {
        // Clay's examples use 0..255 channel ranges.
        const normalize = if (c.r > 1.0 or c.g > 1.0 or c.b > 1.0 or c.a > 1.0) 255.0 else 1.0;
        return .{
            .r = c.r / normalize,
            .g = c.g / normalize,
            .b = c.b / normalize,
            .a = c.a / normalize,
        };
    }

    fn toRect(bb: clay.c.Clay_BoundingBox) Rect {
        return .{ .x = bb.x, .y = bb.y, .w = bb.width, .h = bb.height };
    }

    fn fallbackMeasure(bytes: []const u8, config: [*c]clay.c.Clay_TextElementConfig) clay.Clay_Dimensions {
        var it = utf8.Utf8Iterator.init(bytes);
        var codepoint_count: usize = 0;
        while (it.nextCodepoint() catch null) |cp| {
            if (cp != '\n') codepoint_count += 1;
        }

        const font_size_px: f32 = if (config != null and config.*.fontSize > 0)
            @floatFromInt(config.*.fontSize)
        else
            16.0;

        const line_height_px: f32 = if (config != null and config.*.lineHeight > 0)
            @floatFromInt(config.*.lineHeight)
        else
            font_size_px * 1.2;

        return .{
            .width = @as(f32, @floatFromInt(codepoint_count)) * (font_size_px * 0.55),
            .height = line_height_px,
        };
    }

    fn measuredHeight(default_height: f32, config: [*c]clay.c.Clay_TextElementConfig) f32 {
        if (config != null and config.*.lineHeight > 0) {
            return @floatFromInt(config.*.lineHeight);
        }
        return default_height;
    }

    fn measureWithRegistry(self: *Context, bytes: []const u8, config: [*c]clay.c.Clay_TextElementConfig) ?clay.Clay_Dimensions {
        const registry = self.font_registry orelse return null;

        const handle = if (config != null and config.*.fontId != 0)
            config.*.fontId
        else
            self.theme.font_body;

        if (handle == 0) return null;
        const base_font = registry.getFont(handle) orelse return null;

        const size = registry.measureText(handle, bytes) catch return null;
        const requested_px: f32 = if (config != null and config.*.fontSize > 0)
            @floatFromInt(config.*.fontSize)
        else
            base_font.base_px;
        const size_scale = if (base_font.base_px > 0.0) requested_px / base_font.base_px else 1.0;

        return .{
            .width = size.width * size_scale,
            .height = measuredHeight(size.height * size_scale, config),
        };
    }

    fn measureTextCallback(text: clay.c.Clay_StringSlice, config: [*c]clay.c.Clay_TextElementConfig, user_data: ?*anyopaque) callconv(.c) clay.Clay_Dimensions {
        const len: usize = @intCast(@max(text.length, 0));
        const bytes = if (len == 0) "" else blk: {
            const ptr: [*]const u8 = @ptrCast(text.chars);
            break :blk ptr[0..len];
        };

        if (user_data) |ud| {
            const context: *Context = @ptrCast(@alignCast(ud));
            if (context.measureWithRegistry(bytes, config)) |dims| {
                return dims;
            }
        }

        return fallbackMeasure(bytes, config);
    }

    pub fn setTheme(self: *Context, theme: Theme) void {
        self.theme = theme;
        clay.c.Clay_ResetMeasureTextCache();
    }

    pub fn setScale(self: *Context, scale: ScaleState) void {
        self.scale = scale;
    }

    pub fn getScale(self: *const Context) ScaleState {
        return self.scale;
    }

    pub fn setFontRegistry(self: *Context, registry: ?*FontRegistry) void {
        self.font_registry = registry;
        clay.c.Clay_ResetMeasureTextCache();
    }

    pub fn framePerf(self: *const Context) FramePerf {
        return self.last_perf;
    }

    pub fn beginFrame(self: *Context, options: struct {
        screen: struct { w: f32, h: f32 },
        input: InputState,
        scale: ?ScaleState = null,
    }) void {
        if (options.scale) |scale| {
            self.scale = scale;
        }
        clay.c.Clay_SetMeasureTextFunction(measureTextCallback, @ptrCast(self));

        self.layout_dims = clay.Clay_Dimensions{
            .width = options.screen.w,
            .height = options.screen.h,
        };
        clay.c.Clay_SetLayoutDimensions(self.layout_dims);
        clay.Clay_SetPointerState(clay.Clay_Vector2{
            .x = options.input.mouse_pos.x,
            .y = options.input.mouse_pos.y,
        }, options.input.mouse_down);
        clay.Clay_BeginLayout();
    }

    pub fn endFrame(self: *Context) !DrawList {
        const commands = clay.Clay_EndLayout();

        self.draw_ops.clearRetainingCapacity();

        const cmd_len: usize = @intCast(@max(commands.length, 0));
        var i: usize = 0;
        while (i < cmd_len) : (i += 1) {
            const cmd = commands.internalArray[i];

            switch (cmd.commandType) {
                clay.c.CLAY_RENDER_COMMAND_TYPE_NONE => {},
                clay.c.CLAY_RENDER_COMMAND_TYPE_SCISSOR_START => {
                    try self.draw_ops.append(.{ .clip_push = toRect(cmd.boundingBox) });
                },
                clay.c.CLAY_RENDER_COMMAND_TYPE_SCISSOR_END => {
                    try self.draw_ops.append(.{ .clip_pop = {} });
                },
                clay.c.CLAY_RENDER_COMMAND_TYPE_RECTANGLE => {
                    const d = cmd.renderData.rectangle;
                    try self.draw_ops.append(.{ .rect_filled = .{
                        .rect = toRect(cmd.boundingBox),
                        .color = toColor(d.backgroundColor),
                        .radius = @max(@max(d.cornerRadius.topLeft, d.cornerRadius.topRight), @max(d.cornerRadius.bottomLeft, d.cornerRadius.bottomRight)),
                    } });
                },
                clay.c.CLAY_RENDER_COMMAND_TYPE_BORDER => {
                    const d = cmd.renderData.border;
                    const thickness: f32 = @floatFromInt(@max(@max(d.width.left, d.width.right), @max(d.width.top, d.width.bottom)));
                    try self.draw_ops.append(.{ .rect_stroke = .{
                        .rect = toRect(cmd.boundingBox),
                        .color = toColor(d.color),
                        .thickness = thickness,
                        .radius = @max(@max(d.cornerRadius.topLeft, d.cornerRadius.topRight), @max(d.cornerRadius.bottomLeft, d.cornerRadius.bottomRight)),
                    } });
                },
                clay.c.CLAY_RENDER_COMMAND_TYPE_TEXT => {
                    const d = cmd.renderData.text;
                    const text_len: usize = @intCast(@max(d.stringContents.length, 0));
                    const text_slice = if (text_len == 0)
                        ""
                    else blk: {
                        const ptr: [*]const u8 = @ptrCast(d.stringContents.chars);
                        break :blk ptr[0..text_len];
                    };

                    try self.draw_ops.append(.{ .text_run = .{
                        .rect = toRect(cmd.boundingBox),
                        .text = text_slice,
                        .font_handle = d.fontId,
                        .size_px = @floatFromInt(d.fontSize),
                        .color = toColor(d.textColor),
                        .alignment = .left,
                    } });
                },
                clay.c.CLAY_RENDER_COMMAND_TYPE_IMAGE => {
                    const d = cmd.renderData.image;
                    const image_id: usize = @intFromPtr(d.imageData);
                    try self.draw_ops.append(.{ .image = .{
                        .rect = toRect(cmd.boundingBox),
                        .image_id = image_id,
                        .tint = toColor(d.backgroundColor),
                    } });
                },
                clay.c.CLAY_RENDER_COMMAND_TYPE_CUSTOM => {
                    const payload = cmd.renderData.custom.customData;
                    try self.draw_ops.append(.{ .custom = .{
                        .id = cmd.id,
                        .payload = payload,
                    } });
                },
                else => {},
            }
        }

        const draw_list = DrawList{
            .ops = self.draw_ops.items,
            .stats = .{ .op_count = @intCast(self.draw_ops.items.len) },
        };

        self.frame_index += 1;
        self.last_perf = FramePerf.fromDrawList(draw_list, self.draw_ops.capacity, self.frame_index);

        return draw_list;
    }
};

test "toColor normalizes 0..255 clay color" {
    const c = Context.toColor(.{ .r = 255, .g = 128, .b = 0, .a = 255 });
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c.r, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 128.0 / 255.0), c.g, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c.b, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c.a, 0.0001);
}

test "context begin/end frame produces draw list" {
    var ctx = try Context.init(std.testing.allocator, .{});
    defer ctx.deinit();

    ctx.beginFrame(.{
        .screen = .{ .w = 800, .h = 600 },
        .input = InputState.init(),
    });
    const dl = try ctx.endFrame();

    try std.testing.expect(dl.stats.op_count == dl.ops.len);
}
