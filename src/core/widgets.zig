const std = @import("std");
const Id = @import("ids.zig").Id;
const InputState = @import("input.zig").InputState;

fn isId(maybe_id: ?Id, id: Id) bool {
    return maybe_id != null and maybe_id.?.value == id.value;
}

pub const WidgetState = struct {
    hot: ?Id = null,
    active: ?Id = null,
    focused: ?Id = null,

    pub fn beginFrame(self: *WidgetState) void {
        self.hot = null;
    }

    pub fn setFocus(self: *WidgetState, id: ?Id) void {
        self.focused = id;
    }

    pub fn isFocused(self: WidgetState, id: Id) bool {
        return isId(self.focused, id);
    }
};

pub const ButtonOptions = struct {
    hovered: bool,
    disabled: bool = false,
    focus_on_hover: bool = true,
};

pub const ButtonInteraction = struct {
    hovered: bool,
    active: bool,
    focused: bool,
    disabled: bool,
    pressed: bool,
};

pub const FocusDirection = enum {
    next,
    previous,
};

pub const FocusItem = struct {
    id: Id,
    disabled: bool = false,
};

pub fn moveFocusLinear(state: *WidgetState, items: []const FocusItem, direction: FocusDirection) void {
    if (items.len == 0) {
        state.focused = null;
        return;
    }

    var first_enabled: ?usize = null;
    var last_enabled: ?usize = null;
    var current_index: ?usize = null;

    for (items, 0..) |item, i| {
        if (!item.disabled) {
            if (first_enabled == null) first_enabled = i;
            last_enabled = i;
        }

        if (isId(state.focused, item.id)) {
            current_index = i;
        }
    }

    if (first_enabled == null) {
        state.focused = null;
        return;
    }

    if (current_index == null or items[current_index.?].disabled) {
        const seed = switch (direction) {
            .next => first_enabled.?,
            .previous => last_enabled.?,
        };
        state.focused = items[seed].id;
        return;
    }

    const len = items.len;
    const start = current_index.?;
    var step: usize = 1;
    while (step <= len) : (step += 1) {
        const idx = switch (direction) {
            .next => (start + step) % len,
            .previous => (start + len - (step % len)) % len,
        };
        if (!items[idx].disabled) {
            state.focused = items[idx].id;
            return;
        }
    }
}

pub fn buttonWithOptions(state: *WidgetState, id: Id, input: InputState, options: ButtonOptions) ButtonInteraction {
    if (options.disabled) {
        if (isId(state.hot, id)) state.hot = null;
        if (isId(state.active, id)) state.active = null;
        if (isId(state.focused, id)) state.focused = null;
        return .{
            .hovered = false,
            .active = false,
            .focused = false,
            .disabled = true,
            .pressed = false,
        };
    }

    if (options.hovered) {
        state.hot = id;
        if (options.focus_on_hover and !input.mouse_down) {
            state.focused = id;
        }
    }

    if (options.hovered and input.mouse_pressed) {
        state.active = id;
        state.focused = id;
    }

    var pressed = false;
    const is_active = isId(state.active, id);
    if (input.mouse_released and is_active) {
        state.active = null;
        pressed = options.hovered;
        if (pressed) {
            state.focused = id;
        }
    }

    const focused = isId(state.focused, id);
    if (focused and input.nav_accept) {
        pressed = true;
    }

    return .{
        .hovered = options.hovered,
        .active = isId(state.active, id),
        .focused = focused,
        .disabled = false,
        .pressed = pressed,
    };
}

pub fn button(state: *WidgetState, id: Id, hovered: bool, input: InputState) bool {
    return buttonWithOptions(state, id, input, .{ .hovered = hovered }).pressed;
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
    try std.testing.expect(pressed);
}

test "button release works with multiple buttons" {
    var state = WidgetState{};
    const a = Id.fromStr("a");
    const b = Id.fromStr("b");

    var input = InputState.init();
    input.mouse_pressed = true;
    _ = button(&state, a, false, input);
    _ = button(&state, b, true, input);

    input = InputState.init();
    input.mouse_released = true;
    const a_pressed = button(&state, a, false, input);
    const b_pressed = button(&state, b, true, input);

    try std.testing.expect(!a_pressed);
    try std.testing.expect(b_pressed);
}

test "buttonWithOptions reports hover active focus and press states" {
    var state = WidgetState{};
    const id = Id.fromStr("play");

    var input = InputState.init();
    var interaction = buttonWithOptions(&state, id, input, .{ .hovered = true });
    try std.testing.expect(interaction.hovered);
    try std.testing.expect(!interaction.active);
    try std.testing.expect(interaction.focused);
    try std.testing.expect(!interaction.pressed);

    input.mouse_pressed = true;
    interaction = buttonWithOptions(&state, id, input, .{ .hovered = true });
    try std.testing.expect(interaction.active);
    try std.testing.expect(interaction.focused);
    try std.testing.expect(!interaction.pressed);

    input = InputState.init();
    input.mouse_released = true;
    interaction = buttonWithOptions(&state, id, input, .{ .hovered = true });
    try std.testing.expect(!interaction.active);
    try std.testing.expect(interaction.pressed);
}

test "disabled buttons ignore input and clear tracked state" {
    var state = WidgetState{};
    const id = Id.fromStr("disabled");
    state.hot = id;
    state.active = id;
    state.focused = id;

    var input = InputState.init();
    input.mouse_pressed = true;
    input.nav_accept = true;

    const interaction = buttonWithOptions(&state, id, input, .{ .hovered = true, .disabled = true });
    try std.testing.expect(interaction.disabled);
    try std.testing.expect(!interaction.pressed);
    try std.testing.expect(state.hot == null);
    try std.testing.expect(state.active == null);
    try std.testing.expect(state.focused == null);
}

test "focused button can be activated by nav accept" {
    var state = WidgetState{};
    const id = Id.fromStr("focused");
    state.setFocus(id);

    var input = InputState.init();
    input.nav_accept = true;
    const interaction = buttonWithOptions(&state, id, input, .{ .hovered = false, .focus_on_hover = false });

    try std.testing.expect(interaction.focused);
    try std.testing.expect(interaction.pressed);
}

test "moveFocusLinear skips disabled entries and wraps" {
    var state = WidgetState{};

    const a = Id.fromStr("a");
    const b = Id.fromStr("b");
    const c = Id.fromStr("c");
    const d = Id.fromStr("d");

    const items = [_]FocusItem{
        .{ .id = a, .disabled = true },
        .{ .id = b },
        .{ .id = c, .disabled = true },
        .{ .id = d },
    };

    moveFocusLinear(&state, &items, .next);
    try std.testing.expect(state.isFocused(b));

    moveFocusLinear(&state, &items, .next);
    try std.testing.expect(state.isFocused(d));

    moveFocusLinear(&state, &items, .next);
    try std.testing.expect(state.isFocused(b));

    moveFocusLinear(&state, &items, .previous);
    try std.testing.expect(state.isFocused(d));
}

test "beginFrame clears hot state" {
    var state = WidgetState{};
    state.hot = Id.fromStr("hot");

    state.beginFrame();
    try std.testing.expect(state.hot == null);
}
