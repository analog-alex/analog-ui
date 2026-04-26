const std = @import("std");
const Context = @import("context.zig").Context;
const DrawList = @import("draw_list.zig").DrawList;
const InputState = @import("input.zig").InputState;
const Theme = @import("theme.zig").Theme;
const ScaleState = @import("scale.zig").ScaleState;
const scale_mod = @import("scale.zig");
const FontRegistry = @import("../font/registry.zig").FontRegistry;
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
    font_registry: ?*FontRegistry = null,
    theme: ?Theme = null,
    scale: ?ScaleState = null,
};

pub const FrameRenderOptions = struct {
    font_registry: ?*FontRegistry = null,
    scale: ScaleState = .{},
    font_atlas_scale: ?f32 = null,
};

pub fn collectInput(events: []const sdl_events.Event, previous: InputState) InputState {
    return sdl_events.fromEvents(events, previous);
}

pub fn collectSdlInput(events: []const sdl.SDL_Event, previous: InputState) InputState {
    return sdl_events.fromSdlEvents(events, previous);
}

pub fn clampUiScale(scale: f32) f32 {
    return scale_mod.clampUiScale(scale);
}

pub fn computeDpiScale(window: *sdl.SDL_Window) f32 {
    if (@hasDecl(sdl.c, "SDL_GetWindowDisplayScale")) {
        const display_scale = sdl.c.SDL_GetWindowDisplayScale(window);
        if (std.math.isFinite(display_scale) and display_scale > 0.0) {
            return display_scale;
        }
    }

    if (@hasDecl(sdl.c, "SDL_GetWindowPixelDensity")) {
        const density = sdl.c.SDL_GetWindowPixelDensity(window);
        if (std.math.isFinite(density) and density > 0.0) {
            return density;
        }
    }

    if (@hasDecl(sdl.c, "SDL_GetWindowSize") and @hasDecl(sdl.c, "SDL_GetWindowSizeInPixels")) {
        var window_w: c_int = 0;
        var window_h: c_int = 0;
        _ = sdl.c.SDL_GetWindowSize(window, &window_w, &window_h);

        var pixel_w: c_int = 0;
        var pixel_h: c_int = 0;
        _ = sdl.c.SDL_GetWindowSizeInPixels(window, &pixel_w, &pixel_h);

        if (window_w > 0 and window_h > 0 and pixel_w > 0 and pixel_h > 0) {
            const scale_x = @as(f32, @floatFromInt(pixel_w)) / @as(f32, @floatFromInt(window_w));
            const scale_y = @as(f32, @floatFromInt(pixel_h)) / @as(f32, @floatFromInt(window_h));
            return @max(scale_x, scale_y);
        }
    }

    return 1.0;
}

pub fn beginFrame(context: *Context, options: FrameBeginOptions) void {
    if (options.font_registry) |font_registry| {
        context.setFontRegistry(font_registry);
    }
    if (options.theme) |theme| {
        context.setTheme(theme);
    }

    context.beginFrame(.{
        .screen = .{ .w = options.screen.w, .h = options.screen.h },
        .input = options.input,
        .scale = options.scale,
    });
}

pub fn endFrame(context: *Context) !DrawList {
    return context.endFrame();
}

pub fn toRenderOptions(options: FrameRenderOptions) RenderOptions {
    return .{
        .scale = options.scale,
        .font_atlas_scale = options.font_atlas_scale,
    };
}

pub fn renderFrame(backend: *RendererBackend, draw_list: DrawList, options: FrameRenderOptions) !void {
    if (options.font_registry) |font_registry| {
        try backend.syncFonts(font_registry);
    }
    try backend.render(draw_list, toRenderOptions(options));
}

test "beginFrame sets screen dimensions and registry" {
    var context = try Context.init(std.testing.allocator, .{});
    defer context.deinit();

    var registry = FontRegistry.init(std.testing.allocator);
    defer registry.deinit();

    _ = try registry.addTtf("body", .{
        .ttf_bytes = "fake-font-bytes",
        .base_px = 16,
        .dynamic_glyphs = false,
    });

    var input = InputState.init();
    input.mouse_pos = .{ .x = 12, .y = 34 };
    input.mouse_down = true;

    beginFrame(&context, .{
        .screen = .{ .w = 640, .h = 360 },
        .input = input,
        .font_registry = &registry,
    });

    try std.testing.expect(context.font_registry == &registry);
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
        .scale = .{
            .dpi_scale = 1.5,
            .user_scale = 1.2,
            .app_scale = 0.75,
        },
        .font_atlas_scale = 2.0,
    });

    try std.testing.expectEqual(@as(f32, 1.5), render_options.scale.dpi_scale);
    try std.testing.expectEqual(@as(f32, 1.2), render_options.scale.user_scale);
    try std.testing.expectEqual(@as(f32, 0.75), render_options.scale.app_scale);
    try std.testing.expectEqual(@as(f32, 2.0), render_options.font_atlas_scale.?);
}
