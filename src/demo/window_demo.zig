const std = @import("std");
const ui = @import("analog_ui");
const sdl = ui.sdl;
const menu = @import("menu_screens.zig");

const font_path = "example_ttf/roboto/Roboto-Bold.ttf";
const window_title: [*:0]const u8 = "analog_ui menu examples";
const window_width = 960;
const window_height = 540;
const button_font_px: f32 = 18.0;
const scale_epsilon: f32 = 0.01;
const frame_delay_ms = 16;

const WindowSize = struct {
    w: f32,
    h: f32,
};

const PolledEvents = struct {
    quit: bool = false,
    scale_changed: bool = false,
};

fn validScale(scale: f32) f32 {
    if (std.math.isFinite(scale) and scale > 0.0) return scale;
    return 1.0;
}

fn rebuildFonts(
    alloc: std.mem.Allocator,
    fonts: *ui.FontRegistry,
    theme: *ui.Theme,
    ttf_bytes: []const u8,
    dpi_scale: f32,
) !void {
    fonts.deinit();
    fonts.* = ui.FontRegistry.init(alloc);

    const body = try fonts.addTtf("Roboto-Bold", .{
        .ttf_bytes = ttf_bytes,
        .base_px = button_font_px * validScale(dpi_scale),
        .charset = .ascii,
        .dynamic_glyphs = true,
    });

    var next_theme = theme.*;
    next_theme.font_body = body;
    next_theme.font_heading = body;
    next_theme.font_mono = body;
    theme.* = next_theme;
}

fn pollFrameEvents(frame_events: *std.array_list.Managed(sdl.SDL_Event), window_id: sdl.c.SDL_WindowID) !PolledEvents {
    frame_events.clearRetainingCapacity();

    var result = PolledEvents{};
    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {
        try frame_events.append(event);

        switch (event.type) {
            sdl.SDL_EVENT_QUIT => result.quit = true,
            sdl.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED,
            sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
            sdl.SDL_EVENT_WINDOW_DISPLAY_CHANGED,
            => {
                if (event.window.windowID == window_id) {
                    result.scale_changed = true;
                }
            },
            sdl.SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED => result.scale_changed = true,
            else => {},
        }
    }

    return result;
}

fn windowSize(window: *sdl.SDL_Window) WindowSize {
    var window_w: c_int = 0;
    var window_h: c_int = 0;
    _ = sdl.c.SDL_GetWindowSize(window, &window_w, &window_h);

    return .{
        .w = @as(f32, @floatFromInt(if (window_w > 0) window_w else window_width)),
        .h = @as(f32, @floatFromInt(if (window_h > 0) window_h else window_height)),
    };
}

fn clearRenderer(renderer: *sdl.SDL_Renderer, rgb: [3]u8) !void {
    if (!sdl.SDL_SetRenderDrawColor(renderer, rgb[0], rgb[1], rgb[2], 255)) {
        return error.SdlRendererError;
    }
    if (!sdl.SDL_RenderClear(renderer)) {
        return error.SdlRendererError;
    }
}

fn presentRenderer(renderer: *sdl.SDL_Renderer) !void {
    if (!sdl.SDL_RenderPresent(renderer)) {
        return error.SdlRendererError;
    }
}

pub fn run() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var io_instance: std.Io.Threaded = .init(alloc, .{});
    defer io_instance.deinit();
    const io = io_instance.io();

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.print("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlInitFailed;
    }
    defer sdl.SDL_Quit();

    const window = sdl.SDL_CreateWindow(window_title, window_width, window_height, sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY) orelse {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlCreateWindowFailed;
    };
    defer sdl.SDL_DestroyWindow(window);
    const window_id = sdl.SDL_GetWindowID(window);

    const renderer = sdl.SDL_CreateRenderer(window, null) orelse {
        std.debug.print("SDL_CreateRenderer failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlCreateRendererFailed;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    const cwd = std.Io.Dir.cwd();
    const bold_bytes = try cwd.readFileAlloc(io, font_path, alloc, .limited(std.math.maxInt(usize)));
    defer alloc.free(bold_bytes);

    var backend = try ui.RendererBackend.init(alloc, renderer);
    defer backend.deinit();

    var fonts = ui.FontRegistry.init(alloc);
    defer fonts.deinit();

    var active_scale = validScale(ui.FrameApi.computeDpiScale(window));
    var theme = ui.Theme.default;
    try rebuildFonts(alloc, &fonts, &theme, bold_bytes, active_scale);

    var input = ui.InputState.init();
    var widget_state = ui.WidgetState{};
    var menu_state = menu.State{};
    var frame_events = std.array_list.Managed(sdl.SDL_Event).init(alloc);
    defer frame_events.deinit();

    while (menu_state.running) {
        const events = try pollFrameEvents(&frame_events, window_id);
        if (events.quit) break;

        if (events.scale_changed) {
            const next_scale = validScale(ui.FrameApi.computeDpiScale(window));
            if (@abs(next_scale - active_scale) > scale_epsilon) {
                active_scale = next_scale;
                try rebuildFonts(alloc, &fonts, &theme, bold_bytes, active_scale);
            }
        }

        input = ui.FrameApi.collectSdlInput(frame_events.items, input);

        const screen = windowSize(window);
        const out = try menu.frame(alloc, &menu_state, &widget_state, input, .{
            .screen = .{ .w = screen.w, .h = screen.h },
            .theme = theme,
        });
        defer alloc.free(out.draw_list.ops);

        try clearRenderer(renderer, out.background_rgb);
        try ui.FrameApi.renderFrame(&backend, out.draw_list, .{
            .font_registry = &fonts,
            .scale = .{
                .dpi_scale = active_scale,
                .user_scale = 1.0,
                .app_scale = 1.0,
            },
            .font_atlas_scale = active_scale,
        });

        try presentRenderer(renderer);
        sdl.SDL_Delay(frame_delay_ms);
    }
}
