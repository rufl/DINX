const std = @import("std");
const sysutil = @import("../helpers/sysutil.zig");
const devices = @import("devices.zig");

pub const MountUnit = struct {
    name: []const u8,
    description: []const u8,
    load_state: []const u8,
    active_state: []const u8,
    sub_state: []const u8,
    what: []const u8,
    where: []const u8,
    options: []const u8,
    fs_type: []const u8,
    unit_file_state: []const u8,

    pub fn statusText(self: MountUnit) []const u8 {
        if (self.active_state.len == 0) return "unknown";
        return self.active_state;
    }

    pub fn isActive(self: MountUnit) bool {
        return std.mem.eql(u8, self.active_state, "active");
    }

    pub fn matchesDevice(self: MountUnit, dev: devices.Device) bool {
        if (self.what.len > 0) {
            var suffix: [160]u8 = undefined;
            if (std.fmt.bufPrint(&suffix, "/by-uuid/{s}", .{dev.uuid})) |s| {
                if (endsWithIgnoreCase(self.what, s)) return true;
            } else |_| {}
            if (std.mem.eql(u8, std.fs.path.basename(self.what), std.fs.path.basename(dev.dev))) return true;
        }
        if (self.where.len > 0) {
            for (dev.mount_points) |mp| {
                if (std.mem.eql(u8, mp, self.where)) return true;
            }
        }
        return false;
    }
};

fn endsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    return std.ascii.eqlIgnoreCase(haystack[haystack.len - needle.len ..], needle);
}

const unit_dir = "/etc/dinit.d";

fn commentValue(arena: std.mem.Allocator, line: []const u8, prefix: []const u8) !?[]const u8 {
    if (!std.mem.startsWith(u8, line, prefix)) return null;
    return try arena.dupe(u8, std.mem.trim(u8, line[prefix.len..], " \t\r"));
}

fn encodeMountPath(path: []const u8, out: []u8) ?[]const u8 {
    var len: usize = 0;
    for (path) |c| {
        const replacement: []const u8 = switch (c) {
            ' ' => "\\040",
            '\t' => "\\011",
            '\\' => "\\134",
            else => "",
        };
        if (replacement.len > 0) {
            if (len + replacement.len > out.len) return null;
            @memcpy(out[len .. len + replacement.len], replacement);
            len += replacement.len;
        } else {
            if (len == out.len) return null;
            out[len] = c;
            len += 1;
        }
    }
    return out[0..len];
}

fn isMounted(arena: std.mem.Allocator, where: []const u8) bool {
    if (where.len == 0) return false;
    const mountinfo = sysutil.readFileAlloc(arena, "/proc/self/mountinfo") orelse return false;
    var encoded: [std.posix.PATH_MAX]u8 = undefined;
    const encoded_where = encodeMountPath(where, &encoded) orelse return false;

    var lines = std.mem.splitScalar(u8, mountinfo, '\n');
    while (lines.next()) |line| {
        const separator = std.mem.indexOf(u8, line, " - ") orelse continue;
        var fields = std.mem.splitScalar(u8, line[0..separator], ' ');
        var field_index: usize = 0;
        while (fields.next()) |field| {
            if (field.len == 0) continue;
            if (field_index == 4) {
                if (std.mem.eql(u8, field, encoded_where)) return true;
                break;
            }
            field_index += 1;
        }
    }
    return false;
}

fn refreshState(arena: std.mem.Allocator, unit: *MountUnit) void {
    if (isMounted(arena, unit.where)) {
        unit.active_state = "active";
        unit.sub_state = "mounted";
    } else {
        unit.active_state = "inactive";
        unit.sub_state = "dead";
    }
    // Pori only lists files in /etc/dinit.d and enables them through dinitctl.
    unit.unit_file_state = "enabled";
}

pub fn listLoadedMountUnits(arena: std.mem.Allocator) ![]MountUnit {
    return listManaged(arena);
}

pub fn getUnit(arena: std.mem.Allocator, name: []const u8) !?MountUnit {
    const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ unit_dir, name });
    const content = sysutil.readFileAlloc(arena, path) orelse return null;
    var unit = try parseUnitFile(arena, name, content);
    refreshState(arena, &unit);
    return unit;
}

pub fn listEtcMountUnits(arena: std.mem.Allocator) ![][]const u8 {
    const entries = try sysutil.listDir(arena, unit_dir);
    var out: std.ArrayList([]const u8) = .empty;
    for (entries) |name| {
        if (!std.mem.endsWith(u8, name, ".mount")) continue;
        try out.append(arena, name);
    }
    std.mem.sort([]const u8, out.items, {}, sliceLessThan);
    return out.items;
}

pub fn listManaged(arena: std.mem.Allocator) ![]MountUnit {
    const names = try listEtcMountUnits(arena);
    var out: std.ArrayList(MountUnit) = .empty;
    for (names) |name| {
        if (try unitInfo(arena, name)) |unit| {
            // Ignore unrelated dinit services that happen to use a .mount suffix.
            if (unit.what.len == 0 or unit.where.len == 0) continue;
            try out.append(arena, unit);
        }
    }
    return out.items;
}

fn sliceLessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

pub fn parseUnitFile(arena: std.mem.Allocator, name: []const u8, content: []const u8) !MountUnit {
    var unit = MountUnit{
        .name = try arena.dupe(u8, name),
        .description = "",
        .load_state = "loaded",
        .active_state = "inactive",
        .sub_state = "dead",
        .what = "",
        .where = "",
        .options = "",
        .fs_type = "",
        .unit_file_state = "enabled",
    };

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '[' or line[0] == ';') continue;
        if (line[0] == '#') {
            if (try commentValue(arena, line, "# Pori-Description:")) |value| {
                unit.description = value;
            } else if (try commentValue(arena, line, "# Pori-What:")) |value| {
                unit.what = value;
            } else if (try commentValue(arena, line, "# Pori-Where:")) |value| {
                unit.where = value;
            } else if (try commentValue(arena, line, "# Pori-Type:")) |value| {
                unit.fs_type = value;
            } else if (try commentValue(arena, line, "# Pori-Options:")) |value| {
                unit.options = value;
            }
            continue;
        }
    }
    return unit;
}

pub fn unitInfo(arena: std.mem.Allocator, name: []const u8) !?MountUnit {
    return getUnit(arena, name);
}

pub fn unitFilePath(arena: std.mem.Allocator, unit_name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "{s}/{s}", .{ unit_dir, unit_name });
}

test "matchesDevice accepts by-uuid, device node and mount point spellings" {
    const dev = devices.Device{
        .name = "sda1",
        .path = "/org/freedesktop/UDisks2/block_devices/sda1",
        .dev = "/dev/sda1",
        .fs_type = "ext4",
        .fs_version = "",
        .label = "Games",
        .uuid = "1a2b-3c4d",
        .size = 0,
        .read_only = false,
        .mount_points = &.{"/home/caro/mnt/games"},
        .parent = "sda",
        .parent_size = 0,
        .table_type = "gpt",
        .partition_number = 1,
        .partition_count = 2,
    };
    const base = MountUnit{
        .name = "home-caro-mnt-games.mount",
        .description = "",
        .load_state = "",
        .active_state = "active",
        .sub_state = "",
        .what = "",
        .where = "",
        .options = "",
        .fs_type = "",
        .unit_file_state = "",
    };

    var u = base;
    u.what = "/dev/disk/by-uuid/1A2B-3C4D";
    try std.testing.expect(u.matchesDevice(dev));

    u.what = "/dev/sda1";
    try std.testing.expect(u.matchesDevice(dev));

    u.what = "";
    u.where = "/home/caro/mnt/games";
    try std.testing.expect(u.matchesDevice(dev));

    u.what = "/dev/disk/by-uuid/ffff-0000";
    u.where = "/mnt/other";
    try std.testing.expect(!u.matchesDevice(dev));
}

test "parseUnitFile reads Pori dinit metadata" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const unit = try parseUnitFile(arena.allocator(), "mnt-games.mount", "# Pori-Description: Games\n" ++
        "# Pori-What: /dev/disk/by-uuid/abcd\n" ++
        "# Pori-Where: /mnt/games\n" ++
        "# Pori-Type: btrfs\n" ++
        "# Pori-Options: defaults,noatime\n" ++
        "type = scripted\n");
    try std.testing.expectEqualStrings("Games", unit.description);
    try std.testing.expectEqualStrings("/dev/disk/by-uuid/abcd", unit.what);
    try std.testing.expectEqualStrings("/mnt/games", unit.where);
    try std.testing.expectEqualStrings("btrfs", unit.fs_type);
    try std.testing.expectEqualStrings("defaults,noatime", unit.options);
}
