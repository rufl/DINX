const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Kernel = struct {
    id: []const u8,
    label: []const u8,
    packages: []const []const u8,
};

const linux_packages = [_][]const u8{ "linux", "linux-headers" };
const lts_packages = [_][]const u8{ "linux-lts", "linux-lts-headers" };
const zen_packages = [_][]const u8{ "linux-zen", "linux-zen-headers" };
const hardened_packages = [_][]const u8{ "linux-hardened", "linux-hardened-headers" };

pub const catalog = [_]Kernel{
    .{ .id = "linux", .label = "Linux (default)", .packages = &linux_packages },
    .{ .id = "linux-lts", .label = "Linux LTS", .packages = &lts_packages },
    .{ .id = "linux-zen", .label = "Linux Zen", .packages = &zen_packages },
    .{ .id = "linux-hardened", .label = "Linux Hardened", .packages = &hardened_packages },
};

pub const Report = struct {
    running: []u8,
    installed: std.ArrayList([]const u8),

    pub fn deinit(self: *Report, allocator: Allocator) void {
        allocator.free(self.running);
        self.installed.deinit(allocator);
    }

    pub fn isInstalled(self: *const Report, id: []const u8) bool {
        for (self.installed.items) |installed| {
            if (std.mem.eql(u8, installed, id)) return true;
        }
        return false;
    }
};

pub const CommandResult = struct {
    output: []u8,
    error_output: []u8,
    success: bool,

    pub fn deinit(self: *CommandResult, allocator: Allocator) void {
        allocator.free(self.output);
        allocator.free(self.error_output);
    }
};

pub fn find(id: []const u8) ?*const Kernel {
    for (&catalog) |*kernel| {
        if (std.mem.eql(u8, kernel.id, id)) return kernel;
    }
    return null;
}

pub fn detect(allocator: Allocator, io: std.Io) !Report {
    const uname = try std.process.run(allocator, io, .{
        .argv = &.{ "uname", "-r" },
        .stdout_limit = std.Io.Limit.limited(256),
        .stderr_limit = std.Io.Limit.limited(16 * 1024),
    });
    defer allocator.free(uname.stderr);
    if (!uname.term.success()) {
        allocator.free(uname.stdout);
        return error.KernelDetectionFailed;
    }
    const running = try allocator.dupe(u8, std.mem.trim(u8, uname.stdout, " \t\r\n"));
    allocator.free(uname.stdout);

    var report = Report{ .running = running, .installed = .empty };
    errdefer report.deinit(allocator);

    var argv: [1 + catalog.len][]const u8 = undefined;
    argv[0] = "pacman";
    for (catalog, 0..) |kernel, index| argv[index + 1] = kernel.id;
    const installed = try std.process.run(allocator, io, .{
        .argv = &argv,
        .stdout_limit = std.Io.Limit.limited(64 * 1024),
        .stderr_limit = std.Io.Limit.limited(64 * 1024),
    });
    defer allocator.free(installed.stderr);
    defer allocator.free(installed.stdout);
    try parseInstalled(allocator, &report.installed, installed.stdout);
    return report;
}
pub fn parseInstalled(allocator: Allocator, output: *std.ArrayList([]const u8), text: []const u8) !void {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        const separator = std.mem.indexOfScalar(u8, trimmed, ' ') orelse continue;
        const kernel = find(trimmed[0..separator]) orelse continue;
        var already = false;
        for (output.items) |item| {
            if (std.mem.eql(u8, item, kernel.id)) already = true;
        }
        if (!already) try output.append(allocator, kernel.id);
    }
}

pub fn formatReport(allocator: Allocator, report: *const Report) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.print("kernel-current={s}\n", .{report.running});
    for (catalog) |kernel| {
        try output.writer.print("kernel={s} installed={s} packages=", .{
            kernel.id,
            if (report.isInstalled(kernel.id)) "yes" else "no",
        });
        for (kernel.packages, 0..) |package, index| {
            if (index != 0) try output.writer.writeAll(",");
            try output.writer.writeAll(package);
        }
        try output.writer.writeAll("\n");
    }
    try output.writer.writeAll("kernel-policy=install-only; running kernel is never removed; rollback uses the bootloader\n");
    return output.toOwnedSlice();
}

pub fn install(allocator: Allocator, io: std.Io, id: []const u8) !CommandResult {
    const kernel = find(id) orelse return error.UnsupportedKernel;
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    try argv.appendSlice(allocator, &.{ "pacman", "--needed", "--noconfirm", "-S" });
    try argv.appendSlice(allocator, kernel.packages);

    var result = try runChild(allocator, io, argv.items);
    if (!result.success and permissionFailure(result.error_output)) {
        result.deinit(allocator);
        argv.clearRetainingCapacity();
        try argv.appendSlice(allocator, &.{ "pkexec", "pacman", "--needed", "--noconfirm", "-S" });
        try argv.appendSlice(allocator, kernel.packages);
        return runChild(allocator, io, argv.items);
    }
    return result;
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
        std.mem.indexOf(u8, stderr, "not authorized") != null or
        std.mem.indexOf(u8, stderr, "unless you are root") != null;
}

test "kernel catalog is fixed and excludes arbitrary names" {
    try std.testing.expect(find("linux-lts") != null);
    try std.testing.expect(find("linux-zen") != null);
    try std.testing.expect(find("linux-custom") == null);
}

test "installed parser filters to catalog" {
    var installed: std.ArrayList([]const u8) = .empty;
    defer installed.deinit(std.testing.allocator);
    try parseInstalled(std.testing.allocator, &installed, "linux-lts 6.12\nlinux-custom 1\nlinux 6.18\n");
    try std.testing.expectEqual(@as(usize, 2), installed.items.len);
    try std.testing.expectEqualStrings("linux-lts", installed.items[0]);
    try std.testing.expectEqualStrings("linux", installed.items[1]);
}
