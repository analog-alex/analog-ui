const std = @import("std");
const ui = @import("analog_ui");
const build_options = @import("build_options");
const sdl = ui.sdl;

pub fn main() !void {
    if (build_options.window_demo) {
        try runWindowDemo();
        return;
    }

    try runHeadlessDemo();
}

fn runHeadlessDemo() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    std.debug.print("analog_ui headless demo\n", .{});

    const title_id = ui.Id.fromStr("title");
    const play_id = ui.Id.fromStr("play_button");
    std.debug.print("ids: title={d} play={d}\n", .{ title_id.value, play_id.value });

    var input = ui.InputState.init();
    const frame_1 = [_]ui.SdlEvent{
        .{ .mouse_move = .{ .x = 320, .y = 180 } },
        .mouse_button_down,
    };
    input = ui.inputFromEvents(&frame_1, input);

    var widget_state = ui.WidgetState{};
    _ = ui.button(&widget_state, play_id, true, input);

    const frame_2 = [_]ui.SdlEvent{.mouse_button_up};
    input = ui.inputFromEvents(&frame_2, input);
    const pressed = ui.button(&widget_state, play_id, true, input);
    std.debug.print("button pressed: {}\n", .{pressed});

    const fake_ttf = "not-a-real-ttf";
    var font = try ui.Font.initTtf(alloc, .{
        .ttf_bytes = fake_ttf,
        .base_px = 16,
        .charset = .ascii,
        .dynamic_glyphs = false,
    });
    defer font.deinit();

    const measured = try font.measure("Play\nQuit");
    std.debug.print("text size: {d:.1} x {d:.1}\n", .{ measured.width, measured.height });
}

fn runWindowDemo() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.print("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlInitFailed;
    }
    defer sdl.SDL_Quit();

    const title: [*:0]const u8 = "analog_ui window demo";
    const window = sdl.SDL_CreateWindow(title, 960, 540, sdl.SDL_WINDOW_RESIZABLE) orelse {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlCreateWindowFailed;
    };
    defer sdl.SDL_DestroyWindow(window);

    const renderer = sdl.SDL_CreateRenderer(window, null) orelse {
        std.debug.print("SDL_CreateRenderer failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlCreateRendererFailed;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    const cwd = std.fs.cwd();
    const regular_bytes = try cwd.readFileAlloc(alloc, "example_ttf/roboto/Roboto-Regular.ttf", std.math.maxInt(usize));
    defer alloc.free(regular_bytes);
    const bold_bytes = try cwd.readFileAlloc(alloc, "example_ttf/roboto/Roboto-Bold.ttf", std.math.maxInt(usize));
    defer alloc.free(bold_bytes);
    const italic_bytes = try cwd.readFileAlloc(alloc, "example_ttf/roboto/Roboto-Italic.ttf", std.math.maxInt(usize));
    defer alloc.free(italic_bytes);
    const bold_italic_bytes = try cwd.readFileAlloc(alloc, "example_ttf/roboto/Roboto-BoldItalic.ttf", std.math.maxInt(usize));
    defer alloc.free(bold_italic_bytes);

    var roboto_regular = try ui.Font.initTtf(alloc, .{
        .ttf_bytes = regular_bytes,
        .base_px = 24,
        .charset = .ascii,
        .dynamic_glyphs = true,
    });
    defer roboto_regular.deinit();
    var roboto_bold = try ui.Font.initTtf(alloc, .{
        .ttf_bytes = bold_bytes,
        .base_px = 24,
        .charset = .ascii,
        .dynamic_glyphs = true,
    });
    defer roboto_bold.deinit();
    var roboto_italic = try ui.Font.initTtf(alloc, .{
        .ttf_bytes = italic_bytes,
        .base_px = 24,
        .charset = .ascii,
        .dynamic_glyphs = true,
    });
    defer roboto_italic.deinit();
    var roboto_bold_italic = try ui.Font.initTtf(alloc, .{
        .ttf_bytes = bold_italic_bytes,
        .base_px = 24,
        .charset = .ascii,
        .dynamic_glyphs = true,
    });
    defer roboto_bold_italic.deinit();

    // Keep all Roboto styles loaded; the bold face is used for button text in this demo.
    _ = &roboto_regular;
    _ = &roboto_italic;
    _ = &roboto_bold_italic;

    var backend = try ui.RendererBackend.init(alloc, renderer);
    defer backend.deinit();

    const button_label = "Press Me";
    const label_size = try roboto_bold.measure(button_label);
    try backend.syncFont(&roboto_bold);

    var running = true;
    var frame: u32 = 0;

    while (running) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            if (event.type == sdl.SDL_EVENT_QUIT) {
                running = false;
            }
        }

        const pulse = @as(u8, @intCast((frame / 3) % 120));
        _ = sdl.SDL_SetRenderDrawColor(renderer, 18 + pulse, 26 + pulse / 2, 35, 255);
        _ = sdl.SDL_RenderClear(renderer);

        var panel = sdl.SDL_FRect{ .x = 220, .y = 140, .w = 520, .h = 260 };
        _ = sdl.SDL_SetRenderDrawColor(renderer, 38, 70, 92, 255);
        _ = sdl.SDL_RenderFillRect(renderer, &panel);

        var button = sdl.SDL_FRect{ .x = 360, .y = 300, .w = 240, .h = 64 };
        _ = sdl.SDL_SetRenderDrawColor(renderer, 74, 176, 214, 255);
        _ = sdl.SDL_RenderFillRect(renderer, &button);

        var builder = ui.Builder.init(alloc);
        defer builder.deinit();

        const text_rect = ui.Rect{
            .x = button.x,
            .y = button.y + (button.h - label_size.height) * 0.5,
            .w = button.w,
            .h = label_size.height,
        };
        try builder.push(.{ .text_run = .{
            .rect = text_rect,
            .text = button_label,
            .font_handle = 0,
            .size_px = roboto_bold.base_px,
            .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
            .alignment = .center,
        } });
        const draw_list = try builder.finish();
        defer alloc.free(draw_list.ops);
        try backend.render(draw_list, .{});

        _ = sdl.SDL_RenderPresent(renderer);
        sdl.SDL_Delay(16);
        frame +%= 1;
    }
}
