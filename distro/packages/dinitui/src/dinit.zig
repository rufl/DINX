const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const Scope = enum {
    system,
    user,

    pub fn label(self: Scope) []const u8 {
        return switch (self) {
            .system => "System",
            .user => "User",
        };
    }
};

pub const State = enum {
    started,
    starting,
    stopping,
    stopped,
    failed,
    unknown,

    pub fn label(self: State) []const u8 {
        return switch (self) {
            .started => "Started",
            .starting => "Starting",
            .stopping => "Stopping",
            .stopped => "Stopped",
            .failed => "Failed",
            .unknown => "Unknown",
        };
    }
};

pub const Service = struct {
    name: []u8,
    summary: []u8,
    state: State,

    pub fn deinit(self: *Service, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.summary);
        self.* = undefined;
    }
};

pub const CommandResult = struct {
    output: []u8,
    error_output: []u8,
    success: bool,

    pub fn deinit(self: *CommandResult, allocator: Allocator) void {
        allocator.free(self.output);
        allocator.free(self.error_output);
        self.* = undefined;
    }
};

pub const Action = enum {
    start,
    stop,
    restart,
    reload,
    enable,
    disable,
    wake,
    release,
    unpin,
    unload,
    trigger,
    untrigger,
    is_started,
    is_failed,
    add_dep,
    rm_dep,
    setenv,
    unsetenv,
    catlog,
    clear_log,
    signal,
    signal_list,
    shutdown,

    pub fn label(self: Action) []const u8 {
        return switch (self) {
            .start => "Start",
            .stop => "Stop",
            .restart => "Restart",
            .reload => "Reload description",
            .enable => "Enable via boot",
            .disable => "Disable via boot",
            .wake => "Wake",
            .release => "Release activation",
            .unpin => "Unpin",
            .unload => "Unload",
            .trigger => "Trigger",
            .untrigger => "Untrigger",
            .is_started => "Check started",
            .is_failed => "Check failed",
            .add_dep => "Add dependency",
            .rm_dep => "Remove dependency",
            .setenv => "Set environment",
            .unsetenv => "Unset environment",
            .catlog => "Show log",
            .clear_log => "Clear log",
            .signal => "Send signal",
            .signal_list => "List signals",
            .shutdown => "Shutdown Dinit",
        };
    }

    pub fn requiresService(self: Action) bool {
        return switch (self) {
            .setenv, .unsetenv, .signal_list, .shutdown => false,
            else => true,
        };
    }
};

pub fn deinitServices(allocator: Allocator, services: *std.ArrayList(Service)) void {
    for (services.items) |*service| service.deinit(allocator);
    services.deinit(allocator);
}

pub fn parseList(allocator: Allocator, text: []const u8) !std.ArrayList(Service) {
    var services: std.ArrayList(Service) = .empty;
    errdefer deinitServices(allocator, &services);

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        const name = serviceNameFromListLine(trimmed) orelse continue;
        if (!isSafeServiceName(name)) continue;
        if (containsService(services.items, name)) continue;
        try services.append(allocator, .{
            .name = try allocator.dupe(u8, name),
            .summary = try allocator.dupe(u8, trimmed),
            .state = stateFromListLine(trimmed),
        });
    }
    return services;
}

pub fn appendServiceFiles(
    allocator: Allocator,
    io: std.Io,
    services: *std.ArrayList(Service),
    scope: Scope,
    home: []const u8,
) !void {
    const system_dirs = [_][]const u8{ "/etc/dinit.d", "/etc/dinit.d/boot.d" };
    for (system_dirs) |path| try appendDirectory(allocator, io, services, path);

    if (scope == .user and home.len > 0) {
        var user_path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const user_dir = try std.fmt.bufPrint(&user_path_buffer, "{s}/.config/dinit.d", .{home});
        try appendDirectory(allocator, io, services, user_dir);
        const user_boot = try std.fmt.bufPrint(&user_path_buffer, "{s}/.config/dinit.d/boot.d", .{home});
        try appendDirectory(allocator, io, services, user_boot);
    }
}

pub fn runAction(
    allocator: Allocator,
    io: std.Io,
    scope: Scope,
    action: Action,
    service: ?[]const u8,
    signal_name: []const u8,
    extra: []const u8,
) !CommandResult {
    const service_name = if (action.requiresService()) service orelse return error.ServiceRequired else "";
    if (action.requiresService() and !isSafeServiceName(service_name)) return error.InvalidServiceName;

    var extra_tokens: [16][]const u8 = undefined;
    const extra_count = try splitExtraArguments(extra, &extra_tokens);
    var args: [32][]const u8 = undefined;
    var count: usize = 0;

    switch (action) {
        .start, .stop, .restart, .reload, .wake, .release, .unpin, .unload, .trigger, .untrigger => |simple| {
            args[0] = switch (simple) {
                .start => "start",
                .stop => "stop",
                .restart => "restart",
                .reload => "reload",
                .wake => "wake",
                .release => "release",
                .unpin => "unpin",
                .unload => "unload",
                .trigger => "trigger",
                .untrigger => "untrigger",
                else => unreachable,
            };
            args[1] = service_name;
            count = 2;
        },
        .is_started, .is_failed => |check| {
            args[0] = if (check == .is_started) "is-started" else "is-failed";
            args[1] = service_name;
            count = 2;
        },
        .enable, .disable => |persistent| {
            if (extra_count > 1) return error.InvalidArguments;
            args[0] = if (persistent == .enable) "enable" else "disable";
            if (extra_count == 1) {
                if (!isSafeServiceName(extra_tokens[0])) return error.InvalidServiceName;
                args[1] = "--from";
                args[2] = extra_tokens[0];
                args[3] = service_name;
                count = 4;
            } else {
                args[1] = service_name;
                count = 2;
            }
        },
        .add_dep, .rm_dep => |dependency_action| {
            if (extra_count != 2 or !isSafeDependencyType(extra_tokens[0]) or
                !isSafeServiceName(extra_tokens[1])) return error.InvalidArguments;
            args[0] = if (dependency_action == .add_dep) "add-dep" else "rm-dep";
            args[1] = extra_tokens[0];
            args[2] = service_name;
            args[3] = extra_tokens[1];
            count = 4;
        },
        .setenv, .unsetenv => |environment_action| {
            if (extra_count == 0) return error.InvalidArguments;
            for (extra_tokens[0..extra_count]) |token| {
                if (environment_action == .setenv) {
                    if (!isSafeEnvironmentAssignment(token)) return error.InvalidArguments;
                } else if (!isSafeEnvironmentName(token)) {
                    return error.InvalidArguments;
                }
            }
            args[0] = if (environment_action == .setenv) "setenv" else "unsetenv";
            @memcpy(args[1..][0..extra_count], extra_tokens[0..extra_count]);
            count = extra_count + 1;
        },
        .catlog => {
            if (extra_count != 0) return error.InvalidArguments;
            args[0] = "catlog";
            args[1] = service_name;
            count = 2;
        },
        .clear_log => {
            if (extra_count != 0) return error.InvalidArguments;
            args[0] = "catlog";
            args[1] = "--clear";
            args[2] = service_name;
            count = 3;
        },
        .signal => {
            if (extra_count != 0) return error.InvalidArguments;
            if (!isSafeSignalName(signal_name)) return error.InvalidSignalName;
            args[0] = "signal";
            args[1] = signal_name;
            args[2] = service_name;
            count = 3;
        },
        .signal_list => {
            if (extra_count != 0) return error.InvalidArguments;
            args[0] = "signal";
            args[1] = "--list";
            count = 2;
        },
        .shutdown => {
            if (extra_count != 1 or !std.mem.eql(u8, extra_tokens[0], "CONFIRM"))
                return error.ConfirmationRequired;
            args[0] = "shutdown";
            count = 1;
        },
    }
    return command(allocator, io, scope, args[0..count], true);
}

pub fn list(allocator: Allocator, io: std.Io, scope: Scope) !CommandResult {
    return command(allocator, io, scope, &.{"list"}, true);
}

pub fn status(allocator: Allocator, io: std.Io, scope: Scope, service: []const u8) !CommandResult {
    if (!isSafeServiceName(service)) return error.InvalidServiceName;
    return command(allocator, io, scope, &.{ "status", service }, true);
}

pub fn command(
    allocator: Allocator,
    io: std.Io,
    scope: Scope,
    args: []const []const u8,
    allow_privileged_retry: bool,
) !CommandResult {
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    try argv.append(allocator, "dinitctl");
    try argv.append(allocator, switch (scope) {
        .system => "--system",
        .user => "--user",
    });
    try argv.appendSlice(allocator, args);

    var result = try runChild(allocator, io, argv.items);
    if (scope == .system and allow_privileged_retry and
        !result.success and permissionFailure(result.error_output))
    {
        result.deinit(allocator);
        argv.clearRetainingCapacity();
        try argv.append(allocator, "pkexec");
        try argv.append(allocator, "dinitctl");
        try argv.append(allocator, "--system");
        try argv.appendSlice(allocator, args);
        return runChild(allocator, io, argv.items);
    }
    return result;
}

pub fn isSafeServiceName(name: []const u8) bool {
    if (name.len == 0 or name[0] == '-') return false;
    for (name) |char| {
        if (!((char >= 'a' and char <= 'z') or
            (char >= 'A' and char <= 'Z') or
            (char >= '0' and char <= '9') or
            char == '_' or char == '-' or char == '.' or
            char == '@' or char == ':' or char == '+')) return false;
    }
    return true;
}

fn isSafeSignalName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |char| {
        if (!((char >= 'A' and char <= 'Z') or (char >= '0' and char <= '9') or char == '_'))
            return false;
    }
    return true;
}

fn splitExtraArguments(input: []const u8, output: *[16][]const u8) !usize {
    var count: usize = 0;
    var token_start: ?usize = null;
    for (input, 0..) |char, index| {
        if (isArgumentSeparator(char)) {
            if (token_start) |start| {
                if (count == output.len) return error.InvalidArguments;
                output[count] = input[start..index];
                count += 1;
                token_start = null;
            }
        } else if (token_start == null) {
            token_start = index;
        }
    }
    if (token_start) |start| {
        if (count == output.len) return error.InvalidArguments;
        output[count] = input[start..];
        count += 1;
    }
    return count;
}

fn isArgumentSeparator(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}

fn isSafeDependencyType(value: []const u8) bool {
    return std.mem.eql(u8, value, "need") or
        std.mem.eql(u8, value, "milestone") or
        std.mem.eql(u8, value, "waits-for") or
        std.mem.eql(u8, value, "regular");
}

fn isSafeEnvironmentName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name, 0..) |char, index| {
        const valid = if (index == 0)
            ((char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or char == '_')
        else
            ((char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or
                (char >= '0' and char <= '9') or char == '_');
        if (!valid) return false;
    }
    return true;
}

fn isSafeEnvironmentAssignment(token: []const u8) bool {
    const equal = std.mem.indexOfScalar(u8, token, '=') orelse return false;
    if (!isSafeEnvironmentName(token[0..equal])) return false;
    for (token[equal + 1 ..]) |char| {
        if (char == 0 or char == ' ' or char == '\r' or char == '\n' or char == '\t') return false;
    }
    return true;
}

fn runChild(allocator: Allocator, io: std.Io, argv: []const []const u8) !CommandResult {
    const result = try std.process.run(allocator, io, .{
        .argv = argv,
        .stdout_limit = std.Io.Limit.limited(512 * 1024),
        .stderr_limit = std.Io.Limit.limited(512 * 1024),
    });
    return .{
        .output = result.stdout,
        .error_output = result.stderr,
        .success = result.term.success(),
    };
}

fn permissionFailure(stderr: []const u8) bool {
    return std.mem.indexOf(u8, stderr, "Permission denied") != null or
        std.mem.indexOf(u8, stderr, "permission denied") != null or
        std.mem.indexOf(u8, stderr, "Operation not permitted") != null or
        std.mem.indexOf(u8, stderr, "Not authorized") != null or
        std.mem.indexOf(u8, stderr, "not authorized") != null;
}

fn normalizeListMarker(line: []const u8) []const u8 {
    if (line.len >= 2 and line[0] == '[' and line[1] == '[') return line[1..];
    return line;
}

fn serviceNameFromListLine(line: []const u8) ?[]const u8 {
    var rest = normalizeListMarker(line);
    if (rest[0] == '[') {
        const close = std.mem.lastIndexOfScalar(u8, rest, ']') orelse return null;
        rest = std.mem.trim(u8, rest[close + 1 ..], " \t");
    }
    if (rest.len == 0) return null;
    const end = std.mem.indexOfAny(u8, rest, " \t") orelse rest.len;
    if (end == 0) return null;
    return rest[0..end];
}

fn stateFromListLine(line: []const u8) State {
    const marker = normalizeListMarker(line);
    if (std.mem.startsWith(u8, marker, "[+")) return .started;
    if (std.mem.startsWith(u8, marker, "[X") or std.mem.startsWith(u8, marker, "[x")) return .failed;
    if (std.mem.indexOf(u8, marker, "<<") != null) return .starting;
    if (std.mem.indexOf(u8, marker, ">>") != null) return .stopping;
    if (std.mem.startsWith(u8, marker, "[")) return .stopped;
    return .unknown;
}

fn containsService(services: []const Service, name: []const u8) bool {
    for (services) |service| {
        if (std.mem.eql(u8, service.name, name)) return true;
    }
    return false;
}

fn appendDirectory(allocator: Allocator, io: std.Io, services: *std.ArrayList(Service), path: []const u8) !void {
    var dir = std.Io.Dir.openDirAbsolute(io, path, .{ .iterate = true }) catch return;
    defer dir.close(io);
    var iterator = dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file and entry.kind != .sym_link) continue;
        if (!isSafeServiceName(entry.name)) continue;
        if (containsService(services.items, entry.name)) continue;
        try services.append(allocator, .{
            .name = try allocator.dupe(u8, entry.name),
            .summary = try allocator.dupe(u8, "Description file found"),
            .state = .unknown,
        });
    }
}

fn expectState(expected: State, text: []const u8) !void {
    var services = try parseList(std.testing.allocator, text);
    defer deinitServices(std.testing.allocator, &services);
    try std.testing.expectEqual(@as(usize, 3), services.items.len);
    try std.testing.expectEqual(expected, services.items[0].state);
}

test "parses native dinit list framing" {
    try expectState(.started, "[[+]     ] fixture (pid: 325046)\n[[  <<]  starting\n[[   -] stopped");
}

test "parses dinit list state markers" {
    try expectState(.started, "[+] dbus\n[  <<] pipewire\n[   -] stopped");
}

test "rejects unsafe service names" {
    try std.testing.expect(isSafeServiceName("greetd"));
    try std.testing.expect(isSafeServiceName("foo@bar.service"));
    try std.testing.expect(!isSafeServiceName("--system"));
    try std.testing.expect(!isSafeServiceName("bad name"));
}
test "parses safe structured action arguments" {
    var tokens: [16][]const u8 = undefined;
    try std.testing.expectEqual(@as(usize, 3), try splitExtraArguments("need  target-service\tignored", &tokens));
    try std.testing.expect(std.mem.eql(u8, tokens[0], "need"));
    try std.testing.expect(std.mem.eql(u8, tokens[1], "target-service"));
    try std.testing.expect(std.mem.eql(u8, tokens[2], "ignored"));
    try std.testing.expect(isSafeDependencyType("waits-for"));
    try std.testing.expect(!isSafeDependencyType("exec"));
    try std.testing.expect(isSafeEnvironmentAssignment("PATH=/usr/bin"));
    try std.testing.expect(!isSafeEnvironmentAssignment("PATH=/tmp value"));
    try std.testing.expect(isSafeEnvironmentName("DINX_MODE"));
    try std.testing.expect(!isSafeEnvironmentName("1DINX"));
}

test "classifies actions that need a selected service" {
    try std.testing.expect(Action.start.requiresService());
    try std.testing.expect(Action.add_dep.requiresService());
    try std.testing.expect(!Action.setenv.requiresService());
    try std.testing.expect(!Action.shutdown.requiresService());
}
test "guards service-less and destructive actions" {
    try std.testing.expectError(
        error.ServiceRequired,
        runAction(std.testing.allocator, std.testing.io, .system, .start, null, "TERM", ""),
    );
    try std.testing.expectError(
        error.ConfirmationRequired,
        runAction(std.testing.allocator, std.testing.io, .system, .shutdown, null, "TERM", ""),
    );
}
