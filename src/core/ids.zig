const std = @import("std");

pub const Id = packed struct(u64) {
    value: u64,

    pub fn fromStr(str: []const u8) Id {
        // 64-bit FNV-1a for stable deterministic IDs.
        var hash: u64 = 14695981039346656037;
        for (str) |c| {
            hash ^= c;
            hash *%= 1099511628211;
        }
        return .{ .value = hash };
    }

    pub fn fromStrWithOffset(str: []const u8, offset: u32) Id {
        var id = fromStr(str);
        id.value +%= offset;
        return id;
    }

    pub fn withOffset(self: Id, offset: u32) Id {
        return .{ .value = self.value +% offset };
    }
};

test "Id hashing" {
    const id1 = Id.fromStr("test");
    const id2 = Id.fromStr("test");
    try std.testing.expectEqual(id1.value, id2.value);

    const id3 = Id.fromStr("different");
    try std.testing.expect(id1.value != id3.value);
}

test "Id with offset" {
    const id1 = Id.fromStr("base");
    const id2 = id1.withOffset(5);
    try std.testing.expect(id1.value != id2.value);
}
