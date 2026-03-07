const InputState = @import("../core/input.zig").InputState;
const keys = @import("sdl_keys.zig");
const gamepad = @import("sdl_gamepad.zig");
const sdl = @import("../backend/sdl_shared.zig");

pub const Event = union(enum) {
    mouse_move: struct { x: f32, y: f32 },
    mouse_button_down: void,
    mouse_button_up: void,
    mouse_wheel: struct { x: f32, y: f32 },
    key_down: keys.Keycode,
    gamepad_button_down: gamepad.Button,
};

pub fn fromEvents(events: []const Event, previous: InputState) InputState {
    var out = previous;
    out.clearFrameDeltas();

    for (events) |ev| {
        switch (ev) {
            .mouse_move => |m| out.mouse_pos = .{ .x = m.x, .y = m.y },
            .mouse_button_down => {
                if (!out.mouse_down) out.mouse_pressed = true;
                out.mouse_down = true;
            },
            .mouse_button_up => {
                if (out.mouse_down) out.mouse_released = true;
                out.mouse_down = false;
            },
            .mouse_wheel => |w| {
                out.scroll_x += w.x;
                out.scroll_y += w.y;
            },
            .key_down => |k| {
                if (keys.mapKeycode(k)) |action| {
                    switch (action) {
                        .up => out.nav_up = true,
                        .down => out.nav_down = true,
                        .left => out.nav_left = true,
                        .right => out.nav_right = true,
                        .accept => out.nav_accept = true,
                        .back => out.nav_back = true,
                    }
                }
            },
            .gamepad_button_down => |btn| {
                switch (gamepad.mapButton(btn)) {
                    .up => out.nav_up = true,
                    .down => out.nav_down = true,
                    .left => out.nav_left = true,
                    .right => out.nav_right = true,
                    .accept => out.nav_accept = true,
                    .back => out.nav_back = true,
                }
            },
        }
    }

    return out;
}

pub fn fromSdlEvents(events: []const sdl.SDL_Event, previous: InputState) InputState {
    var out = previous;
    out.clearFrameDeltas();

    for (events) |ev| {
        switch (ev.type) {
            sdl.c.SDL_EVENT_MOUSE_MOTION => {
                out.mouse_pos = .{ .x = ev.motion.x, .y = ev.motion.y };
            },
            sdl.c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                if (!out.mouse_down) out.mouse_pressed = true;
                out.mouse_down = true;
            },
            sdl.c.SDL_EVENT_MOUSE_BUTTON_UP => {
                if (out.mouse_down) out.mouse_released = true;
                out.mouse_down = false;
            },
            sdl.c.SDL_EVENT_MOUSE_WHEEL => {
                out.scroll_x += ev.wheel.x;
                out.scroll_y += ev.wheel.y;
            },
            sdl.c.SDL_EVENT_KEY_DOWN => {
                const maybe_action = switch (ev.key.key) {
                    sdl.c.SDLK_UP => keys.KeyAction.up,
                    sdl.c.SDLK_DOWN => keys.KeyAction.down,
                    sdl.c.SDLK_LEFT => keys.KeyAction.left,
                    sdl.c.SDLK_RIGHT => keys.KeyAction.right,
                    sdl.c.SDLK_RETURN, sdl.c.SDLK_KP_ENTER => keys.KeyAction.accept,
                    sdl.c.SDLK_ESCAPE => keys.KeyAction.back,
                    else => null,
                };

                if (maybe_action) |action| {
                    switch (action) {
                        .up => out.nav_up = true,
                        .down => out.nav_down = true,
                        .left => out.nav_left = true,
                        .right => out.nav_right = true,
                        .accept => out.nav_accept = true,
                        .back => out.nav_back = true,
                    }
                }
            },
            sdl.c.SDL_EVENT_GAMEPAD_BUTTON_DOWN => {
                const nav_action = switch (ev.gbutton.button) {
                    sdl.c.SDL_GAMEPAD_BUTTON_DPAD_UP => gamepad.NavAction.up,
                    sdl.c.SDL_GAMEPAD_BUTTON_DPAD_DOWN => gamepad.NavAction.down,
                    sdl.c.SDL_GAMEPAD_BUTTON_DPAD_LEFT => gamepad.NavAction.left,
                    sdl.c.SDL_GAMEPAD_BUTTON_DPAD_RIGHT => gamepad.NavAction.right,
                    sdl.c.SDL_GAMEPAD_BUTTON_SOUTH => gamepad.NavAction.accept,
                    sdl.c.SDL_GAMEPAD_BUTTON_EAST => gamepad.NavAction.back,
                    else => null,
                };

                if (nav_action) |a| {
                    switch (a) {
                        .up => out.nav_up = true,
                        .down => out.nav_down = true,
                        .left => out.nav_left = true,
                        .right => out.nav_right = true,
                        .accept => out.nav_accept = true,
                        .back => out.nav_back = true,
                    }
                }
            },
            else => {},
        }
    }

    return out;
}

test "fromEvents sets mouse pressed and release deltas" {
    var input = InputState.init();
    input = fromEvents(&.{.mouse_button_down}, input);
    try @import("std").testing.expect(input.mouse_pressed);
    try @import("std").testing.expect(input.mouse_down);

    input = fromEvents(&.{.mouse_button_up}, input);
    try @import("std").testing.expect(input.mouse_released);
    try @import("std").testing.expect(!input.mouse_down);
}

test "fromSdlEvents handles empty input" {
    var input = InputState.init();
    input.mouse_down = true;
    const out = fromSdlEvents(&.{}, input);
    try @import("std").testing.expect(out.mouse_down);
    try @import("std").testing.expect(!out.mouse_pressed);
}
