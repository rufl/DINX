const std = @import("std");

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;

pub fn isDisabled() bool {
    const live_session = getenv("DINX_LIVE_SESSION") orelse return false;
    return disabledFor(std.mem.span(live_session));
}

pub fn disabledFor(live_session: ?[]const u8) bool {
    return if (live_session) |value| std.mem.eql(u8, value, "1") else false;
}

test "only the live-session marker disables locking" {
    try std.testing.expect(disabledFor("1"));
    try std.testing.expect(!disabledFor("0"));
    try std.testing.expect(!disabledFor("true"));
    try std.testing.expect(!disabledFor(null));
}
