const std = @import("std");
const dinit = @import("dinit.zig");

const Allocator = std.mem.Allocator;

pub const Vendor = enum {
    amd,
    intel,
    nvidia,
    unknown,

    pub fn label(self: Vendor) []const u8 {
        return switch (self) {
            .amd => "AMD",
            .intel => "Intel",
            .nvidia => "NVIDIA",
            .unknown => "Unknown",
        };
    }
};

pub const Device = struct {
    vendor: Vendor,
    address: []u8,
    pci_id: []u8,
    name: []u8,
    driver: []u8,

    pub fn deinit(self: *Device, allocator: Allocator) void {
        allocator.free(self.address);
        allocator.free(self.pci_id);
        allocator.free(self.name);
        allocator.free(self.driver);
        self.* = undefined;
    }
};

pub const Report = struct {
    devices: std.ArrayList(Device),

    pub fn deinit(self: *Report, allocator: Allocator) void {
        for (self.devices.items) |*device| device.deinit(allocator);
        self.devices.deinit(allocator);
    }
};

pub const Plan = struct {
    packages: std.ArrayList([]const u8),
    has_amd: bool = false,
    has_intel: bool = false,
    has_nvidia: bool = false,

    pub fn deinit(self: *Plan, allocator: Allocator) void {
        self.packages.deinit(allocator);
    }

    pub fn isEmpty(self: *const Plan) bool {
        return self.packages.items.len == 0;
    }
};

pub fn detect(allocator: Allocator, io: std.Io) !Report {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{ "lspci", "-nnk" },
        .stdout_limit = std.Io.Limit.limited(512 * 1024),
        .stderr_limit = std.Io.Limit.limited(128 * 1024),
    });
    defer allocator.free(result.stderr);
    if (!result.term.success()) {
        allocator.free(result.stdout);
        return error.DetectionFailed;
    }
    defer allocator.free(result.stdout);
    return parseLspci(allocator, result.stdout);
}

pub fn parseLspci(allocator: Allocator, text: []const u8) !Report {
    var report = Report{ .devices = .empty };
    errdefer report.deinit(allocator);

    var current: ?usize = null;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        const header_line = raw_line[0] != ' ' and raw_line[0] != '\t';
        if (header_line and !isDisplayLine(line)) {
            current = null;
            continue;
        }
        if (isDisplayLine(line)) {
            const device = try parseDevice(allocator, line);
            try report.devices.append(allocator, device);
            current = report.devices.items.len - 1;
            continue;
        }
        const index = current orelse continue;
        if (std.mem.startsWith(u8, line, "Kernel driver in use:")) {
            const driver = std.mem.trim(u8, line[21..], " \t");
            try replaceString(allocator, &report.devices.items[index].driver, driver);
        } else if (std.mem.startsWith(u8, line, "Kernel modules:") and report.devices.items[index].driver.len == 0) {
            const driver = std.mem.trim(u8, line[15..], " \t");
            try replaceString(allocator, &report.devices.items[index].driver, driver);
        }
    }
    return report;
}

pub fn recommendedPlan(allocator: Allocator, devices: []const Device) !Plan {
    var plan = Plan{ .packages = .empty };
    errdefer plan.deinit(allocator);

    for (devices) |device| {
        switch (device.vendor) {
            .amd => {
                plan.has_amd = true;
                try appendPackage(allocator, &plan.packages, "mesa");
                try appendPackage(allocator, &plan.packages, "vulkan-radeon");
                try appendPackage(allocator, &plan.packages, "lib32-mesa");
                try appendPackage(allocator, &plan.packages, "lib32-vulkan-radeon");
                try appendPackage(allocator, &plan.packages, "linux-firmware-amdgpu");
            },
            .intel => {
                plan.has_intel = true;
                try appendPackage(allocator, &plan.packages, "mesa");
                try appendPackage(allocator, &plan.packages, "vulkan-intel");
                try appendPackage(allocator, &plan.packages, "lib32-mesa");
                try appendPackage(allocator, &plan.packages, "lib32-vulkan-intel");
                try appendPackage(allocator, &plan.packages, "intel-media-driver");
            },
            .nvidia => {
                plan.has_nvidia = true;
                try appendPackage(allocator, &plan.packages, "nvidia-open-dkms");
                try appendPackage(allocator, &plan.packages, "nvidia-utils");
                try appendPackage(allocator, &plan.packages, "nvidia-utils-dinit");
                try appendPackage(allocator, &plan.packages, "lib32-nvidia-utils");
            },
            .unknown => {},
        }
    }
    return plan;
}

pub fn formatReport(allocator: Allocator, report: *const Report) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();

    if (report.devices.items.len == 0) {
        try output.writer.writeAll("gpu=none\nNo VGA, 3D, or display controller was reported by lspci.\n");
    } else {
        for (report.devices.items) |device| {
            try output.writer.print("gpu={s} address={s} pci={s} driver={s} name={s}\n", .{
                device.vendor.label(),
                device.address,
                device.pci_id,
                if (device.driver.len > 0) device.driver else "none",
                device.name,
            });
        }
    }

    var plan = try recommendedPlan(allocator, report.devices.items);
    defer plan.deinit(allocator);
    if (plan.isEmpty()) {
        try output.writer.writeAll("driver-plan=unsupported\n");
    } else {
        try output.writer.writeAll("driver-plan=Artix pacman packages\npackages=");
        for (plan.packages.items, 0..) |package, index| {
            if (index != 0) try output.writer.writeAll(",");
            try output.writer.writeAll(package);
        }
        try output.writer.writeAll("\n");
        if (plan.has_nvidia) {
            try output.writer.writeAll("warning=NVIDIA open DKMS is selected for modern GPUs; legacy cards may need the matching nvidia-580xx package family.\n");
        }
        try output.writer.writeAll("reboot=required-after-kernel-driver-change\n");
    }
    return output.toOwnedSlice();
}

pub fn install(allocator: Allocator, io: std.Io, plan: *const Plan) !dinit.CommandResult {
    if (plan.isEmpty()) return error.UnsupportedHardware;

    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    try argv.appendSlice(allocator, &.{ "pacman", "--needed", "--noconfirm", "-S" });
    try argv.appendSlice(allocator, plan.packages.items);

    var result = try runChild(allocator, io, argv.items);
    if (!result.success and permissionFailure(result.error_output)) {
        result.deinit(allocator);
        argv.clearRetainingCapacity();
        try argv.appendSlice(allocator, &.{ "pkexec", "pacman", "--needed", "--noconfirm", "-S" });
        try argv.appendSlice(allocator, plan.packages.items);
        return runChild(allocator, io, argv.items);
    }
    return result;
}

fn parseDevice(allocator: Allocator, line: []const u8) !Device {
    const address_end = std.mem.indexOfScalar(u8, line, ' ') orelse return error.InvalidPciLine;
    const class_end = std.mem.indexOf(u8, line, "]: ") orelse return error.InvalidPciLine;
    const name_start = class_end + 3;
    const rest = line[name_start..];
    const name_end = std.mem.indexOf(u8, rest, " [") orelse rest.len;
    const name = std.mem.trim(u8, rest[0..name_end], " ");
    const pci = pciIdentifier(line);
    const vendor = if (pci.vendor_id) |vendor_id| vendorFromId(vendor_id) else vendorFromName(name);
    return .{
        .vendor = vendor,
        .address = try allocator.dupe(u8, line[0..address_end]),
        .pci_id = try allocator.dupe(u8, pci.text),
        .name = try allocator.dupe(u8, name),
        .driver = try allocator.dupe(u8, ""),
    };
}

const PciIdentifier = struct {
    vendor_id: ?u16,
    text: []const u8,
};

fn pciIdentifier(line: []const u8) PciIdentifier {
    var index: usize = 0;
    while (std.mem.indexOfScalarPos(u8, line, index, '[')) |open| {
        if (open + 11 <= line.len and line[open + 5] == ':' and line[open + 10] == ']') {
            const vendor = parseHex(line[open + 1 .. open + 5]) catch {
                index = open + 1;
                continue;
            };
            _ = parseHex(line[open + 6 .. open + 10]) catch {
                index = open + 1;
                continue;
            };
            return .{ .vendor_id = vendor, .text = line[open + 1 .. open + 10] };
        }
        index = open + 1;
    }
    return .{ .vendor_id = null, .text = "unknown" };
}

fn parseHex(text: []const u8) !u16 {
    if (text.len != 4) return error.InvalidHex;
    var value: u16 = 0;
    for (text) |char| {
        const digit: u16 = switch (char) {
            '0'...'9' => char - '0',
            'a'...'f' => char - 'a' + 10,
            'A'...'F' => char - 'A' + 10,
            else => return error.InvalidHex,
        };
        value = value * 16 + digit;
    }
    return value;
}

fn vendorFromId(id: u16) Vendor {
    return switch (id) {
        0x1002 => .amd,
        0x8086 => .intel,
        0x10de => .nvidia,
        else => .unknown,
    };
}

fn vendorFromName(name: []const u8) Vendor {
    if (std.mem.indexOf(u8, name, "NVIDIA") != null) return .nvidia;
    if (std.mem.indexOf(u8, name, "Intel") != null) return .intel;
    if (std.mem.indexOf(u8, name, "AMD") != null or std.mem.indexOf(u8, name, "Advanced Micro Devices") != null) return .amd;
    return .unknown;
}

fn isDisplayLine(line: []const u8) bool {
    return std.mem.indexOf(u8, line, "VGA compatible controller") != null or
        std.mem.indexOf(u8, line, "3D controller") != null or
        std.mem.indexOf(u8, line, "Display controller") != null;
}

fn replaceString(allocator: Allocator, target: *[]u8, value: []const u8) !void {
    const copy = try allocator.dupe(u8, value);
    allocator.free(target.*);
    target.* = copy;
}

fn appendPackage(allocator: Allocator, list: *std.ArrayList([]const u8), package: []const u8) !void {
    for (list.items) |existing| {
        if (std.mem.eql(u8, existing, package)) return;
    }
    try list.append(allocator, package);
}

fn runChild(allocator: Allocator, io: std.Io, argv: []const []const u8) !dinit.CommandResult {
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

test "parses AMD and NVIDIA display controllers" {
    const fixture =
        "00:02.0 VGA compatible controller [0300]: Intel Corporation UHD Graphics [8086:9a49] (rev 01)\n" ++
        "\tKernel driver in use: i915\n" ++
        "01:00.0 3D controller [0302]: NVIDIA Corporation Device [10de:25a9] (rev a1)\n" ++
        "\tKernel modules: nouveau, nvidia_drm\n";
    var report = try parseLspci(std.testing.allocator, fixture);
    defer report.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), report.devices.items.len);
    try std.testing.expectEqual(Vendor.intel, report.devices.items[0].vendor);
    try std.testing.expectEqualStrings("i915", report.devices.items[0].driver);
    try std.testing.expectEqual(Vendor.nvidia, report.devices.items[1].vendor);
    try std.testing.expectEqualStrings("nouveau, nvidia_drm", report.devices.items[1].driver);
}

test "recommended plan merges hybrid GPU packages without duplicates" {
    const devices = [_]Device{
        .{ .vendor = .amd, .address = "00:00.0", .pci_id = "1002:164e", .name = "AMD", .driver = "amdgpu" },
        .{ .vendor = .nvidia, .address = "01:00.0", .pci_id = "10de:25a9", .name = "NVIDIA", .driver = "nouveau" },
    };
    var plan = try recommendedPlan(std.testing.allocator, &devices);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.has_amd);
    try std.testing.expect(plan.has_nvidia);
    try std.testing.expectEqual(@as(usize, 9), plan.packages.items.len);
    try std.testing.expectEqualStrings("nvidia-open-dkms", plan.packages.items[5]);
}

test "unknown controllers produce no install plan" {
    const devices = [_]Device{
        .{ .vendor = .unknown, .address = "02:00.0", .pci_id = "1234:5678", .name = "Vendor", .driver = "" },
    };
    var plan = try recommendedPlan(std.testing.allocator, &devices);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.isEmpty());
}
