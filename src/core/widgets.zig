const std = @import("std");
const Id = @import("ids.zig").Id;
const Builder = @import("draw_list.zig").Builder;
const Color = @import("draw_list.zig").Color;
const ImageId = @import("draw_list.zig").ImageId;
const Rect = @import("draw_list.zig").Rect;
const TextAlign = @import("draw_list.zig").TextAlign;
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

pub const CoreWidgets = struct {
    pub const Axis = enum {
        horizontal,
        vertical,
    };

    pub const LabelOptions = struct {
        font_handle: u16 = 0,
        size_px: f32 = 16.0,
        color: Color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        alignment: TextAlign = .left,
    };

    pub const ImageOptions = struct {
        tint: Color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
    };

    pub const SeparatorOptions = struct {
        color: Color = .{ .r = 0.8, .g = 0.85, .b = 0.95, .a = 0.45 },
        thickness: f32 = 1.0,
        axis: Axis = .horizontal,
    };

    pub const ButtonWidgetOptions = struct {
        disabled: bool = false,
        focus_on_hover: bool = true,
        fill_color: Color = .{ .r = 0.22, .g = 0.48, .b = 0.72, .a = 1.0 },
        border_color: Color = .{ .r = 0.85, .g = 0.9, .b = 0.98, .a = 0.7 },
        focused_border_color: Color = .{ .r = 0.72, .g = 0.95, .b = 1.0, .a = 1.0 },
        text_color: Color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        radius: f32 = 8.0,
        border_thickness: f32 = 2.0,
        font_handle: u16 = 0,
        size_px: f32 = 18.0,
        alignment: TextAlign = .center,
        active_boost: f32 = 0.16,
        hover_boost: f32 = 0.11,
        focus_boost: f32 = 0.06,
    };

    fn pointInRect(rect: Rect, x: f32, y: f32) bool {
        return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h;
    }

    fn scaleColor(color: Color, boost: f32) Color {
        return .{
            .r = std.math.clamp(color.r + boost, 0.0, 1.0),
            .g = std.math.clamp(color.g + boost, 0.0, 1.0),
            .b = std.math.clamp(color.b + boost, 0.0, 1.0),
            .a = color.a,
        };
    }

    pub fn label(builder: *Builder, rect: Rect, text: []const u8, options: LabelOptions) !void {
        try builder.push(.{ .text_run = .{
            .rect = rect,
            .text = text,
            .font_handle = options.font_handle,
            .size_px = options.size_px,
            .color = options.color,
            .alignment = options.alignment,
        } });
    }

    pub fn image(builder: *Builder, rect: Rect, image_id: ImageId, options: ImageOptions) !void {
        try builder.push(.{ .image = .{
            .rect = rect,
            .image_id = image_id,
            .tint = options.tint,
        } });
    }

    pub fn spacer(rect: Rect, amount: f32, axis: Axis) Rect {
        return switch (axis) {
            .horizontal => .{ .x = rect.x + amount, .y = rect.y, .w = rect.w, .h = rect.h },
            .vertical => .{ .x = rect.x, .y = rect.y + amount, .w = rect.w, .h = rect.h },
        };
    }

    pub fn separator(builder: *Builder, rect: Rect, options: SeparatorOptions) !void {
        const thickness = @max(options.thickness, 1.0);
        const line_rect: Rect = switch (options.axis) {
            .horizontal => .{
                .x = rect.x,
                .y = rect.y + (rect.h - thickness) * 0.5,
                .w = rect.w,
                .h = thickness,
            },
            .vertical => .{
                .x = rect.x + (rect.w - thickness) * 0.5,
                .y = rect.y,
                .w = thickness,
                .h = rect.h,
            },
        };

        try builder.push(.{ .rect_filled = .{
            .rect = line_rect,
            .color = options.color,
            .radius = 0,
        } });
    }

    pub fn button(
        builder: *Builder,
        state: *WidgetState,
        id: Id,
        rect: Rect,
        text: []const u8,
        input: InputState,
        options: ButtonWidgetOptions,
    ) !ButtonInteraction {
        const hovered = pointInRect(rect, input.mouse_pos.x, input.mouse_pos.y);
        const interaction = buttonWithOptions(state, id, input, .{
            .hovered = hovered,
            .disabled = options.disabled,
            .focus_on_hover = options.focus_on_hover,
        });

        const fill = if (interaction.disabled)
            scaleColor(options.fill_color, -0.18)
        else if (interaction.active)
            scaleColor(options.fill_color, options.active_boost)
        else if (interaction.hovered)
            scaleColor(options.fill_color, options.hover_boost)
        else if (interaction.focused)
            scaleColor(options.fill_color, options.focus_boost)
        else
            options.fill_color;

        try builder.push(.{ .rect_filled = .{
            .rect = rect,
            .color = fill,
            .radius = options.radius,
        } });

        try builder.push(.{ .rect_stroke = .{
            .rect = rect,
            .color = if (interaction.focused) options.focused_border_color else options.border_color,
            .thickness = options.border_thickness,
            .radius = options.radius,
        } });

        try label(builder, rect, text, .{
            .font_handle = options.font_handle,
            .size_px = options.size_px,
            .color = if (interaction.disabled) scaleColor(options.text_color, -0.35) else options.text_color,
            .alignment = options.alignment,
        });

        return interaction;
    }
};

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

test "CoreWidgets label image and separator append draw ops" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();

    try CoreWidgets.label(&builder, .{ .x = 10, .y = 10, .w = 80, .h = 24 }, "HP", .{});
    try CoreWidgets.image(&builder, .{ .x = 10, .y = 40, .w = 24, .h = 24 }, 42, .{});
    try CoreWidgets.separator(&builder, .{ .x = 0, .y = 80, .w = 120, .h = 8 }, .{});

    const draw_list = try builder.finish();
    defer std.testing.allocator.free(draw_list.ops);

    try std.testing.expectEqual(@as(usize, 3), draw_list.ops.len);
    try std.testing.expectEqual(@as(u32, 3), draw_list.stats.op_count);

    try std.testing.expect(switch (draw_list.ops[0]) {
        .text_run => true,
        else => false,
    });
    try std.testing.expect(switch (draw_list.ops[1]) {
        .image => true,
        else => false,
    });
    try std.testing.expect(switch (draw_list.ops[2]) {
        .rect_filled => true,
        else => false,
    });
}

test "CoreWidgets spacer shifts rect by axis" {
    const rect = Rect{ .x = 10, .y = 20, .w = 100, .h = 40 };

    const moved_y = CoreWidgets.spacer(rect, 12, .vertical);
    try std.testing.expectEqual(@as(f32, 10), moved_y.x);
    try std.testing.expectEqual(@as(f32, 32), moved_y.y);

    const moved_x = CoreWidgets.spacer(rect, 8, .horizontal);
    try std.testing.expectEqual(@as(f32, 18), moved_x.x);
    try std.testing.expectEqual(@as(f32, 20), moved_x.y);
}

test "CoreWidgets button renders ops and reports pressed" {
    var widget_state = WidgetState{};
    const button_id = Id.fromStr("core_button");
    const rect = Rect{ .x = 20, .y = 20, .w = 180, .h = 44 };

    var input = InputState.init();
    input.mouse_pos = .{ .x = 40, .y = 40 };
    input.mouse_pressed = true;
    {
        var builder = Builder.init(std.testing.allocator);
        defer builder.deinit();

        const interaction = try CoreWidgets.button(&builder, &widget_state, button_id, rect, "Play", input, .{});
        try std.testing.expect(!interaction.pressed);

        const draw_list = try builder.finish();
        defer std.testing.allocator.free(draw_list.ops);
        try std.testing.expectEqual(@as(usize, 3), draw_list.ops.len);
    }

    input = InputState.init();
    input.mouse_pos = .{ .x = 40, .y = 40 };
    input.mouse_released = true;
    {
        var builder = Builder.init(std.testing.allocator);
        defer builder.deinit();

        const interaction = try CoreWidgets.button(&builder, &widget_state, button_id, rect, "Play", input, .{});
        try std.testing.expect(interaction.pressed);

        const draw_list = try builder.finish();
        defer std.testing.allocator.free(draw_list.ops);
        try std.testing.expectEqual(@as(usize, 3), draw_list.ops.len);
    }
}
