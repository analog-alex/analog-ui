const std = @import("std");
const ui = @import("analog_ui");
const sdl = ui.sdl;
const menu = @import("menu_screens.zig");

fn sanitizeScale(scale: f32) f32 {
    if (std.math.isFinite(scale) and scale > 0.0) {
        return scale;
    }
    return 1.0;
}

fn detectWindowScale(window: *sdl.SDL_Window) f32 {
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
            return sanitizeScale(@max(scale_x, scale_y));
        }
    }

    return 1.0;
}

fn initScaledFont(alloc: std.mem.Allocator, ttf_bytes: []const u8, logical_px: f32, dpi_scale: f32) !ui.Font {
    return ui.Font.initTtf(alloc, .{
        .ttf_bytes = ttf_bytes,
        .base_px = logical_px * sanitizeScale(dpi_scale),
        .charset = .ascii,
        .dynamic_glyphs = true,
    });
}

fn setRendererScale(renderer: *sdl.SDL_Renderer, scale: f32) !void {
    if (@hasDecl(sdl.c, "SDL_SetRenderScale")) {
        if (!sdl.c.SDL_SetRenderScale(renderer, scale, scale)) {
            std.debug.print("SDL_SetRenderScale failed: {s}\n", .{sdl.SDL_GetError()});
            return error.SdlRendererError;
        }
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

    const title: [*:0]const u8 = "analog_ui menu examples";
    const window = sdl.SDL_CreateWindow(title, 960, 540, sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY) orelse {
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
    const bold_bytes = try cwd.readFileAlloc(io, "example_ttf/roboto/Roboto-Bold.ttf", alloc, .limited(std.math.maxInt(usize)));
    defer alloc.free(bold_bytes);

    const button_font_px: f32 = 18.0;
    var active_scale = sanitizeScale(detectWindowScale(window));
    var roboto_bold = try initScaledFont(alloc, bold_bytes, button_font_px, active_scale);
    defer roboto_bold.deinit();

    var backend = try ui.RendererBackend.init(alloc, renderer);
    defer backend.deinit();

    try backend.syncFont(&roboto_bold);
    try setRendererScale(renderer, active_scale);

    var running = true;
    var frame: u32 = 0;
    var scale_needs_refresh = false;
    var input = ui.InputState.init();
    var widget_state = ui.WidgetState{};
    var menu_state = menu.State{};
    var frame_events = std.array_list.Managed(sdl.SDL_Event).init(alloc);
    defer frame_events.deinit();

    while (running and menu_state.running) {
        frame_events.clearRetainingCapacity();

        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            try frame_events.append(event);

            if (event.type == sdl.SDL_EVENT_QUIT) {
                running = false;
                continue;
            }

            if (event.type == sdl.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED or
                event.type == sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED or
                event.type == sdl.SDL_EVENT_WINDOW_DISPLAY_CHANGED)
            {
                if (event.window.windowID == window_id) {
                    scale_needs_refresh = true;
                }
                continue;
            }

            if (event.type == sdl.SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED) {
                scale_needs_refresh = true;
            }
        }

        if (scale_needs_refresh) {
            const detected_scale = sanitizeScale(detectWindowScale(window));
            if (@abs(detected_scale - active_scale) > 0.01) {
                const replacement = try initScaledFont(alloc, bold_bytes, button_font_px, detected_scale);
                roboto_bold.deinit();
                roboto_bold = replacement;
                active_scale = detected_scale;
                try backend.syncFont(&roboto_bold);
                try setRendererScale(renderer, active_scale);
            }
            scale_needs_refresh = false;
        }

        input = ui.FrameApi.collectSdlInput(frame_events.items, input);

        var window_w: c_int = 0;
        var window_h: c_int = 0;
        _ = sdl.c.SDL_GetWindowSize(window, &window_w, &window_h);
        const logical_w = @as(f32, @floatFromInt(if (window_w > 0) window_w else 960));
        const logical_h = @as(f32, @floatFromInt(if (window_h > 0) window_h else 540));

        const out = try menu.frame(alloc, &menu_state, &widget_state, input, .{
            .screen = .{ .w = logical_w, .h = logical_h },
            .frame_index = frame,
        });
        defer alloc.free(out.draw_list.ops);

        _ = sdl.SDL_SetRenderDrawColor(renderer, out.background_rgb[0], out.background_rgb[1], out.background_rgb[2], 255);
        _ = sdl.SDL_RenderClear(renderer);

        try ui.FrameApi.renderFrame(&backend, out.draw_list, .{
            .sync_font = &roboto_bold,
            .dpi_scale = active_scale,
            .font_atlas_scale = active_scale,
        });

        _ = sdl.SDL_RenderPresent(renderer);
        sdl.SDL_Delay(16);
        frame +%= 1;
    }
}
