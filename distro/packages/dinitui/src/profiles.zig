const std = @import("std");
const dinit = @import("dinit.zig");

const builtin_config =
    "# DINX service performance profiles. Keep essential desktop services out of these lists.\n" ++
    "\n" ++
    "[profile.normal]\n" ++
    "description = Desktop services\n" ++
    "enable = bluetoothd\n" ++
    "disable =\n" ++
    "\n" ++
    "[profile.lite]\n" ++
    "description = Reduced optional background services\n" ++
    "enable =\n" ++
    "disable = bluetoothd\n" ++
    "\n" ++
    "[profile.gaming]\n" ++
    "description = Gaming with controller and security services preserved\n" ++
    "enable = bluetoothd\n" ++
    "disable =\n";

pub const Profile = struct {
    name: []u8,
    description: []u8,
    enable: std.ArrayList([]u8),
    disable: std.ArrayList([]u8),

    fn deinit(self: *Profile, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.description);
        for (self.enable.items) |service| allocator.free(service);
        for (self.disable.items) |service| allocator.free(service);
        self.enable.deinit(allocator);
        self.disable.deinit(allocator);
    }

    fn init(allocator: std.mem.Allocator, name: []const u8) !Profile {
        return .{
            .name = try allocator.dupe(u8, name),
            .description = try allocator.dupe(u8, name),
            .enable = .empty,
            .disable = .empty,
        };
    }

    fn hasService(list: []const []u8, service: []const u8) bool {
        for (list) |item| {
            if (std.mem.eql(u8, item, service)) return true;
        }
        return false;
    }

    pub fn isDisabled(self: *const Profile, service: []const u8) bool {
        return hasService(self.disable.items, service);
    }

    fn removeService(list: *std.ArrayList([]u8), allocator: std.mem.Allocator, service: []const u8) void {
        var index: usize = 0;
        while (index < list.items.len) {
            if (std.mem.eql(u8, list.items[index], service)) {
                allocator.free(list.orderedRemove(index));
            } else {
                index += 1;
            }
        }
    }

    fn addService(list: *std.ArrayList([]u8), allocator: std.mem.Allocator, service: []const u8) !void {
        for (list.items) |item| {
            if (std.mem.eql(u8, item, service)) return;
        }
        try list.append(allocator, try allocator.dupe(u8, service));
    }
};

pub const ApplyReport = struct {
    success: bool,
    output: []u8,

    pub fn deinit(self: *ApplyReport, allocator: std.mem.Allocator) void {
        allocator.free(self.output);
    }
};

pub const Store = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    home: []const u8,
    profiles: std.ArrayList(Profile),
    config_path: []u8,
    state_path: []u8,
    gaming_previous_path: []u8,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, home: []const u8) !Store {
        var store = Store{
            .allocator = allocator,
            .io = io,
            .home = home,
            .profiles = .empty,
            .config_path = try configPath(allocator, home),
            .state_path = try statePath(allocator, home),
            .gaming_previous_path = try gamingPreviousPath(allocator, home),
        };
        errdefer store.deinit();
        try store.loadBuiltins();
        try store.loadFile("/etc/dinx/dinitui/profiles.conf");
        try store.loadFile(store.config_path);
        return store;
    }

    pub fn deinit(self: *Store) void {
        for (self.profiles.items) |*profile| profile.deinit(self.allocator);
        self.profiles.deinit(self.allocator);
        self.allocator.free(self.config_path);
        self.allocator.free(self.state_path);
        self.allocator.free(self.gaming_previous_path);
    }
    fn loadBuiltins(self: *Store) !void {
        try self.parseConfig(builtin_config);
    }

    fn loadFile(self: *Store, path: []const u8) !void {
        const contents = std.Io.Dir.cwd().readFileAlloc(self.io, path, self.allocator, .limited(64 * 1024)) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer self.allocator.free(contents);
        try self.parseConfig(contents);
    }

    fn parseConfig(self: *Store, contents: []const u8) !void {
        var current: ?usize = null;
        var lines = std.mem.splitScalar(u8, contents, '\n');
        while (lines.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;

            if (line[0] == '[' and line[line.len - 1] == ']') {
                const section = line[1 .. line.len - 1];
                if (!std.mem.startsWith(u8, section, "profile.")) {
                    current = null;
                    continue;
                }
                const name = section[8..];
                if (!isSafeProfileName(name)) {
                    current = null;
                    continue;
                }
                if (self.findProfile(name)) |index| {
                    self.profiles.items[index].deinit(self.allocator);
                    _ = self.profiles.orderedRemove(index);
                }
                try self.profiles.append(self.allocator, try Profile.init(self.allocator, name));
                current = self.profiles.items.len - 1;
                continue;
            }

            const index = current orelse continue;
            const equals = std.mem.indexOfScalar(u8, line, '=') orelse continue;
            const key = std.mem.trim(u8, line[0..equals], " \t");
            const value = std.mem.trim(u8, line[equals + 1 ..], " \t");
            if (std.mem.eql(u8, key, "description")) {
                self.allocator.free(self.profiles.items[index].description);
                self.profiles.items[index].description = try self.allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "enable")) {
                try self.parseServices(&self.profiles.items[index].enable, value);
            } else if (std.mem.eql(u8, key, "disable")) {
                try self.parseServices(&self.profiles.items[index].disable, value);
            }
        }
    }

    fn parseServices(self: *Store, list: *std.ArrayList([]u8), value: []const u8) !void {
        for (list.items) |service| self.allocator.free(service);
        list.clearRetainingCapacity();
        var fields = std.mem.splitScalar(u8, value, ',');
        while (fields.next()) |raw_service| {
            const service = std.mem.trim(u8, raw_service, " \t\r");
            if (service.len == 0 or !dinit.isSafeServiceName(service)) continue;
            try Profile.addService(list, self.allocator, service);
        }
    }

    fn findProfile(self: *const Store, name: []const u8) ?usize {
        for (self.profiles.items, 0..) |profile, index| {
            if (std.mem.eql(u8, profile.name, name)) return index;
        }
        return null;
    }

    pub fn get(self: *const Store, name: []const u8) ?*const Profile {
        const index = self.findProfile(name) orelse return null;
        return &self.profiles.items[index];
    }

    pub fn names(self: *const Store) []const Profile {
        return self.profiles.items;
    }

    pub fn activeName(self: *const Store) ![]u8 {
        const contents = std.Io.Dir.cwd().readFileAlloc(self.io, self.state_path, self.allocator, .limited(256)) catch |err| switch (err) {
            error.FileNotFound => return self.allocator.dupe(u8, "normal"),
            else => return err,
        };
        defer self.allocator.free(contents);
        const name = std.mem.trim(u8, contents, " \t\r\n");
        if (self.findProfile(name) == null) return self.allocator.dupe(u8, "normal");
        return self.allocator.dupe(u8, name);
    }
    pub fn enterGaming(self: *Store) !ApplyReport {
        const active = try self.activeName();
        defer self.allocator.free(active);
        if (std.mem.eql(u8, active, "gaming")) {
            return .{ .success = true, .output = try self.allocator.dupe(u8, "profile=gaming\nprevious=unchanged\n") };
        }
        try self.writeGamingPrevious(active);
        return self.apply("gaming");
    }

    pub fn leaveGaming(self: *Store) !ApplyReport {
        const contents = std.Io.Dir.cwd().readFileAlloc(self.io, self.gaming_previous_path, self.allocator, .limited(256)) catch |err| switch (err) {
            error.FileNotFound => return error.NoGamingProfile,
            else => return err,
        };
        defer self.allocator.free(contents);
        const previous = std.mem.trim(u8, contents, " \t\r\n");
        if (!isSafeProfileName(previous) or self.findProfile(previous) == null) return error.InvalidGamingState;
        const report = try self.apply(previous);
        if (report.success) try self.writeGamingPrevious("");
        return report;
    }

    pub fn ensureProfile(self: *Store, name: []const u8) !void {
        if (!isSafeProfileName(name)) return error.InvalidProfileName;
        if (self.findProfile(name) != null) return;
        try self.profiles.append(self.allocator, try Profile.init(self.allocator, name));
    }

    pub fn setServiceEnabled(self: *Store, profile_name: []const u8, service: []const u8, enabled: bool) !void {
        if (!isSafeProfileName(profile_name) or !dinit.isSafeServiceName(service)) return error.InvalidProfileName;
        const index = self.findProfile(profile_name) orelse return error.ProfileNotFound;
        var profile = &self.profiles.items[index];
        Profile.removeService(&profile.enable, self.allocator, service);
        Profile.removeService(&profile.disable, self.allocator, service);
        if (enabled) {
            try Profile.addService(&profile.enable, self.allocator, service);
        } else {
            try Profile.addService(&profile.disable, self.allocator, service);
        }
        try self.save();
    }

    pub fn save(self: *const Store) !void {
        const parent = std.fs.path.dirname(self.config_path) orelse return error.InvalidConfigPath;
        try std.Io.Dir.cwd().createDirPath(self.io, parent);
        var output: std.Io.Writer.Allocating = .init(self.allocator);
        defer output.deinit();
        try output.writer.writeAll("# DINX service performance profiles.\n# enable/disable entries are explicit; essential desktop services are not touched by defaults.\n\n");
        for (self.profiles.items) |profile| {
            try output.writer.print("[profile.{s}]\ndescription = {s}\nenable = ", .{ profile.name, profile.description });
            try writeServices(&output.writer, profile.enable.items);
            try output.writer.writeAll("\ndisable = ");
            try writeServices(&output.writer, profile.disable.items);
            try output.writer.writeAll("\n\n");
        }
        const bytes = try output.toOwnedSlice();
        defer self.allocator.free(bytes);
        try std.Io.Dir.cwd().writeFile(self.io, .{
            .sub_path = self.config_path,
            .data = bytes,
            .flags = .{ .permissions = .fromMode(0o600) },
        });
    }

    fn runProfileCommand(
        self: *Store,
        writer: *std.Io.Writer,
        operation: []const u8,
        service: []const u8,
        args: []const []const u8,
    ) !bool {
        const result = dinit.command(self.allocator, self.io, .system, args, true) catch |err| {
            try writer.print("{s}={s} result=error:{s}\n", .{ operation, service, @errorName(err) });
            return false;
        };
        var command_result = result;
        defer command_result.deinit(self.allocator);
        try writeCommandOutcome(writer, operation, service, &command_result);
        return command_result.success;
    }

    pub fn apply(self: *Store, name: []const u8) !ApplyReport {
        const profile = self.get(name) orelse return error.ProfileNotFound;
        var available: std.ArrayList(dinit.Service) = .empty;
        defer dinit.deinitServices(self.allocator, &available);
        try dinit.appendServiceFiles(self.allocator, self.io, &available, .system, self.home);

        var output: std.Io.Writer.Allocating = .init(self.allocator);
        errdefer output.deinit();
        var failures: usize = 0;
        try output.writer.print("profile={s}\n", .{name});

        var listed: ?dinit.CommandResult = null;
        if (dinit.list(self.allocator, self.io, .system)) |result| {
            listed = result;
        } else |err| {
            failures += 1;
            try output.writer.print("list result=error:{s}\n", .{@errorName(err)});
        }
        if (listed) |result| {
            var list_result = result;
            defer list_result.deinit(self.allocator);
            if (!list_result.success) {
                failures += 1;
                try writeCommandOutcome(&output.writer, "list", "", &list_result);
            } else if (dinit.parseList(self.allocator, list_result.output)) |services_value| {
                var services = services_value;
                defer dinit.deinitServices(self.allocator, &services);
                for (services.items) |service| {
                    if (!containsService(available.items, service.name)) {
                        try available.append(self.allocator, .{
                            .name = try self.allocator.dupe(u8, service.name),
                            .summary = try self.allocator.dupe(u8, service.summary),
                            .state = service.state,
                        });
                    }
                }
            } else |err| {
                failures += 1;
                try output.writer.print("list-parse result=error:{s}\n", .{@errorName(err)});
            }
        }

        for (profile.disable.items) |service| {
            if (!containsService(available.items, service)) {
                try output.writer.print("disable={s} result=skipped reason=service-not-discovered\n", .{service});
                continue;
            }
            if (!try self.runProfileCommand(&output.writer, "stop", service, &.{ "stop", service })) failures += 1;
            if (!try self.runProfileCommand(&output.writer, "disable", service, &.{ "disable", service })) failures += 1;
        }
        for (profile.enable.items) |service| {
            if (!containsService(available.items, service)) {
                try output.writer.print("enable={s} result=skipped reason=service-not-discovered\n", .{service});
                continue;
            }
            if (!try self.runProfileCommand(&output.writer, "enable", service, &.{ "enable", service })) failures += 1;
            if (!try self.runProfileCommand(&output.writer, "start", service, &.{ "start", service })) failures += 1;
        }
        if (failures == 0) {
            try self.writeActive(name);
        } else {
            try output.writer.print("failures={d}\nactive-state=unchanged\n", .{failures});
        }
        return .{ .success = failures == 0, .output = try output.toOwnedSlice() };
    }

    fn writeActive(self: *const Store, name: []const u8) !void {
        const parent = std.fs.path.dirname(self.state_path) orelse return error.InvalidStatePath;
        try std.Io.Dir.cwd().createDirPath(self.io, parent);
        try std.Io.Dir.cwd().writeFile(self.io, .{
            .sub_path = self.state_path,
            .data = name,
            .flags = .{ .permissions = .fromMode(0o600) },
        });
    }

    fn writeGamingPrevious(self: *const Store, name: []const u8) !void {
        const parent = std.fs.path.dirname(self.gaming_previous_path) orelse return error.InvalidStatePath;
        try std.Io.Dir.cwd().createDirPath(self.io, parent);
        try std.Io.Dir.cwd().writeFile(self.io, .{
            .sub_path = self.gaming_previous_path,
            .data = name,
            .flags = .{ .permissions = .fromMode(0o600) },
        });
    }
};

fn writeCommandOutcome(writer: *std.Io.Writer, operation: []const u8, service: []const u8, result: *const dinit.CommandResult) !void {
    const label = if (result.success) "ok" else "failed";
    if (service.len == 0) {
        try writer.print("{s} result={s}\n", .{ operation, label });
    } else {
        try writer.print("{s}={s} result={s}\n", .{ operation, service, label });
    }
    const detail = if (result.success) result.output else result.error_output;
    if (detail.len == 0) return;
    try writer.writeAll(detail);
    if (detail[detail.len - 1] != '\n') try writer.writeByte('\n');
}

fn writeServices(writer: *std.Io.Writer, services: []const []u8) !void {
    for (services, 0..) |service, index| {
        if (index != 0) try writer.writeAll(",");
        try writer.writeAll(service);
    }
}

fn containsService(items: []const dinit.Service, value: []const u8) bool {
    for (items) |item| {
        if (std.mem.eql(u8, item.name, value)) return true;
    }
    return false;
}

pub fn isSafeProfileName(name: []const u8) bool {
    if (name.len == 0 or name.len > 48 or std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..") or name[0] == '-') return false;
    for (name) |char| {
        if (!((char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or (char >= '0' and char <= '9') or char == '_' or char == '-' or char == '.')) return false;
    }
    return true;
}

fn configPath(allocator: std.mem.Allocator, home: []const u8) ![]u8 {
    if (std.c.getenv("XDG_CONFIG_HOME")) |value| {
        return try std.fs.path.join(allocator, &.{ std.mem.span(value), "dinx", "dinitui", "profiles.conf" });
    }
    const base = try std.fs.path.join(allocator, &.{ home, ".config" });
    defer allocator.free(base);
    return try std.fs.path.join(allocator, &.{ base, "dinx", "dinitui", "profiles.conf" });
}

fn statePath(allocator: std.mem.Allocator, home: []const u8) ![]u8 {
    if (std.c.getenv("XDG_STATE_HOME")) |value| {
        return try std.fs.path.join(allocator, &.{ std.mem.span(value), "dinx", "dinitui", "active-profile" });
    }
    const base = try std.fs.path.join(allocator, &.{ home, ".local", "state" });
    defer allocator.free(base);
    return try std.fs.path.join(allocator, &.{ base, "dinx", "dinitui", "active-profile" });
}
fn gamingPreviousPath(allocator: std.mem.Allocator, home: []const u8) ![]u8 {
    if (std.c.getenv("XDG_STATE_HOME")) |value| {
        return try std.fs.path.join(allocator, &.{ std.mem.span(value), "dinx", "dinitui", "gaming-previous-profile" });
    }
    const base = try std.fs.path.join(allocator, &.{ home, ".local", "state" });
    defer allocator.free(base);
    return try std.fs.path.join(allocator, &.{ base, "dinx", "dinitui", "gaming-previous-profile" });
}

test "built-in profiles preserve essential services" {
    var store = try Store.init(std.testing.allocator, std.testing.io, "/tmp/dinx-profile-test");
    defer store.deinit();
    const lite = store.get("lite").?;
    try std.testing.expect(lite.isDisabled("bluetoothd"));
    try std.testing.expect(!lite.isDisabled("ufw"));
    try std.testing.expect(!lite.isDisabled("opensnitchd"));
    const gaming = store.get("gaming").?;
    try std.testing.expect(!gaming.isDisabled("bluetoothd"));
    try std.testing.expect(!gaming.isDisabled("ufw"));
    try std.testing.expect(!gaming.isDisabled("opensnitchd"));
    try std.testing.expect(!gaming.isDisabled("NetworkManager"));
    try std.testing.expect(!gaming.isDisabled("pipewire"));
}

test "profile parser accepts custom names and filters unsafe services" {
    var store = try Store.init(std.testing.allocator, std.testing.io, "/tmp/dinx-profile-test");
    defer store.deinit();
    try store.parseConfig(
        "[profile.streamer]\n" ++
            "description = Streaming and gaming\n" ++
            "enable = NetworkManager,pipewire\n" ++
            "disable = bluetoothd,../../etc/passwd,opensnitchd\n",
    );
    const profile = store.get("streamer").?;
    try std.testing.expectEqualStrings("Streaming and gaming", profile.description);
    try std.testing.expectEqual(@as(usize, 2), profile.enable.items.len);
    try std.testing.expectEqual(@as(usize, 2), profile.disable.items.len);
}

test "profile names and service names are constrained" {
    try std.testing.expect(isSafeProfileName("my-gaming.v2"));
    try std.testing.expect(!isSafeProfileName("../gaming"));
    try std.testing.expect(!isSafeProfileName(".."));
    try std.testing.expect(!dinit.isSafeServiceName("../dinit.d"));
}
