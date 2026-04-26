const std = @import("std");

pub const min_ui_scale: f32 = 0.5;
pub const max_ui_scale: f32 = 3.0;

pub const ScaleState = struct {
    dpi_scale: f32 = 1.0,
    user_scale: f32 = 1.0,
    app_scale: f32 = 1.0,

    pub fn effective(self: ScaleState) f32 {
        return sanitizeScale(self.dpi_scale) * clampUiScale(self.user_scale) * sanitizeScale(self.app_scale);
    }
};

pub fn sanitizeScale(scale: f32) f32 {
    if (std.math.isFinite(scale) and scale > 0.0) {
        return scale;
    }
    return 1.0;
}

pub fn clampUiScale(scale: f32) f32 {
    if (!std.math.isFinite(scale)) return 1.0;
    return std.math.clamp(scale, min_ui_scale, max_ui_scale);
}

test "ScaleState effective combines dpi user and app" {
    const state = ScaleState{
        .dpi_scale = 2.0,
        .user_scale = 1.25,
        .app_scale = 0.8,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), state.effective(), 0.0001);
}

test "clampUiScale clamps invalid values" {
    try std.testing.expectEqual(@as(f32, 1.0), clampUiScale(std.math.inf(f32)));
    try std.testing.expectEqual(min_ui_scale, clampUiScale(0.01));
    try std.testing.expectEqual(max_ui_scale, clampUiScale(8.0));
}
