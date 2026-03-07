pub const Button = enum {
    dpad_up,
    dpad_down,
    dpad_left,
    dpad_right,
    south,
    east,
};

pub const NavAction = enum {
    up,
    down,
    left,
    right,
    accept,
    back,
};

pub fn mapButton(button: Button) NavAction {
    return switch (button) {
        .dpad_up => .up,
        .dpad_down => .down,
        .dpad_left => .left,
        .dpad_right => .right,
        .south => .accept,
        .east => .back,
    };
}
