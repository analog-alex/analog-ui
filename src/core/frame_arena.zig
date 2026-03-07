const std = @import("std");

pub const FrameArena = struct {
    buffer: []u8,
    cursor: usize,

    pub fn init(buffer: []u8) FrameArena {
        return .{ .buffer = buffer, .cursor = 0 };
    }

    pub fn reset(self: *FrameArena) void {
        self.cursor = 0;
    }

    pub fn alloc(self: *FrameArena, comptime T: type, count: usize) ![]T {
        const alignment = @alignOf(T);
        const bytes = @sizeOf(T) * count;
        const aligned = std.mem.alignForward(usize, self.cursor, alignment);
        const end = aligned + bytes;
        if (end > self.buffer.len) return error.FrameArenaExhausted;
        self.cursor = end;
        return @as([*]T, @ptrCast(@alignCast(self.buffer.ptr + aligned)))[0..count];
    }
};

test "FrameArena alloc and reset" {
    var storage: [64]u8 = undefined;
    var arena = FrameArena.init(&storage);

    const a = try arena.alloc(u32, 4);
    a[0] = 1;
    try std.testing.expectEqual(@as(usize, 16), arena.cursor);

    arena.reset();
    try std.testing.expectEqual(@as(usize, 0), arena.cursor);
}
