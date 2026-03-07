const std = @import("std");

pub const Utf8Iterator = struct {
    bytes: []const u8,
    index: usize = 0,

    pub fn init(bytes: []const u8) Utf8Iterator {
        return .{ .bytes = bytes };
    }

    pub fn nextCodepoint(self: *Utf8Iterator) !?u21 {
        if (self.index >= self.bytes.len) return null;

        const b0 = self.bytes[self.index];
        var len: usize = 0;
        var cp: u32 = 0;

        if ((b0 & 0x80) == 0) {
            len = 1;
            cp = b0;
        } else if ((b0 & 0xE0) == 0xC0) {
            len = 2;
            cp = b0 & 0x1F;
        } else if ((b0 & 0xF0) == 0xE0) {
            len = 3;
            cp = b0 & 0x0F;
        } else if ((b0 & 0xF8) == 0xF0) {
            len = 4;
            cp = b0 & 0x07;
        } else {
            return error.InvalidUtf8;
        }

        if (self.index + len > self.bytes.len) return error.InvalidUtf8;

        var i: usize = 1;
        while (i < len) : (i += 1) {
            const bx = self.bytes[self.index + i];
            if ((bx & 0xC0) != 0x80) return error.InvalidUtf8;
            cp = (cp << 6) | (bx & 0x3F);
        }

        self.index += len;
        return @intCast(cp);
    }
};

test "Utf8Iterator decodes ASCII and multibyte" {
    var it = Utf8Iterator.init("A\xC3\xA9");
    try std.testing.expectEqual(@as(?u21, 'A'), try it.nextCodepoint());
    try std.testing.expectEqual(@as(?u21, 0xE9), try it.nextCodepoint());
    try std.testing.expectEqual(@as(?u21, null), try it.nextCodepoint());
}

test "Utf8Iterator rejects invalid continuation" {
    var it = Utf8Iterator.init("\xC3\x41");
    try std.testing.expectError(error.InvalidUtf8, it.nextCodepoint());
}
