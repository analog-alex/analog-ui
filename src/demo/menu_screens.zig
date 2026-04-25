const std = @import("std");
const ui = @import("analog_ui");
const core_widgets = ui.CoreWidgets;

pub const Screen = enum {
    title,
    pause,
    settings,
};

pub const State = struct {
    current_screen: Screen = .title,
    settings_return_screen: Screen = .title,
    running: bool = true,
    music_enabled: bool = true,
    sfx_enabled: bool = true,
    selected_theme: usize = 0,
};

pub const FrameOutput = struct {
    draw_list: ui.DrawList,
    background_rgb: [3]u8,
};

const title_start_id = ui.Id.fromStr("title_start");
const title_settings_id = ui.Id.fromStr("title_settings");
const title_quit_id = ui.Id.fromStr("title_quit");

const pause_resume_id = ui.Id.fromStr("pause_resume");
const pause_settings_id = ui.Id.fromStr("pause_settings");
const pause_title_id = ui.Id.fromStr("pause_title");

const settings_music_id = ui.Id.fromStr("settings_music");
const settings_sfx_id = ui.Id.fromStr("settings_sfx");
const settings_theme_id = ui.Id.fromStr("settings_theme");
const settings_back_id = ui.Id.fromStr("settings_back");

const title_focus_items = [_]ui.FocusItem{
    .{ .id = title_start_id },
    .{ .id = title_settings_id },
    .{ .id = title_quit_id },
};

const pause_focus_items = [_]ui.FocusItem{
    .{ .id = pause_resume_id },
    .{ .id = pause_settings_id },
    .{ .id = pause_title_id },
};

const settings_focus_items = [_]ui.FocusItem{
    .{ .id = settings_music_id },
    .{ .id = settings_sfx_id },
    .{ .id = settings_theme_id },
    .{ .id = settings_back_id },
};

const theme_setting_labels = [_][]const u8{
    "Theme: Ocean Blue",
    "Theme: Forest Green",
    "Theme: Sunset Orange",
    "Theme: Steel Night",
};

const theme_backgrounds = [_][3]u8{
    .{ 24, 46, 66 },
    .{ 24, 56, 38 },
    .{ 74, 44, 24 },
    .{ 36, 40, 58 },
};

const ScreenLayout = struct {
    panel_rect: ui.Rect,
    button_rects: [4]ui.Rect,
};

fn focusItems(screen: Screen) []const ui.FocusItem {
    return switch (screen) {
        .title => &title_focus_items,
        .pause => &pause_focus_items,
        .settings => &settings_focus_items,
    };
}

fn buttonCount(screen: Screen) usize {
    return switch (screen) {
        .title => 3,
        .pause => 3,
        .settings => 4,
    };
}

fn layoutForScreen(screen_w: f32, screen_h: f32, count: usize) ScreenLayout {
    const panel_w = std.math.clamp(screen_w * 0.56, 420.0, 760.0);
    const panel_h = std.math.clamp(screen_h * 0.74, 320.0, 540.0);
    const panel_rect = ui.Rect{
        .x = (screen_w - panel_w) * 0.5,
        .y = (screen_h - panel_h) * 0.5,
        .w = panel_w,
        .h = panel_h,
    };

    const button_w = panel_rect.w - 72.0;
    const button_h = 52.0;
    const button_gap = 12.0;
    const count_f = @as(f32, @floatFromInt(count));
    const buttons_h = count_f * button_h + @as(f32, @floatFromInt(if (count > 0) count - 1 else 0)) * button_gap;
    const buttons_start_y = panel_rect.y + panel_rect.h - buttons_h - 32.0;

    var button_rects: [4]ui.Rect = undefined;
    for (0..count) |i| {
        button_rects[i] = .{
            .x = panel_rect.x + 36.0,
            .y = buttons_start_y + @as(f32, @floatFromInt(i)) * (button_h + button_gap),
            .w = button_w,
            .h = button_h,
        };
    }

    return .{
        .panel_rect = panel_rect,
        .button_rects = button_rects,
    };
}

fn colorFromRgb(rgb: [3]u8) ui.Color {
    return .{
        .r = @as(f32, @floatFromInt(rgb[0])) / 255.0,
        .g = @as(f32, @floatFromInt(rgb[1])) / 255.0,
        .b = @as(f32, @floatFromInt(rgb[2])) / 255.0,
        .a = 1.0,
    };
}

fn buttonStyle(base_rgb: [3]u8) core_widgets.ButtonWidgetOptions {
    return .{
        .fill_color = colorFromRgb(base_rgb),
        .size_px = 18,
        .alignment = .center,
    };
}

fn setScreen(state: *State, widget_state: *ui.WidgetState, next: Screen) void {
    if (state.current_screen != next) {
        state.current_screen = next;
        widget_state.setFocus(null);
    }
}

fn screenHeader(screen: Screen) struct { title: []const u8, subtitle: []const u8 } {
    return switch (screen) {
        .title => .{
            .title = "TITLE SCREEN",
            .subtitle = "Start, open settings, or quit",
        },
        .pause => .{
            .title = "PAUSE SCREEN",
            .subtitle = "Resume, adjust settings, or return",
        },
        .settings => .{
            .title = "SETTINGS SCREEN",
            .subtitle = "Audio and theme options",
        },
    };
}

fn backgroundColor(state: State) [3]u8 {
    return theme_backgrounds[state.selected_theme];
}

pub fn frame(
    allocator: std.mem.Allocator,
    state: *State,
    widget_state: *ui.WidgetState,
    input: ui.InputState,
    options: struct {
        screen: struct { w: f32 = 960, h: f32 = 540 } = .{},
    },
) !FrameOutput {
    widget_state.beginFrame();

    const current_focus_items = focusItems(state.current_screen);
    if (input.nav_down) {
        ui.moveFocusLinear(widget_state, current_focus_items, .next);
    }
    if (input.nav_up) {
        ui.moveFocusLinear(widget_state, current_focus_items, .previous);
    }

    const count = buttonCount(state.current_screen);
    const layout = layoutForScreen(options.screen.w, options.screen.h, count);

    var builder = ui.Builder.init(allocator);
    defer builder.deinit();

    try builder.push(.{ .rect_filled = .{
        .rect = layout.panel_rect,
        .color = .{ .r = 0.09, .g = 0.10, .b = 0.14, .a = 0.92 },
        .radius = 10,
    } });
    try builder.push(.{ .rect_stroke = .{
        .rect = layout.panel_rect,
        .color = .{ .r = 0.77, .g = 0.82, .b = 0.92, .a = 0.45 },
        .thickness = 2,
        .radius = 10,
    } });

    const header = screenHeader(state.current_screen);
    const title_rect = ui.Rect{
        .x = layout.panel_rect.x,
        .y = layout.panel_rect.y + 22.0,
        .w = layout.panel_rect.w,
        .h = 28.0,
    };
    try core_widgets.label(&builder, title_rect, header.title, .{
        .size_px = 20,
        .color = .{ .r = 0.95, .g = 0.97, .b = 1.0, .a = 1.0 },
        .alignment = .center,
    });

    const subtitle_rect = core_widgets.spacer(title_rect, 34.0, .vertical);
    try core_widgets.label(&builder, .{
        .x = subtitle_rect.x,
        .y = subtitle_rect.y,
        .w = subtitle_rect.w,
        .h = 22.0,
    }, header.subtitle, .{
        .size_px = 16,
        .color = .{ .r = 0.82, .g = 0.86, .b = 0.94, .a = 1.0 },
        .alignment = .center,
    });

    const separator_rect = core_widgets.spacer(subtitle_rect, 30.0, .vertical);
    try core_widgets.separator(&builder, .{
        .x = layout.panel_rect.x + 32.0,
        .y = separator_rect.y,
        .w = layout.panel_rect.w - 64.0,
        .h = 8.0,
    }, .{});

    switch (state.current_screen) {
        .title => {
            const start = try core_widgets.button(&builder, widget_state, title_start_id, layout.button_rects[0], "Start Game", input, buttonStyle(.{ 66, 140, 196 }));
            if (start.pressed) {
                setScreen(state, widget_state, .pause);
            }

            const settings = try core_widgets.button(&builder, widget_state, title_settings_id, layout.button_rects[1], "Settings", input, buttonStyle(.{ 78, 156, 98 }));
            if (settings.pressed) {
                state.settings_return_screen = .title;
                setScreen(state, widget_state, .settings);
            }

            const quit = try core_widgets.button(&builder, widget_state, title_quit_id, layout.button_rects[2], "Quit", input, buttonStyle(.{ 154, 46, 58 }));
            if (quit.pressed) {
                state.running = false;
            }
        },
        .pause => {
            const resume_btn = try core_widgets.button(&builder, widget_state, pause_resume_id, layout.button_rects[0], "Resume", input, buttonStyle(.{ 66, 140, 196 }));
            if (resume_btn.pressed) {
                setScreen(state, widget_state, .title);
            }

            const settings_btn = try core_widgets.button(&builder, widget_state, pause_settings_id, layout.button_rects[1], "Settings", input, buttonStyle(.{ 78, 156, 98 }));
            if (settings_btn.pressed) {
                state.settings_return_screen = .pause;
                setScreen(state, widget_state, .settings);
            }

            const back_to_title_btn = try core_widgets.button(&builder, widget_state, pause_title_id, layout.button_rects[2], "Back To Title", input, buttonStyle(.{ 120, 118, 170 }));
            if (back_to_title_btn.pressed) {
                setScreen(state, widget_state, .title);
            }
        },
        .settings => {
            const music = try core_widgets.button(&builder, widget_state, settings_music_id, layout.button_rects[0], if (state.music_enabled) "Music: On" else "Music: Off", input, buttonStyle(.{ 76, 146, 198 }));
            if (music.pressed) {
                state.music_enabled = !state.music_enabled;
            }

            const sfx = try core_widgets.button(&builder, widget_state, settings_sfx_id, layout.button_rects[1], if (state.sfx_enabled) "SFX: On" else "SFX: Off", input, buttonStyle(.{ 86, 162, 120 }));
            if (sfx.pressed) {
                state.sfx_enabled = !state.sfx_enabled;
            }

            const theme = try core_widgets.button(&builder, widget_state, settings_theme_id, layout.button_rects[2], theme_setting_labels[state.selected_theme], input, buttonStyle(.{ 184, 128, 72 }));
            if (theme.pressed) {
                state.selected_theme = (state.selected_theme + 1) % theme_setting_labels.len;
            }

            const back = try core_widgets.button(&builder, widget_state, settings_back_id, layout.button_rects[3], "Back", input, buttonStyle(.{ 120, 118, 170 }));
            if (back.pressed) {
                setScreen(state, widget_state, state.settings_return_screen);
            }
        },
    }

    return .{
        .draw_list = try builder.finish(),
        .background_rgb = backgroundColor(state.*),
    };
}

test "title screen start button transitions to pause" {
    var state = State{};
    var widget_state = ui.WidgetState{};
    var input = ui.InputState.init();
    const layout = layoutForScreen(960, 540, 3);
    const start = layout.button_rects[0];

    input = ui.inputFromEvents(&.{ .{ .mouse_move = .{ .x = start.x + 20, .y = start.y + 20 } }, .mouse_button_down }, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
    }

    input = ui.inputFromEvents(&.{.mouse_button_up}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
        try std.testing.expectEqual(Screen.pause, state.current_screen);
    }
}

test "settings back returns to title when opened from title" {
    var state = State{};
    var widget_state = ui.WidgetState{};
    var input = ui.InputState.init();

    var step: usize = 0;
    while (step < 2) : (step += 1) {
        input = ui.inputFromEvents(&.{.{ .key_down = .down }}, input);
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
    }
    input = ui.inputFromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
        try std.testing.expectEqual(Screen.settings, state.current_screen);
        try std.testing.expectEqual(Screen.title, state.settings_return_screen);
    }

    var down_steps: usize = 0;
    while (down_steps < 4) : (down_steps += 1) {
        input = ui.inputFromEvents(&.{.{ .key_down = .down }}, input);
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
    }
    input = ui.inputFromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
        try std.testing.expectEqual(Screen.title, state.current_screen);
    }
}

test "settings toggles values and cycles theme" {
    var state = State{ .current_screen = .settings };
    var widget_state = ui.WidgetState{};
    widget_state.setFocus(settings_music_id);
    var input = ui.InputState.init();

    input = ui.inputFromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
        try std.testing.expect(!state.music_enabled);
    }

    input = ui.inputFromEvents(&.{.{ .key_down = .down }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
    }
    input = ui.inputFromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
        try std.testing.expect(!state.sfx_enabled);
    }

    input = ui.inputFromEvents(&.{.{ .key_down = .down }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
    }
    input = ui.inputFromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
        try std.testing.expectEqual(@as(usize, 1), state.selected_theme);
        try std.testing.expectEqual(theme_backgrounds[1], out.background_rgb);
    }
}

test "settings back returns to pause when opened from pause" {
    var state = State{ .current_screen = .pause };
    var widget_state = ui.WidgetState{};
    var input = ui.InputState.init();

    input = ui.inputFromEvents(&.{.{ .key_down = .down }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
    }

    input = ui.inputFromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
        try std.testing.expectEqual(Screen.settings, state.current_screen);
        try std.testing.expectEqual(Screen.pause, state.settings_return_screen);
    }

    var down_steps: usize = 0;
    while (down_steps < 4) : (down_steps += 1) {
        input = ui.inputFromEvents(&.{.{ .key_down = .down }}, input);
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
    }

    input = ui.inputFromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
        try std.testing.expectEqual(Screen.pause, state.current_screen);
    }
}

test "quit button stops demo running state" {
    var state = State{};
    var widget_state = ui.WidgetState{};
    var input = ui.InputState.init();

    var step: usize = 0;
    while (step < 3) : (step += 1) {
        input = ui.inputFromEvents(&.{.{ .key_down = .down }}, input);
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
    }

    input = ui.inputFromEvents(&.{.{ .key_down = .enter }}, input);
    {
        const out = try frame(std.testing.allocator, &state, &widget_state, input, .{});
        defer std.testing.allocator.free(out.draw_list.ops);
        try out.draw_list.validateContract();
        try std.testing.expect(!state.running);
    }
}
