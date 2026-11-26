// SPDX-FileCopyrightText: 2026 DINX Contributors
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const c_translate = b.addTranslateC(.{
        .root_source_file = b.path("src/gtk.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const c_include_paths = [_][]const u8{
        "/usr/include/gtk4-layer-shell",
        "/usr/include/astal-apps",
        "/usr/include/gtk-4.0",
        "/usr/include/gio-unix-2.0",
        "/usr/include/pango-1.0",
        "/usr/include/harfbuzz",
        "/usr/include/gdk-pixbuf-2.0",
        "/usr/include/cairo",
        "/usr/include/freetype2",
        "/usr/include/libpng16",
        "/usr/include/pixman-1",
        "/usr/include/graphene-1.0",
        "/usr/lib/graphene-1.0/include",
        "/usr/include/fribidi",
        "/usr/include/libmount",
        "/usr/include/blkid",
        "/usr/include/glib-2.0",
        "/usr/lib/glib-2.0/include",
        "/usr/include/sysprof-6",
    };
    for (c_include_paths) |path| c_translate.addIncludePath(.{ .cwd_relative = path });
    const c_module = c_translate.createModule();
    const module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    module.addImport("c", c_module);
    const exe = b.addExecutable(.{ .name = "redbean", .root_module = module });
    exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/astal" });
    exe.root_module.linkSystemLibrary("gtk4", .{});
    exe.root_module.linkSystemLibrary("gtk4-layer-shell", .{});
    exe.root_module.linkSystemLibrary("astal-apps", .{});
    exe.root_module.linkSystemLibrary("astal-river", .{});
    exe.root_module.linkSystemLibrary("astal-wireplumber", .{});
    exe.root_module.linkSystemLibrary("astal-notifd", .{});
    exe.root_module.linkSystemLibrary("astal-tray", .{});
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the Redbean shell");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.addPassthruArgs();
    run_step.dependOn(&run_cmd.step);
}
