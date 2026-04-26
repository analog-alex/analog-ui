const ScaleState = @import("../core/scale.zig").ScaleState;

pub const RenderOptions = struct {
    scale: ScaleState = .{},
    font_atlas_scale: ?f32 = null,
};
