const std = @import("std");
const ui = @import("analog_ui");
const sdl = ui.sdl;
const menu = @import("menu_screens.zig");

// This file is intentionally written as a compact host-app tutorial.
// It shows the pieces an SDL application owns, and the smaller surface area
// that analog_ui needs each frame: input, a logical screen size, a draw list,
// and a renderer backend.

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

// A bad DPI scale should never leak into font sizing or render transforms.
// Treat invalid values as a normal 1:1 logical-to-physical scale.
fn validScale(scale: f32) f32 {
    if (std.math.isFinite(scale) and scale > 0.0) {
        return scale;
    }
    return 1.0;
}

fn detectWindowScale(window: *sdl.SDL_Window) f32 {
    // SDL's high-DPI API surface has changed over time. The @hasDecl checks
    // keep this demo buildable against the SDL headers selected by build.zig.
    // Prefer SDL's explicit high-DPI scale APIs, then fall back to comparing
    // logical window size with pixel size on older SDL builds.
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
            return validScale(@max(scale_x, scale_y));
        }
    }

    return 1.0;
}

fn initScaledFont(alloc: std.mem.Allocator, ttf_bytes: []const u8, logical_px: f32, dpi_scale: f32) !ui.Font {
    // Layout stays in logical pixels. The font atlas is rasterized at the
    // physical size so text remains crisp on high-density displays. The
    // renderer later receives the same scale as font_atlas_scale, letting it
    // convert atlas-space glyph metrics back into logical UI coordinates.
    return ui.Font.initTtf(alloc, .{
        .ttf_bytes = ttf_bytes,
        .base_px = logical_px * validScale(dpi_scale),
        .charset = .ascii,
        .dynamic_glyphs = true,
    });
}

fn pollFrameEvents(frame_events: *std.array_list.Managed(sdl.SDL_Event), window_id: sdl.c.SDL_WindowID) !PolledEvents {
    // Keep the raw SDL events for FrameApi.collectSdlInput. We also scan them
    // here for app-level decisions that analog_ui should not own: quitting and
    // reacting to display/window scale changes.
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

fn refreshScaleIfNeeded(
    alloc: std.mem.Allocator,
    window: *sdl.SDL_Window,
    ttf_bytes: []const u8,
    font: *ui.Font,
    active_scale: *f32,
) !void {
    // When a window moves between monitors or the OS display scale changes, the
    // renderer transform and font atlas need to agree on the new scale. Rebuild
    // the font only when the scale actually changed enough to matter.
    const detected_scale = validScale(detectWindowScale(window));
    if (@abs(detected_scale - active_scale.*) <= scale_epsilon) {
        return;
    }

    const replacement = try initScaledFont(alloc, ttf_bytes, button_font_px, detected_scale);
    font.deinit();
    font.* = replacement;
    active_scale.* = detected_scale;
}

fn windowSize(window: *sdl.SDL_Window) WindowSize {
    // The UI describes rectangles in logical window coordinates. SDL's renderer
    // scale maps those logical coordinates onto the actual backing pixels.
    var window_w: c_int = 0;
    var window_h: c_int = 0;
    _ = sdl.c.SDL_GetWindowSize(window, &window_w, &window_h);

    return .{
        .w = @as(f32, @floatFromInt(if (window_w > 0) window_w else window_width)),
        .h = @as(f32, @floatFromInt(if (window_h > 0) window_h else window_height)),
    };
}

fn clearRenderer(renderer: *sdl.SDL_Renderer, rgb: [3]u8) !void {
    // Clearing is intentionally host-owned. analog_ui renders draw operations;
    // it does not decide when or how the frame buffer is prepared.
    if (!sdl.SDL_SetRenderDrawColor(renderer, rgb[0], rgb[1], rgb[2], 255)) {
        return error.SdlRendererError;
    }
    if (!sdl.SDL_RenderClear(renderer)) {
        return error.SdlRendererError;
    }
}

fn presentRenderer(renderer: *sdl.SDL_Renderer) !void {
    // Presenting and frame pacing stay in the host app for the same reason as
    // event polling: games and tools usually need direct control here.
    if (!sdl.SDL_RenderPresent(renderer)) {
        return error.SdlRendererError;
    }
}

pub fn run() !void {
    // This demo uses a debug allocator so leaks are visible during development.
    // A real application can pass whichever allocator matches its ownership
    // model; analog_ui APIs keep allocation explicit.
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // The threaded I/O object is only needed to load the TTF file in this demo.
    // Font.initTtf copies the bytes it needs, so bold_bytes can be freed after
    // the font has been created.
    var io_instance: std.Io.Threaded = .init(alloc, .{});
    defer io_instance.deinit();
    const io = io_instance.io();

    // SDL initialization is outside analog_ui. If your host already owns SDL,
    // you would create the backend with your existing window/renderer instead.
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.print("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlInitFailed;
    }
    defer sdl.SDL_Quit();

    // The host app owns SDL objects and destroys them in reverse order.
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

    // Asset discovery is also host-owned. The UI library receives bytes, not a
    // path, which keeps it independent of project layout and package systems.
    const cwd = std.Io.Dir.cwd();
    const bold_bytes = try cwd.readFileAlloc(io, font_path, alloc, .limited(std.math.maxInt(usize)));
    defer alloc.free(bold_bytes);

    // The backend stores renderer-side resources such as atlas textures. It must
    // be deinitialized before the SDL_Renderer it references is destroyed.
    var active_scale = validScale(detectWindowScale(window));
    var roboto_bold = try initScaledFont(alloc, bold_bytes, button_font_px, active_scale);
    defer roboto_bold.deinit();

    var backend = try ui.RendererBackend.init(alloc, renderer);
    defer backend.deinit();

    var input = ui.InputState.init();
    var widget_state = ui.WidgetState{};
    var menu_state = menu.State{};
    var frame_events = std.array_list.Managed(sdl.SDL_Event).init(alloc);
    defer frame_events.deinit();

    while (menu_state.running) {
        // 1. Pump SDL, keeping the raw events for analog_ui's input mapper.
        // InputState is carried forward so held buttons/keys survive frames
        // that contain no new SDL event for that control.
        const events = try pollFrameEvents(&frame_events, window_id);
        if (events.quit) break;
        if (events.scale_changed) {
            try refreshScaleIfNeeded(alloc, window, bold_bytes, &roboto_bold, &active_scale);
        }
        input = ui.FrameApi.collectSdlInput(frame_events.items, input);

        // 2. Build a draw list in logical coordinates.
        // menu.frame is deliberately backend-neutral: it mutates widget/menu
        // state and returns drawing commands, but it does not know about SDL.
        const screen = windowSize(window);
        const out = try menu.frame(alloc, &menu_state, &widget_state, input, .{
            .screen = .{ .w = screen.w, .h = screen.h },
        });
        defer alloc.free(out.draw_list.ops);

        // 3. Render with matching DPI and atlas scales. Passing sync_font lets
        // dynamic glyph uploads happen at the same point every frame.
        try clearRenderer(renderer, out.background_rgb);

        // renderFrame is the convenience wrapper around backend.syncFont and
        // backend.render. Calling sync each frame is acceptable for dynamic
        // glyphs; the backend only uploads dirty atlas regions.
        try ui.FrameApi.renderFrame(&backend, out.draw_list, .{
            .sync_font = &roboto_bold,
            .dpi_scale = active_scale,
            .font_atlas_scale = active_scale,
        });

        try presentRenderer(renderer);
        sdl.SDL_Delay(frame_delay_ms);
    }
}
