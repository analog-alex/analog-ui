const std = @import("std");
const Context = @import("context.zig").Context;
const DrawList = @import("draw_list.zig").DrawList;
const InputState = @import("input.zig").InputState;
const Font = @import("../font/font.zig").Font;
const RendererBackend = @import("../backend/sdl_renderer.zig").RendererBackend;
const RenderOptions = @import("../backend/common.zig").RenderOptions;
const sdl_events = @import("../platform/sdl_events.zig");
const sdl = @import("../backend/sdl_shared.zig");

pub const ScreenSize = struct {
    w: f32,
    h: f32,
};

pub const FrameBeginOptions = struct {
    screen: ScreenSize,
    input: InputState,
    default_font: ?*Font = null,
};

pub const FrameRenderOptions = struct {
    sync_font: ?*Font = null,
    dpi_scale: f32 = 1.0,
    font_atlas_scale: f32 = 1.0,
};

pub fn collectInput(events: []const sdl_events.Event, previous: InputState) InputState {
    return sdl_events.fromEvents(events, previous);
}

pub fn collectSdlInput(events: []const sdl.SDL_Event, previous: InputState) InputState {
    return sdl_events.fromSdlEvents(events, previous);
}

pub fn beginFrame(context: *Context, options: FrameBeginOptions) void {
    if (options.default_font) |font| {
        context.setDefaultFont(font);
    }

    context.beginFrame(.{
        .screen = .{ .w = options.screen.w, .h = options.screen.h },
        .input = options.input,
    });
}

pub fn endFrame(context: *Context) !DrawList {
    return context.endFrame();
}

pub fn toRenderOptions(options: FrameRenderOptions) RenderOptions {
    return .{
        .dpi_scale = options.dpi_scale,
        .font_atlas_scale = options.font_atlas_scale,
    };
}

pub fn renderFrame(backend: *RendererBackend, draw_list: DrawList, options: FrameRenderOptions) !void {
    if (options.sync_font) |font| {
        try backend.syncFont(font);
    }
    try backend.render(draw_list, toRenderOptions(options));
}

test "beginFrame sets screen dimensions and default font" {
    var context = try Context.init(std.testing.allocator, .{});
    defer context.deinit();

    var font = try Font.initTtf(std.testing.allocator, .{
        .ttf_bytes = "fake-font-bytes",
        .base_px = 16,
        .dynamic_glyphs = false,
    });
    defer font.deinit();

    var input = InputState.init();
    input.mouse_pos = .{ .x = 12, .y = 34 };
    input.mouse_down = true;

    beginFrame(&context, .{
        .screen = .{ .w = 640, .h = 360 },
        .input = input,
        .default_font = &font,
    });

    try std.testing.expect(context.default_font == &font);
    try std.testing.expectEqual(@as(f32, 640), context.layout_dims.width);
    try std.testing.expectEqual(@as(f32, 360), context.layout_dims.height);

    const draw_list = try endFrame(&context);
    try std.testing.expectEqual(draw_list.stats.op_count, draw_list.ops.len);
}

test "collectInput wraps platform event mapping" {
    var previous = InputState.init();
    previous.mouse_down = true;

    const out = collectInput(
        &.{
            .{ .mouse_move = .{ .x = 101, .y = 44 } },
            .{ .key_down = .enter },
        },
        previous,
    );

    try std.testing.expectEqual(@as(f32, 101), out.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 44), out.mouse_pos.y);
    try std.testing.expect(out.mouse_down);
    try std.testing.expect(out.nav_accept);
}

test "toRenderOptions maps frame render options" {
    const render_options = toRenderOptions(.{
        .dpi_scale = 1.5,
        .font_atlas_scale = 2.0,
    });

    try std.testing.expectEqual(@as(f32, 1.5), render_options.dpi_scale);
    try std.testing.expectEqual(@as(f32, 2.0), render_options.font_atlas_scale);
}
