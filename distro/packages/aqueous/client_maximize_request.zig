// SPDX-FileCopyrightText: © 2026 Seafoam Labs
// SPDX-License-Identifier: GPL-3.0-only

const std = @import("std");

/// Do not consume an initial maximize request until its window has a workspace.
/// Aqueous assigns new windows during the manage cycle after requests are read.
pub fn isReady(request: anytype, workspace_assigned: bool) bool {
    return workspace_assigned and request != .no_request;
}

/// Return and clear a ready request; otherwise preserve it for the next manage cycle.
pub fn take(request: anytype, workspace_assigned: bool) ?@TypeOf(request.*) {
    if (!isReady(request.*, workspace_assigned)) return null;
    const action = request.*;
    request.* = .no_request;
    return action;
}

test "client maximize survives initial workspace assignment" {
    const Store = @import("state/store.zig");
    const types = @import("layout/types.zig");
    const Resolver = struct {
        var entry: Store.Entry = .{};

        fn reset() void {
            entry = .{};
        }

        fn resolve(handle: types.Handle) ?*Store.Entry {
            if (handle != 1) return null;
            return &entry;
        }
    };

    const Request = enum { no_request, maximize, unmaximize };
    Resolver.reset();
    var store = Store.init(std.testing.allocator, Resolver.resolve);
    defer store.deinit();

    var request: Request = .maximize;
    try std.testing.expect(!isReady(request, false));
    try std.testing.expectEqual(@as(?Request, null), take(&request, false));
    try std.testing.expectEqual(Request.maximize, request);
    try std.testing.expectEqual(Store.Kind.tiled, Resolver.entry.kind());

    const action = take(&request, true);
    try std.testing.expectEqual(@as(?Request, Request.maximize), action);
    if (action) |pending| switch (pending) {
        .maximize => try std.testing.expect(store.setClientMaximized(1, true, true)),
        .unmaximize => unreachable,
        .no_request => unreachable,
    };
    try std.testing.expectEqual(Request.no_request, request);
    try std.testing.expectEqual(Store.Kind.maximized, Resolver.entry.kind());
}
