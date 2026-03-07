pub const KeyAction = enum {
    up,
    down,
    left,
    right,
    accept,
    back,
};

pub const Keycode = enum(i32) {
    up = 1,
    down = 2,
    left = 3,
    right = 4,
    enter = 5,
    escape = 6,
    unknown = 999,
};

pub fn mapKeycode(key: Keycode) ?KeyAction {
    return switch (key) {
        .up => .up,
        .down => .down,
        .left => .left,
        .right => .right,
        .enter => .accept,
        .escape => .back,
        .unknown => null,
    };
}

test "mapKeycode maps enter to accept" {
    try @import("std").testing.expectEqual(@as(?KeyAction, .accept), mapKeycode(.enter));
}
