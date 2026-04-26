const std = @import("std");
const Id = @import("ids.zig").Id;
const InputState = @import("input.zig").InputState;
const Builder = @import("draw_list.zig").Builder;
const Color = @import("draw_list.zig").Color;
const DrawList = @import("draw_list.zig").DrawList;
const DrawOp = @import("draw_list.zig").DrawOp;
const Rect = @import("draw_list.zig").Rect;
const Theme = @import("theme.zig").Theme;
const widgets = @import("widgets.zig");
const events = @import("../platform/sdl_events.zig");

const theme_labels = [_][]const u8{
    "Ocean Blue",
    "Forest Green",
    "Sunset Orange",
    "Steel Night",
};

const theme_ids = [_]Id{
    Id.fromStr("theme_ocean"),
    Id.fromStr("theme_forest"),
    Id.fromStr("theme_sunset"),
    Id.fromStr("theme_steel"),
};

const theme_buttons = [_][3]u8{
    .{ 66, 140, 196 },
    .{ 78, 156, 98 },
    .{ 196, 118, 74 },
    .{ 112, 126, 168 },
};

const pulse_toggle_id = Id.fromStr("menu_toggle_pulse");
const quit_id = Id.fromStr("menu_quit");

const menu_focus_items = [_]widgets.FocusItem{
    .{ .id = theme_ids[0] },
    .{ .id = theme_ids[1] },
    .{ .id = theme_ids[2] },
    .{ .id = theme_ids[3] },
    .{ .id = pulse_toggle_id },
    .{ .id = quit_id },
};

pub const MenuState = struct {
    selected_theme: usize = 0,
    pulse_enabled: bool = false,
    running: bool = true,
};

const MenuLayout = struct {
    panel_rect: Rect,
    theme_rects: [theme_ids.len]Rect,
    pulse_rect: Rect,
    quit_rect: Rect,
};

fn saturatingAdd(base: u8, delta: u8) u8 {
    const sum: u16 = @as(u16, base) + @as(u16, delta);
    return @intCast(@min(sum, 255));
}

fn pointInRect(rect: Rect, x: f32, y: f32) bool {
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h;
}

fn rectApproxEq(a: Rect, b: Rect) bool {
    const eps: f32 = 0.01;
    return @abs(a.x - b.x) <= eps and @abs(a.y - b.y) <= eps and @abs(a.w - b.w) <= eps and @abs(a.h - b.h) <= eps;
}

fn layoutForScreen(screen_w: f32, screen_h: f32) MenuLayout {
    const panel_w = std.math.clamp(screen_w * 0.56, 420.0, 740.0);
    const panel_h = std.math.clamp(screen_h * 0.74, 320.0, 520.0);
    const panel_rect = Rect{
        .x = (screen_w - panel_w) * 0.5,
        .y = (screen_h - panel_h) * 0.5,
        .w = panel_w,
        .h = panel_h,
    };

    const button_w = panel_rect.w - 72.0;
    const button_h = 52.0;
    const button_gap = 12.0;
    const control_gap = 14.0;
    const theme_count_f = @as(f32, @floatFromInt(theme_ids.len));
    const theme_buttons_total_h = theme_count_f * button_h + @as(f32, @floatFromInt(theme_ids.len - 1)) * button_gap;
    const controls_total_h = theme_buttons_total_h + control_gap + button_h + control_gap + button_h;
    const buttons_start_y = panel_rect.y + panel_rect.h - controls_total_h - 26.0;

    var theme_rects: [theme_ids.len]Rect = undefined;
    for (0..theme_ids.len) |i| {
        theme_rects[i] = .{
            .x = panel_rect.x + 36.0,
            .y = buttons_start_y + @as(f32, @floatFromInt(i)) * (button_h + button_gap),
            .w = button_w,
            .h = button_h,
        };
    }

    const pulse_rect = Rect{
        .x = panel_rect.x + 36.0,
        .y = buttons_start_y + theme_buttons_total_h + control_gap,
        .w = button_w,
        .h = button_h,
    };

    const quit_rect = Rect{
        .x = panel_rect.x + 36.0,
        .y = pulse_rect.y + button_h + control_gap,
        .w = button_w,
        .h = button_h,
    };

    return .{
        .panel_rect = panel_rect,
        .theme_rects = theme_rects,
        .pulse_rect = pulse_rect,
        .quit_rect = quit_rect,
    };
}

fn interactionBoost(interaction: widgets.ButtonInteraction, selected: bool) u8 {
    if (interaction.active) return 36;
    if (interaction.hovered) return 30;
    if (interaction.focused) return 20;
    if (selected) return 14;
    return 0;
}

fn boostedColor(rgb: [3]u8, boost: u8) Color {
    return .{
        .r = @as(f32, @floatFromInt(saturatingAdd(rgb[0], boost))) / 255.0,
        .g = @as(f32, @floatFromInt(saturatingAdd(rgb[1], boost))) / 255.0,
        .b = @as(f32, @floatFromInt(saturatingAdd(rgb[2], boost))) / 255.0,
        .a = 1.0,
    };
}

fn pushButtonVisual(builder: *Builder, rect: Rect, fill: Color, focused: bool, selected: bool) !void {
    try builder.push(.{ .rect_filled = .{
        .rect = rect,
        .color = fill,
        .radius = 8,
    } });

    if (selected or focused) {
        try builder.push(.{ .rect_stroke = .{
            .rect = rect,
            .color = if (focused)
                .{ .r = 0.72, .g = 0.95, .b = 1.0, .a = 1.0 }
            else
                .{ .r = 0.96, .g = 0.98, .b = 1.0, .a = 1.0 },
            .thickness = 2,
            .radius = 8,
        } });
    }
}

pub fn menuFrame(
    allocator: std.mem.Allocator,
    state: *MenuState,
    widget_state: *widgets.WidgetState,
    input: InputState,
    screen: struct { w: f32 = 960, h: f32 = 540 },
    theme: Theme,
) !DrawList {
    widget_state.beginFrame();

    if (input.nav_down) {
        widgets.moveFocusLinear(widget_state, &menu_focus_items, .next);
    }
    if (input.nav_up) {
        widgets.moveFocusLinear(widget_state, &menu_focus_items, .previous);
    }

    const layout = layoutForScreen(screen.w, screen.h);

    var theme_interactions: [theme_ids.len]widgets.ButtonInteraction = undefined;
    for (0..theme_ids.len) |i| {
        const hovered = pointInRect(layout.theme_rects[i], input.mouse_pos.x, input.mouse_pos.y);
        theme_interactions[i] = widgets.buttonWithOptions(widget_state, theme_ids[i], input, .{ .hovered = hovered });
        if (theme_interactions[i].pressed) {
            state.selected_theme = i;
        }
    }

    const pulse_hovered = pointInRect(layout.pulse_rect, input.mouse_pos.x, input.mouse_pos.y);
    const pulse_interaction = widgets.buttonWithOptions(widget_state, pulse_toggle_id, input, .{ .hovered = pulse_hovered });
    if (pulse_interaction.pressed) {
        state.pulse_enabled = !state.pulse_enabled;
    }

    const quit_hovered = pointInRect(layout.quit_rect, input.mouse_pos.x, input.mouse_pos.y);
    const quit_interaction = widgets.buttonWithOptions(widget_state, quit_id, input, .{ .hovered = quit_hovered });
    if (quit_interaction.pressed) {
        state.running = false;
    }

    var builder = Builder.init(allocator);
    defer builder.deinit();

    try builder.push(.{ .clip_push = layout.panel_rect });
    try builder.push(.{ .rect_filled = .{
        .rect = layout.panel_rect,
        .color = .{ .r = 0.09, .g = 0.10, .b = 0.14, .a = 0.92 },
        .radius = 10,
    } });

    for (0..theme_ids.len) |i| {
        const selected = state.selected_theme == i;
        const boost = interactionBoost(theme_interactions[i], selected);
        try pushButtonVisual(
            &builder,
            layout.theme_rects[i],
            boostedColor(theme_buttons[i], boost),
            theme_interactions[i].focused,
            selected,
        );
        try builder.push(.{ .text_run = .{
            .rect = layout.theme_rects[i],
            .text = theme_labels[i],
            .font_handle = theme.font_body,
            .size_px = 18,
            .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
            .alignment = .center,
        } });
    }

    const pulse_rgb = if (state.pulse_enabled) [3]u8{ 76, 162, 178 } else [3]u8{ 98, 106, 120 };
    const pulse_boost = interactionBoost(pulse_interaction, false);
    try pushButtonVisual(
        &builder,
        layout.pulse_rect,
        boostedColor(pulse_rgb, pulse_boost),
        pulse_interaction.focused,
        false,
    );
    try builder.push(.{ .text_run = .{
        .rect = layout.pulse_rect,
        .text = if (state.pulse_enabled) "Pulse: On" else "Pulse: Off",
        .font_handle = theme.font_body,
        .size_px = 18,
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        .alignment = .center,
    } });

    const quit_boost = interactionBoost(quit_interaction, false);
    try pushButtonVisual(
        &builder,
        layout.quit_rect,
        boostedColor(.{ 154, 46, 58 }, quit_boost),
        quit_interaction.focused,
        false,
    );
    try builder.push(.{ .text_run = .{
        .rect = layout.quit_rect,
        .text = "Quit",
        .font_handle = theme.font_body,
        .size_px = 18,
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        .alignment = .center,
    } });

    try builder.push(.{ .clip_pop = {} });
    return builder.finish();
}

fn expectMenuOutputShape(draw_list: DrawList) !void {
    var clip_push_count: usize = 0;
    var clip_pop_count: usize = 0;
    var rect_filled_count: usize = 0;
    var text_run_count: usize = 0;

    for (draw_list.ops) |op| {
        switch (op) {
            .clip_push => clip_push_count += 1,
            .clip_pop => clip_pop_count += 1,
            .rect_filled => rect_filled_count += 1,
            .text_run => text_run_count += 1,
            else => {},
        }
    }

    try std.testing.expectEqual(@as(usize, 1), clip_push_count);
    try std.testing.expectEqual(@as(usize, 1), clip_pop_count);
    try std.testing.expectEqual(@as(usize, 7), rect_filled_count);
    try std.testing.expectEqual(@as(usize, 6), text_run_count);
}

fn drawListHasStrokeForRect(draw_list: DrawList, rect: Rect) bool {
    for (draw_list.ops) |op| {
        switch (op) {
            .rect_stroke => |stroke| {
                if (rectApproxEq(stroke.rect, rect)) {
                    return true;
                }
            },
            else => {},
        }
    }
    return false;
}

test "menu integration mouse click changes selection and emits valid draw list" {
    var menu_state = MenuState{};
    var widget_state = widgets.WidgetState{};
    var input = InputState.init();

    const layout = layoutForScreen(960, 540);
    const target = layout.theme_rects[2];
    const cx = target.x + target.w * 0.5;
    const cy = target.y + target.h * 0.5;

    input = events.fromEvents(&.{ .{ .mouse_move = .{ .x = cx, .y = cy } }, .mouse_button_down }, input);
    {
        const draw_list = try menuFrame(std.testing.allocator, &menu_state, &widget_state, input, .{}, Theme.default);
        defer std.testing.allocator.free(draw_list.ops);
        try draw_list.validateContract();
        try expectMenuOutputShape(draw_list);
        try std.testing.expectEqual(@as(usize, 0), menu_state.selected_theme);
    }

    input = events.fromEvents(&.{.mouse_button_up}, input);
    {
        const draw_list = try menuFrame(std.testing.allocator, &menu_state, &widget_state, input, .{}, Theme.default);
        defer std.testing.allocator.free(draw_list.ops);
        try draw_list.validateContract();
        try expectMenuOutputShape(draw_list);
        try std.testing.expectEqual(@as(usize, 2), menu_state.selected_theme);
        try std.testing.expect(drawListHasStrokeForRect(draw_list, target));
    }
}

test "menu integration nav focus and accept toggles pulse" {
    var menu_state = MenuState{};
    var widget_state = widgets.WidgetState{};
    var input = InputState.init();

    const layout = layoutForScreen(960, 540);

    var step: usize = 0;
    while (step < 5) : (step += 1) {
        input = events.fromEvents(&.{.{ .key_down = .down }}, input);
        const draw_list = try menuFrame(std.testing.allocator, &menu_state, &widget_state, input, .{}, Theme.default);
        defer std.testing.allocator.free(draw_list.ops);
        try draw_list.validateContract();
        try expectMenuOutputShape(draw_list);
    }

    input = events.fromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const draw_list = try menuFrame(std.testing.allocator, &menu_state, &widget_state, input, .{}, Theme.default);
        defer std.testing.allocator.free(draw_list.ops);
        try draw_list.validateContract();
        try expectMenuOutputShape(draw_list);
        try std.testing.expect(menu_state.pulse_enabled);
        try std.testing.expect(menu_state.running);
        try std.testing.expect(drawListHasStrokeForRect(draw_list, layout.pulse_rect));
    }
}

test "menu integration nav accept on quit updates running state" {
    var menu_state = MenuState{};
    var widget_state = widgets.WidgetState{};
    var input = InputState.init();

    var step: usize = 0;
    while (step < 6) : (step += 1) {
        input = events.fromEvents(&.{.{ .key_down = .down }}, input);
        const draw_list = try menuFrame(std.testing.allocator, &menu_state, &widget_state, input, .{}, Theme.default);
        defer std.testing.allocator.free(draw_list.ops);
        try draw_list.validateContract();
    }

    input = events.fromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const draw_list = try menuFrame(std.testing.allocator, &menu_state, &widget_state, input, .{}, Theme.default);
        defer std.testing.allocator.free(draw_list.ops);
        try draw_list.validateContract();
        try std.testing.expect(!menu_state.running);
    }
}

test "menu integration draw list keeps op count in sync" {
    var menu_state = MenuState{};
    var widget_state = widgets.WidgetState{};
    const draw_list = try menuFrame(std.testing.allocator, &menu_state, &widget_state, InputState.init(), .{}, Theme.default);
    defer std.testing.allocator.free(draw_list.ops);

    try std.testing.expectEqual(draw_list.stats.op_count, draw_list.ops.len);
}
