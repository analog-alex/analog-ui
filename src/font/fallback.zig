const std = @import("std");

pub const FallbackChain = struct {
    font_indices: []u16,

    pub fn first(self: FallbackChain) ?u16 {
        if (self.font_indices.len == 0) return null;
        return self.font_indices[0];
    }
};

test "FallbackChain first returns null on empty" {
    const chain = FallbackChain{ .font_indices = &.{} };
    try std.testing.expect(chain.first() == null);
}
