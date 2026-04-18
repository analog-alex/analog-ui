const std = @import("std");
const ui = @import("analog_ui");
const sdl = ui.sdl;

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

fn pointInRect(rect: ui.Rect, x: f32, y: f32) bool {
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h;
}

fn saturatingAdd(base: u8, delta: u8) u8 {
    const sum: u16 = @as(u16, base) + @as(u16, delta);
    return @intCast(@min(sum, 255));
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

    const title: [*:0]const u8 = "analog_ui menu demo";
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

    const title_text = "ANALOG UI";
    const subtitle_text = "Choose a background preset";
    const button_font_px: f32 = 18.0;
    const pulse_off_label = "Pulse: Off";
    const pulse_on_label = "Pulse: On";
    const quit_label = "Quit";

    const theme_labels = [_][]const u8{
        "Ocean Blue",
        "Forest Green",
        "Sunset Orange",
        "Steel Night",
    };
    const theme_backgrounds = [_][3]u8{
        .{ 24, 46, 66 },
        .{ 24, 56, 38 },
        .{ 74, 44, 24 },
        .{ 36, 40, 58 },
    };
    const theme_buttons = [_][3]u8{
        .{ 66, 140, 196 },
        .{ 78, 156, 98 },
        .{ 196, 118, 74 },
        .{ 112, 126, 168 },
    };
    const theme_ids = [_]ui.Id{
        ui.Id.fromStr("theme_ocean"),
        ui.Id.fromStr("theme_forest"),
        ui.Id.fromStr("theme_sunset"),
        ui.Id.fromStr("theme_steel"),
    };
    const pulse_toggle_id = ui.Id.fromStr("menu_toggle_pulse");
    const quit_id = ui.Id.fromStr("menu_quit");

    var selected_theme: usize = 0;
    var pulse_enabled = false;
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
    var frame_events = std.array_list.Managed(sdl.SDL_Event).init(alloc);
    defer frame_events.deinit();

    while (running) {
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

        input = ui.inputFromSdlEvents(frame_events.items, input);

        const dpi_scale = active_scale;

        var window_w: c_int = 0;
        var window_h: c_int = 0;
        _ = sdl.c.SDL_GetWindowSize(window, &window_w, &window_h);
        const logical_w = @as(f32, @floatFromInt(if (window_w > 0) window_w else 960));
        const logical_h = @as(f32, @floatFromInt(if (window_h > 0) window_h else 540));

        const panel_w = std.math.clamp(logical_w * 0.56, 420.0, 740.0);
        const panel_h = std.math.clamp(logical_h * 0.74, 320.0, 520.0);
        const panel_rect = ui.Rect{
            .x = (logical_w - panel_w) * 0.5,
            .y = (logical_h - panel_h) * 0.5,
            .w = panel_w,
            .h = panel_h,
        };

        const button_w = panel_rect.w - 72.0;
        const button_h = 52.0;
        const button_gap = 12.0;
        const control_gap = 14.0;
        const button_count_f = @as(f32, @floatFromInt(theme_labels.len));
        const theme_buttons_total_h = button_count_f * button_h + @as(f32, @floatFromInt(theme_labels.len - 1)) * button_gap;
        const controls_total_h = theme_buttons_total_h + control_gap + button_h + control_gap + button_h;
        const buttons_start_y = panel_rect.y + panel_rect.h - controls_total_h - 26.0;

        var button_rects: [theme_labels.len]ui.Rect = undefined;
        var i: usize = 0;
        while (i < theme_labels.len) : (i += 1) {
            button_rects[i] = .{
                .x = panel_rect.x + 36.0,
                .y = buttons_start_y + @as(f32, @floatFromInt(i)) * (button_h + button_gap),
                .w = button_w,
                .h = button_h,
            };

            const hovered = pointInRect(button_rects[i], input.mouse_pos.x, input.mouse_pos.y);
            if (ui.button(&widget_state, theme_ids[i], hovered, input)) {
                selected_theme = i;
            }
        }

        const pulse_rect = ui.Rect{
            .x = panel_rect.x + 36.0,
            .y = buttons_start_y + theme_buttons_total_h + control_gap,
            .w = button_w,
            .h = button_h,
        };
        const pulse_hovered = pointInRect(pulse_rect, input.mouse_pos.x, input.mouse_pos.y);
        if (ui.button(&widget_state, pulse_toggle_id, pulse_hovered, input)) {
            pulse_enabled = !pulse_enabled;
        }

        const quit_rect = ui.Rect{
            .x = panel_rect.x + 36.0,
            .y = pulse_rect.y + button_h + control_gap,
            .w = button_w,
            .h = button_h,
        };
        const quit_hovered = pointInRect(quit_rect, input.mouse_pos.x, input.mouse_pos.y);
        if (ui.button(&widget_state, quit_id, quit_hovered, input)) {
            running = false;
        }

        const pulse: u8 = if (pulse_enabled)
            @as(u8, @intCast((frame / 6) % 24))
        else
            0;
        const bg = theme_backgrounds[selected_theme];
        const bg_r = saturatingAdd(bg[0], pulse / 2);
        const bg_g = saturatingAdd(bg[1], pulse / 2);
        const bg_b = saturatingAdd(bg[2], pulse);

        _ = sdl.SDL_SetRenderDrawColor(renderer, bg_r, bg_g, bg_b, 255);
        _ = sdl.SDL_RenderClear(renderer);

        var builder = ui.Builder.init(alloc);
        defer builder.deinit();

        try builder.push(.{ .rect_filled = .{
            .rect = panel_rect,
            .color = .{ .r = 0.09, .g = 0.10, .b = 0.14, .a = 0.92 },
            .radius = 10,
        } });
        try builder.push(.{ .rect_stroke = .{
            .rect = panel_rect,
            .color = .{ .r = 0.77, .g = 0.82, .b = 0.92, .a = 0.45 },
            .thickness = 2,
            .radius = 10,
        } });

        const title_size = try roboto_bold.measure(title_text);
        const title_h = title_size.height / active_scale;
        const title_rect = ui.Rect{
            .x = panel_rect.x,
            .y = panel_rect.y + 22.0,
            .w = panel_rect.w,
            .h = title_h,
        };
        try builder.push(.{ .text_run = .{
            .rect = title_rect,
            .text = title_text,
            .font_handle = 0,
            .size_px = button_font_px,
            .color = .{ .r = 0.95, .g = 0.97, .b = 1.0, .a = 1.0 },
            .alignment = .center,
        } });

        const subtitle_size = try roboto_bold.measure(subtitle_text);
        const subtitle_h = subtitle_size.height / active_scale;
        const subtitle_rect = ui.Rect{
            .x = panel_rect.x,
            .y = panel_rect.y + 22.0 + title_h + 8.0,
            .w = panel_rect.w,
            .h = subtitle_h,
        };
        try builder.push(.{ .text_run = .{
            .rect = subtitle_rect,
            .text = subtitle_text,
            .font_handle = 0,
            .size_px = button_font_px,
            .color = .{ .r = 0.82, .g = 0.86, .b = 0.94, .a = 1.0 },
            .alignment = .center,
        } });

        i = 0;
        while (i < theme_labels.len) : (i += 1) {
            const hovered = pointInRect(button_rects[i], input.mouse_pos.x, input.mouse_pos.y);
            const boost: u8 = if (hovered) 30 else if (selected_theme == i) 14 else 0;
            const button_rgb = theme_buttons[i];

            try builder.push(.{ .rect_filled = .{
                .rect = button_rects[i],
                .color = .{
                    .r = @as(f32, @floatFromInt(saturatingAdd(button_rgb[0], boost))) / 255.0,
                    .g = @as(f32, @floatFromInt(saturatingAdd(button_rgb[1], boost))) / 255.0,
                    .b = @as(f32, @floatFromInt(saturatingAdd(button_rgb[2], boost))) / 255.0,
                    .a = 1.0,
                },
                .radius = 8,
            } });

            if (selected_theme == i) {
                try builder.push(.{ .rect_stroke = .{
                    .rect = button_rects[i],
                    .color = .{ .r = 0.96, .g = 0.98, .b = 1.0, .a = 1.0 },
                    .thickness = 2,
                    .radius = 8,
                } });
            }

            const label_size = try roboto_bold.measure(theme_labels[i]);
            const label_h = label_size.height / active_scale;
            const label_rect = ui.Rect{
                .x = button_rects[i].x,
                .y = button_rects[i].y + (button_rects[i].h - label_h) * 0.5,
                .w = button_rects[i].w,
                .h = label_h,
            };
            try builder.push(.{ .text_run = .{
                .rect = label_rect,
                .text = theme_labels[i],
                .font_handle = 0,
                .size_px = button_font_px,
                .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
                .alignment = .center,
            } });
        }

        const pulse_boost: u8 = if (pulse_hovered) 28 else 0;
        const pulse_base = if (pulse_enabled) [3]u8{ 76, 162, 178 } else [3]u8{ 98, 106, 120 };
        try builder.push(.{ .rect_filled = .{
            .rect = pulse_rect,
            .color = .{
                .r = @as(f32, @floatFromInt(saturatingAdd(pulse_base[0], pulse_boost))) / 255.0,
                .g = @as(f32, @floatFromInt(saturatingAdd(pulse_base[1], pulse_boost))) / 255.0,
                .b = @as(f32, @floatFromInt(saturatingAdd(pulse_base[2], pulse_boost))) / 255.0,
                .a = 1.0,
            },
            .radius = 8,
        } });
        try builder.push(.{ .rect_stroke = .{
            .rect = pulse_rect,
            .color = if (pulse_enabled)
                .{ .r = 0.90, .g = 1.0, .b = 0.98, .a = 0.95 }
            else
                .{ .r = 0.84, .g = 0.88, .b = 0.95, .a = 0.75 },
            .thickness = 2,
            .radius = 8,
        } });

        const pulse_label = if (pulse_enabled) pulse_on_label else pulse_off_label;
        const pulse_size = try roboto_bold.measure(pulse_label);
        const pulse_h = pulse_size.height / active_scale;
        const pulse_label_rect = ui.Rect{
            .x = pulse_rect.x,
            .y = pulse_rect.y + (pulse_rect.h - pulse_h) * 0.5,
            .w = pulse_rect.w,
            .h = pulse_h,
        };
        try builder.push(.{ .text_run = .{
            .rect = pulse_label_rect,
            .text = pulse_label,
            .font_handle = 0,
            .size_px = button_font_px,
            .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
            .alignment = .center,
        } });

        const quit_boost: u8 = if (quit_hovered) 35 else 0;
        try builder.push(.{ .rect_filled = .{
            .rect = quit_rect,
            .color = .{
                .r = @as(f32, @floatFromInt(saturatingAdd(154, quit_boost))) / 255.0,
                .g = @as(f32, @floatFromInt(saturatingAdd(46, quit_boost / 2))) / 255.0,
                .b = @as(f32, @floatFromInt(saturatingAdd(58, quit_boost / 2))) / 255.0,
                .a = 1.0,
            },
            .radius = 8,
        } });
        try builder.push(.{ .rect_stroke = .{
            .rect = quit_rect,
            .color = .{ .r = 0.98, .g = 0.92, .b = 0.93, .a = 0.8 },
            .thickness = 2,
            .radius = 8,
        } });

        const quit_size = try roboto_bold.measure(quit_label);
        const quit_h = quit_size.height / active_scale;
        const quit_label_rect = ui.Rect{
            .x = quit_rect.x,
            .y = quit_rect.y + (quit_rect.h - quit_h) * 0.5,
            .w = quit_rect.w,
            .h = quit_h,
        };
        try builder.push(.{ .text_run = .{
            .rect = quit_label_rect,
            .text = quit_label,
            .font_handle = 0,
            .size_px = button_font_px,
            .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
            .alignment = .center,
        } });

        const draw_list = try builder.finish();
        defer alloc.free(draw_list.ops);
        try backend.syncFont(&roboto_bold);
        try backend.render(draw_list, .{ .dpi_scale = dpi_scale, .font_atlas_scale = active_scale });

        _ = sdl.SDL_RenderPresent(renderer);
        sdl.SDL_Delay(16);
        frame +%= 1;
    }
}
