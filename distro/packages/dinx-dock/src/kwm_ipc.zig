// SPDX-FileCopyrightText: 2026 DINX Contributors
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");

const max_windows = 64;
const text_limit = 512;
const response_limit = 70 * 1024;
const sockaddr_un = extern struct { family: u16, path: [108]u8 };

extern "c" fn socket(domain: c_int, socket_type: c_int, protocol: c_int) c_int;
extern "c" fn connect(fd: c_int, address: *const sockaddr_un, length: u32) c_int;
extern "c" fn send(fd: c_int, buffer: [*]const u8, length: usize, flags: c_int) isize;
extern "c" fn recv(fd: c_int, buffer: [*]u8, length: usize, flags: c_int) isize;
extern "c" fn close(fd: c_int) c_int;

pub const Window = struct {
    id: u64,
    focused: bool,
    app_id: [text_limit]u8,
    app_id_len: usize,
    title: [text_limit]u8,
    title_len: usize,

    pub fn appId(self: *const Window) []const u8 {
        return self.app_id[0..self.app_id_len];
    }

    pub fn titleText(self: *const Window) []const u8 {
        return self.title[0..self.title_len];
    }
};

pub const Snapshot = struct {
    session_id: u64 = 0,
    windows: [max_windows]Window = undefined,
    count: usize = 0,

};

pub fn query(path: [:0]const u8) !Snapshot {
    const fd = try connectSocket(path);
    defer _ = close(fd);
    try sendPacket(fd, "LIST");

    var buffer: [response_limit]u8 = undefined;
    const count = recv(fd, &buffer, buffer.len, 0);
    if (count <= 0) return error.EmptyResponse;
    return parseSnapshot(buffer[0..@intCast(count)]);
}

pub fn focus(path: [:0]const u8, session_id: u64, window_id: u64) !void {
    try command(path, "FOCUS", session_id, window_id);
}

pub fn closeWindow(path: [:0]const u8, session_id: u64, window_id: u64) !void {
    try command(path, "CLOSE", session_id, window_id);
}

fn command(path: [:0]const u8, operation: []const u8, session_id: u64, window_id: u64) !void {
    const fd = try connectSocket(path);
    defer _ = close(fd);
    var request: [96]u8 = undefined;
    const request_text = try std.fmt.bufPrint(&request, "{s} {x} {x}", .{ operation, session_id, window_id });
    try sendPacket(fd, request_text);

    var response: [64]u8 = undefined;
    const count = recv(fd, &response, response.len, 0);
    if (count <= 0) return error.EmptyResponse;
    if (!std.mem.startsWith(u8, response[0..@intCast(count)], "OK\n")) return error.ActionRejected;
}

fn connectSocket(path: [:0]const u8) !c_int {
    const fd = socket(1, 5, 0); // AF_UNIX, SOCK_SEQPACKET
    if (fd < 0) return error.SocketCreateFailed;
    errdefer _ = close(fd);

    var address = sockaddr_un{ .family = 1, .path = std.mem.zeroes([108]u8) };
    if (path.len >= address.path.len) return error.SocketPathTooLong;
    @memcpy(address.path[0..path.len], path);
    if (connect(fd, &address, @sizeOf(sockaddr_un)) != 0) return error.SocketUnavailable;
    return fd;
}

fn sendPacket(fd: c_int, bytes: []const u8) !void {
    const count = send(fd, bytes.ptr, bytes.len, 0x4000); // MSG_NOSIGNAL
    if (count < 0 or @as(usize, @intCast(count)) != bytes.len) return error.SendFailed;
}

fn parseSnapshot(bytes: []const u8) !Snapshot {
    var snapshot = Snapshot{ .session_id = 0, .windows = undefined, .count = 0 };
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    const header = lines.next() orelse return error.InvalidResponse;
    var header_fields = std.mem.tokenizeScalar(u8, header, ' ');
    if (!std.mem.eql(u8, header_fields.next() orelse return error.InvalidResponse, "DINXKW/1"))
        return error.UnsupportedVersion;
    snapshot.session_id = std.fmt.parseInt(u64, header_fields.next() orelse return error.InvalidResponse, 16) catch return error.InvalidResponse;
    if (header_fields.next() != null or snapshot.session_id == 0) return error.InvalidResponse;

    var found_end = false;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "END ")) {
            const declared = std.fmt.parseInt(usize, line[4..], 10) catch return error.InvalidResponse;
            if (declared != snapshot.count) return error.InvalidResponse;
            found_end = true;
            break;
        }
        if (snapshot.count == snapshot.windows.len) return error.TooManyWindows;

        var fields = std.mem.tokenizeScalar(u8, line, ' ');
        if (!std.mem.eql(u8, fields.next() orelse return error.InvalidResponse, "W")) return error.InvalidResponse;
        const id = std.fmt.parseInt(u64, fields.next() orelse return error.InvalidResponse, 16) catch return error.InvalidResponse;
        const focused = fields.next() orelse return error.InvalidResponse;
        if (id == 0 or (!std.mem.eql(u8, focused, "0") and !std.mem.eql(u8, focused, "1"))) return error.InvalidResponse;
        const app_hex = fields.next() orelse return error.InvalidResponse;
        const title_hex = fields.next() orelse return error.InvalidResponse;
        if (fields.next() != null) return error.InvalidResponse;

        var window = Window{ .id = id, .focused = std.mem.eql(u8, focused, "1"), .app_id = undefined, .app_id_len = 0, .title = undefined, .title_len = 0 };
        window.app_id_len = try decodeHex(app_hex, &window.app_id);
        window.title_len = try decodeHex(title_hex, &window.title);
        snapshot.windows[snapshot.count] = window;
        snapshot.count += 1;
    }
    if (!found_end) return error.InvalidResponse;
    return snapshot;
}

fn decodeHex(encoded: []const u8, output: *[text_limit]u8) !usize {
    if (std.mem.eql(u8, encoded, "-")) return 0;
    if (encoded.len % 2 != 0 or encoded.len / 2 > output.len) return error.InvalidResponse;
    for (0..encoded.len / 2) |index| {
        const high = std.fmt.charToDigit(encoded[index * 2], 16) catch return error.InvalidResponse;
        const low = std.fmt.charToDigit(encoded[index * 2 + 1], 16) catch return error.InvalidResponse;
        output[index] = (high << 4) | low;
    }
    return encoded.len / 2;
}

test "parse versioned window snapshots and reject malformed records" {
    const snapshot = try parseSnapshot("DINXKW/1 2a\nW 1 1 617070 -\nEND 1\n");
    try std.testing.expectEqual(@as(u64, 42), snapshot.session_id);
    try std.testing.expectEqual(@as(usize, 1), snapshot.count);
    try std.testing.expect(snapshot.windows[0].focused);
    try std.testing.expectEqualStrings("app", snapshot.windows[0].appId());
    try std.testing.expectEqualStrings("", snapshot.windows[0].titleText());
    const unknown_app = try parseSnapshot("DINXKW/1 2b\nW 2 0 - 7469746c65\nEND 1\n");
    try std.testing.expectEqualStrings("", unknown_app.windows[0].appId());
    try std.testing.expectEqualStrings("title", unknown_app.windows[0].titleText());
    try std.testing.expectError(error.InvalidResponse, parseSnapshot("DINXKW/1 2a\nW 1 1 61\nEND 1\n"));
    try std.testing.expectError(error.InvalidResponse, parseSnapshot("DINXKW/1 2a\nW 1 1 61 -\nEND 2\n"));
}
