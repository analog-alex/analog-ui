pub const Id = @import("core/ids.zig").Id;
pub const InputState = @import("core/input.zig").InputState;
pub const DrawList = @import("core/draw_list.zig").DrawList;
pub const Rect = @import("core/draw_list.zig").Rect;
pub const Builder = @import("core/draw_list.zig").Builder;
pub const Context = @import("core/context.zig").Context;
pub const Theme = @import("core/theme.zig").Theme;
pub const Font = @import("font/font.zig").Font;
pub const WidgetState = @import("core/widgets.zig").WidgetState;
pub const button = @import("core/widgets.zig").button;
pub const SdlEvent = @import("platform/sdl_events.zig").Event;
pub const inputFromEvents = @import("platform/sdl_events.zig").fromEvents;
pub const inputFromSdlEvents = @import("platform/sdl_events.zig").fromSdlEvents;
pub const RendererBackend = @import("backend/sdl_renderer.zig").RendererBackend;
pub const GpuBackend = @import("backend/sdl_gpu.zig").GpuBackend;
pub const sdl = @import("backend/sdl_shared.zig");
pub const version = @import("version.zig").version;

test "root exports are available" {
    const std = @import("std");
    try std.testing.expect(@sizeOf(Id) == @sizeOf(u64));
}
