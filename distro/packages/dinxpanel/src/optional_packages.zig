const std = @import("std");

const Allocator = std.mem.Allocator;

pub const cups_package = "cups-dinit";
pub const cups_description = "CUPS printing support with the Artix dinit service files";
pub const cups_user_install_argv = [_][]const u8{
    "pacman",
    "--needed",
    "--noconfirm",
    "-S",
    cups_package,
};
pub const cups_install_argv = [_][]const u8{
    "pkexec",
    "pacman",
    "--needed",
    "--noconfirm",
    "-S",
    cups_package,
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

pub fn install(allocator: Allocator, io: std.Io) !CommandResult {
    var result = try runChild(allocator, io, &cups_user_install_argv);
    if (!result.success and permissionFailure(result.error_output)) {
        result.deinit(allocator);
        return runChild(allocator, io, &cups_install_argv);
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

test "printing package uses a fixed non-root and pkexec fallback" {
    const user_expected = [_][]const u8{ "pacman", "--needed", "--noconfirm", "-S", "cups-dinit" };
    const root_expected = [_][]const u8{ "pkexec", "pacman", "--needed", "--noconfirm", "-S", "cups-dinit" };
    try std.testing.expectEqualStrings("cups-dinit", cups_package);
    try std.testing.expectEqualStrings("CUPS printing support with the Artix dinit service files", cups_description);
    for (cups_user_install_argv, 0..) |argument, index| {
        try std.testing.expectEqualStrings(user_expected[index], argument);
    }
    for (cups_install_argv, 0..) |argument, index| {
        try std.testing.expectEqualStrings(root_expected[index], argument);
    }
}

test "permission fallback recognizes pacman authorization failures only" {
    try std.testing.expect(permissionFailure("error: you cannot perform this operation unless you are root"));
    try std.testing.expect(permissionFailure("Permission denied"));
    try std.testing.expect(permissionFailure("Not authorized"));
    try std.testing.expect(!permissionFailure("error: target not found: cups-dinit"));
    try std.testing.expect(!permissionFailure("error: failed to commit transaction"));
}
