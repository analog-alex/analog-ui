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

        _ = sdl.SDL_RenderPresent(renderer);
        sdl.SDL_Delay(16);
        frame +%= 1;
    }
}
