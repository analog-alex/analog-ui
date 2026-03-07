pub const Vec2 = struct {
    x: f32,
    y: f32,
};

pub const InputState = struct {
    mouse_pos: Vec2,
    mouse_down: bool,
    mouse_pressed: bool,
    mouse_released: bool,
    scroll_x: f32,
    scroll_y: f32,

    nav_up: bool,
    nav_down: bool,
    nav_left: bool,
    nav_right: bool,
    nav_accept: bool,
    nav_back: bool,

    pub fn init() InputState {
        return .{
            .mouse_pos = .{ .x = 0, .y = 0 },
            .mouse_down = false,
            .mouse_pressed = false,
            .mouse_released = false,
            .scroll_x = 0,
            .scroll_y = 0,
            .nav_up = false,
            .nav_down = false,
            .nav_left = false,
            .nav_right = false,
            .nav_accept = false,
            .nav_back = false,
        };
    }

    pub fn clearFrameDeltas(self: *InputState) void {
        self.mouse_pressed = false;
        self.mouse_released = false;
        self.scroll_x = 0;
        self.scroll_y = 0;
        self.nav_up = false;
        self.nav_down = false;
        self.nav_left = false;
        self.nav_right = false;
        self.nav_accept = false;
        self.nav_back = false;
    }
};

test "InputState.init returns zeroed state" {
    const input = InputState.init();
    try @import("std").testing.expectEqual(false, input.mouse_down);
    try @import("std").testing.expectEqual(@as(f32, 0), input.mouse_pos.x);
    try @import("std").testing.expectEqual(@as(f32, 0), input.mouse_pos.y);
}

test "InputState.clearFrameDeltas clears transient flags" {
    var input = InputState.init();
    input.mouse_pressed = true;
    input.scroll_y = 2;
    input.nav_accept = true;
    input.mouse_down = true;

    input.clearFrameDeltas();

    try @import("std").testing.expectEqual(false, input.mouse_pressed);
    try @import("std").testing.expectEqual(@as(f32, 0), input.scroll_y);
    try @import("std").testing.expectEqual(false, input.nav_accept);
    try @import("std").testing.expectEqual(true, input.mouse_down);
}
