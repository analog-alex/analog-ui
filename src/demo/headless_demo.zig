const std = @import("std");
const ui = @import("analog_ui");

pub fn run() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    widget_state.beginFrame();
    _ = ui.button(&widget_state, play_id, true, input);

    const frame_2 = [_]ui.SdlEvent{.mouse_button_up};
    input = ui.inputFromEvents(&frame_2, input);
    widget_state.beginFrame();
    const pressed = ui.button(&widget_state, play_id, true, input);
    std.debug.print("button pressed: {}\n", .{pressed});

    const fake_ttf = "not-a-real-ttf";
    var fonts = ui.FontRegistry.init(alloc);
    defer fonts.deinit();

    const body = try fonts.addTtf("Body", .{
        .ttf_bytes = fake_ttf,
        .base_px = 16,
        .charset = .ascii,
        .dynamic_glyphs = false,
    });
    const fallback = try fonts.addTtf("Fallback", .{
        .ttf_bytes = fake_ttf,
        .base_px = 16,
        .charset = .latin_1,
        .dynamic_glyphs = false,
    });
    try fonts.setFallback(body, &.{fallback});

    const measured = try ui.Text.measure(&fonts, body, "Play\nQuit");
    const wrapped = try ui.Text.wrap(alloc, &fonts, body, "Play Settings Quit", 70.0);
    defer alloc.free(wrapped);
    const truncated = try ui.Text.truncateWithEllipsis(alloc, &fonts, body, "Very Long Settings Menu", 90.0, "...");
    defer alloc.free(truncated);

    std.debug.print("text size: {d:.1} x {d:.1}\n", .{ measured.width, measured.height });
    std.debug.print("wrapped lines: {d} truncated: {s}\n", .{ wrapped.len, truncated });
}
