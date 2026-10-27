const std = @import("std");
const unitname = @import("../helpers/unitname.zig");
const sysutil = @import("../helpers/sysutil.zig");

pub const OpResult = struct {
    ok: bool,
    cancelled: bool,
    output: []const u8,
    err: []const u8,
    exit_code: i32,
};

fn fromExec(res: sysutil.ExecResult) OpResult {
    return .{
        .ok = res.exit_code == 0,
        .cancelled = res.exit_code == 126,
        .output = res.output,
        .err = res.err,
        .exit_code = res.exit_code,
    };
}

pub fn runPrivileged(arena: std.mem.Allocator, argv: []const []const u8) !OpResult {
    var full = try arena.alloc([]const u8, argv.len + 1);
    full[0] = "/usr/bin/pkexec";
    @memcpy(full[1..], argv);
    return fromExec(try sysutil.runCommand(arena, full));
}

fn shQuote(arena: std.mem.Allocator, s: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.append(arena, '\'');
    for (s) |c| {
        if (c == '\'') {
            try out.appendSlice(arena, "'\\''");
        } else {
            try out.append(arena, c);
        }
    }
    try out.append(arena, '\'');
    return out.items;
}

fn dinitToken(arena: std.mem.Allocator, value: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.append(arena, '"');
    for (value) |c| {
        if (c == '\\' or c == '"') try out.append(arena, '\\');
        try out.append(arena, c);
    }
    try out.append(arena, '"');
    return out.items;
}

fn singleLine(arena: std.mem.Allocator, value: []const u8) ![]const u8 {
    if (std.mem.indexOfAny(u8, value, "\r\n") == null) return value;
    var out: std.ArrayList(u8) = .empty;
    for (value) |c| try out.append(arena, if (c == '\r' or c == '\n') ' ' else c);
    return out.items;
}

fn normalizeMountPoint(arena: std.mem.Allocator, mount_point: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, mount_point, "/")) return mount_point;
    return std.fmt.allocPrint(arena, "/{s}", .{mount_point});
}

fn normalizeFsType(fs_type: []const u8) []const u8 {
    // UDisks2 reports NTFS as "ntfs". The in-kernel ntfs3 driver is the
    // DINX default and keeps read/write support available without ntfs-3g.
    if (std.ascii.eqlIgnoreCase(fs_type, "ntfs")) return "ntfs3";
    return if (fs_type.len > 0) fs_type else "auto";
}

fn validateUnitName(name: []const u8) !void {
    if (name.len == 0 or
        std.mem.indexOfAny(u8, name, "/\r\n") != null or
        std.mem.eql(u8, name, ".") or
        std.mem.eql(u8, name, "..")) return error.InvalidUnitName;
}

fn servicePath(arena: std.mem.Allocator, unit: []const u8) ![]const u8 {
    try validateUnitName(unit);
    return std.fmt.allocPrint(arena, "/etc/dinit.d/{s}", .{unit});
}

fn buildServiceContent(
    arena: std.mem.Allocator,
    description: []const u8,
    what: []const u8,
    mount_point: []const u8,
    fs_type: []const u8,
    options: []const u8,
) ![]const u8 {
    const path = try normalizeMountPoint(arena, mount_point);
    const effective_type = normalizeFsType(fs_type);
    const description_line = try singleLine(arena, description);
    const options_line = try singleLine(arena, options);
    const type_token = try dinitToken(arena, effective_type);
    const what_token = try dinitToken(arena, what);
    const path_token = try dinitToken(arena, path);
    const options_token = try dinitToken(arena, options_line);
    const command = try std.fmt.allocPrint(
        arena,
        "/usr/local/libexec/pori-mount-service {s} {s} {s} {s}",
        .{ what_token, path_token, type_token, options_token },
    );

    return std.fmt.allocPrint(arena,
        \\# Managed by Pori for DINX (dinit).
        \\# Pori-Description: {s}
        \\# Pori-What: {s}
        \\# Pori-Where: {s}
        \\# Pori-Type: {s}
        \\# Pori-Options: {s}
        \\type = process
        \\command = {s}
        \\restart = true
        \\restart-delay = 5
        \\restart-limit-count = 0
        \\depends-on = local.target
        \\
    , .{ description_line, what, path, effective_type, options_line, command });
}

var temp_counter: std.atomic.Value(u64) = std.atomic.Value(u64).init(0);

fn writeTempFile(arena: std.mem.Allocator, content: []const u8) ![]const u8 {
    const n = temp_counter.fetchAdd(1, .monotonic);
    const name = try std.fmt.allocPrint(arena, "/tmp/pori-{d}-{d}.dinit.tmp", .{ std.os.linux.getpid(), n });
    sysutil.writeFile(name, content) catch return error.TempFileFailed;
    return name;
}

fn readMountSource(arena: std.mem.Allocator, unit: []const u8) ![]const u8 {
    const path = try servicePath(arena, unit);
    const content = sysutil.readFileAlloc(arena, path) orelse return error.MissingMountUnit;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        const prefix = "# Pori-What:";
        if (std.mem.startsWith(u8, line, prefix)) {
            return std.mem.trim(u8, line[prefix.len..], " \t\r");
        }
    }
    return error.MissingMountSource;
}

fn privilegedScript(arena: std.mem.Allocator, script: []const u8) !OpResult {
    return runPrivileged(arena, &.{ "/usr/bin/sh", "-c", script });
}

fn buildInstallScript(
    arena: std.mem.Allocator,
    tmp: []const u8,
    old_unit: []const u8,
    new_unit: []const u8,
    remove_old: bool,
) ![]const u8 {
    const tmp_q = try shQuote(arena, tmp);
    const old_q = try shQuote(arena, old_unit);
    const new_q = try shQuote(arena, new_unit);
    const old_path = try servicePath(arena, old_unit);
    const new_path = try servicePath(arena, new_unit);
    const old_path_q = try shQuote(arena, old_path);
    const new_path_q = try shQuote(arena, new_path);
    const remove_old_line = if (remove_old)
        try std.fmt.allocPrint(arena, "/usr/bin/rm -f {s}\n", .{old_path_q})
    else
        "";

    return std.fmt.allocPrint(arena,
        \\set -e
        \\/usr/bin/dinitctl --system stop --ignore-unstarted {s} || true
        \\/usr/bin/dinitctl --system disable {s} || true
        \\/usr/bin/dinitctl --system unload {s} || true
        \\{s}
        \\/usr/bin/install -Dm644 {s} {s}
        \\/usr/bin/dinitctl --system enable {s}
        \\/usr/bin/dinitctl --system start {s}
        \\
    , .{ old_q, old_q, old_q, remove_old_line, tmp_q, new_path_q, new_q, new_q });
}

pub fn createMountUnit(arena: std.mem.Allocator, description: []const u8, uuid: []const u8, mount_point: []const u8, fs_type: []const u8, options: []const u8) !OpResult {
    const unit = try unitname.fromMountPoint(arena, mount_point);
    const what = try std.fmt.allocPrint(arena, "/dev/disk/by-uuid/{s}", .{uuid});
    const content = try buildServiceContent(arena, description, what, mount_point, fs_type, options);
    const tmp = try writeTempFile(arena, content);
    defer sysutil.deleteFile(tmp);
    const script = try buildInstallScript(arena, tmp, unit, unit, false);
    return privilegedScript(arena, script);
}

pub fn editMountUnit(arena: std.mem.Allocator, old_unit: []const u8, description: []const u8, mount_point: []const u8, fs_type: []const u8, options: []const u8) !OpResult {
    try validateUnitName(old_unit);
    const what = try readMountSource(arena, old_unit);
    const new_unit = try unitname.fromMountPoint(arena, mount_point);
    const content = try buildServiceContent(arena, description, what, mount_point, fs_type, options);
    const tmp = try writeTempFile(arena, content);
    defer sysutil.deleteFile(tmp);
    const script = try buildInstallScript(
        arena,
        tmp,
        old_unit,
        new_unit,
        !std.mem.eql(u8, old_unit, new_unit),
    );
    return privilegedScript(arena, script);
}

pub fn deleteMountUnit(arena: std.mem.Allocator, unit: []const u8) !OpResult {
    const path = try servicePath(arena, unit);
    const unit_q = try shQuote(arena, unit);
    const path_q = try shQuote(arena, path);
    const script = try std.fmt.allocPrint(arena,
        \\set -e
        \\/usr/bin/dinitctl --system stop --ignore-unstarted {s} || true
        \\/usr/bin/dinitctl --system disable {s} || true
        \\/usr/bin/dinitctl --system unload {s} || true
        \\/usr/bin/rm -f {s}
        \\
    , .{ unit_q, unit_q, unit_q, path_q });
    return privilegedScript(arena, script);
}

test "shQuote escapes single quotes" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const quoted = try shQuote(arena.allocator(), "it's a trap");
    try std.testing.expectEqualStrings("'it'\\''s a trap'", quoted);
}

test "dinit content maps NTFS to the supervised kernel driver" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const content = try buildServiceContent(arena.allocator(), "Games", "/dev/disk/by-uuid/abcd-1234", "mnt/games", "ntfs", "defaults,noatime");
    try std.testing.expect(std.mem.indexOf(u8, content, "type = process") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "pori-mount-service") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "ntfs3") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "restart = true") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "restart-delay = 5") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "restart-limit-count = 0") != null);
}

test "dinit tokens preserve spaces and backslashes" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const token = try dinitToken(arena.allocator(), "/mnt/New Volume\\Games");
    try std.testing.expectEqualStrings("\"/mnt/New Volume\\\\Games\"", token);
}
