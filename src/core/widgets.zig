const Id = @import("ids.zig").Id;
const InputState = @import("input.zig").InputState;

pub const WidgetState = struct {
    hot: ?Id = null,
    active: ?Id = null,
};

pub fn button(state: *WidgetState, id: Id, hovered: bool, input: InputState) bool {
    if (hovered) state.hot = id;

    if (hovered and input.mouse_pressed) {
        state.active = id;
    }

    if (input.mouse_released) {
        const pressed = (state.active != null and state.active.?.value == id.value and hovered);
        state.active = null;
        return pressed;
    }

    return false;
}

test "button press requires press and release while hovered" {
    var state = WidgetState{};
    const id = Id.fromStr("play");

    var input = InputState.init();
    input.mouse_pressed = true;
    _ = button(&state, id, true, input);

    input = InputState.init();
    input.mouse_released = true;
    const pressed = button(&state, id, true, input);
    try @import("std").testing.expect(pressed);
}
