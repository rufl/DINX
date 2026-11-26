// SPDX-FileCopyrightText: 2026 DINX Contributors
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");
const c = @import("c");

const allocator = std.heap.c_allocator;
const log = std.log.scoped(.dinx_dock);

/// GTK4 derives the Wayland app id and the window class from the program name
/// for components that run without a GtkApplication, so prgname carries the id.
const app_id = "com.dinx.Dock";
const app_name = "DINX Dock";
const shell_namespace = "dinx-dock";
const css_class = "dinx-dock-button";
const lock_name = "dinx-dock.lock";
const config_limit: usize = 64 * 1024;
const edge_margin: c_int = 4;
const box_spacing: c_int = 6;
const sighup: c_int = 1;
/// Fallback when appearance.json is absent, unreadable or malformed.
const default_edge: Edge = .left;

const css =
    \\button.dinx-dock-button { border-radius: 10px; padding: 6px; }
    \\button.dinx-dock-button.running { background-color: color-mix(in srgb, currentColor 20%, transparent); box-shadow: inset 0 -3px 0 currentColor; }
    \\
;

const Edge = enum {
    none,
    left,
    right,
    bottom,

    fn parse(value: ?[]const u8) Edge {
        const text = value orelse return default_edge;
        if (std.mem.eql(u8, text, "none")) return .none;
        if (std.mem.eql(u8, text, "left")) return .left;
        if (std.mem.eql(u8, text, "right")) return .right;
        if (std.mem.eql(u8, text, "bottom")) return .bottom;
        return default_edge;
    }

    fn orientation(self: Edge) c.GtkOrientation {
        return switch (self) {
            .left, .right => c.GTK_ORIENTATION_VERTICAL,
            .none, .bottom => c.GTK_ORIENTATION_HORIZONTAL,
        };
    }

    /// The anchored edges of the strip: the configured edge plus the two cross
    /// edges, which stretch it along the screen. The opposite edge stays
    /// unanchored so the surface keeps its natural thickness.
    fn anchors(self: Edge) [3]c.GtkLayerShellEdge {
        return switch (self) {
            .left => .{ c.GTK_LAYER_SHELL_EDGE_LEFT, c.GTK_LAYER_SHELL_EDGE_TOP, c.GTK_LAYER_SHELL_EDGE_BOTTOM },
            .right => .{ c.GTK_LAYER_SHELL_EDGE_RIGHT, c.GTK_LAYER_SHELL_EDGE_TOP, c.GTK_LAYER_SHELL_EDGE_BOTTOM },
            .bottom => .{ c.GTK_LAYER_SHELL_EDGE_BOTTOM, c.GTK_LAYER_SHELL_EDGE_LEFT, c.GTK_LAYER_SHELL_EDGE_RIGHT },
            .none => unreachable,
        };
    }
};

const Config = struct {
    version: ?i64 = null,
    dock: ?[]const u8 = null,
    favorites: ?[]const []const u8 = null,
};

/// The compiled list is the safe default. `appearance.json` may replace it
/// with validated desktop-entry ids, preserving the rest of the first-run
/// configuration.
const Favorite = struct {
    desktop_id: [:0]const u8,
    fallback_icon: [*:0]const u8,
};

const default_favorites = [_]Favorite{
    .{ .desktop_id = "org.dinx.Deetty.desktop", .fallback_icon = "utilities-terminal" },
    .{ .desktop_id = "pcmanfm.desktop", .fallback_icon = "system-file-manager" },
    .{ .desktop_id = "firefox.desktop", .fallback_icon = "web-browser" },
    .{ .desktop_id = "org.dinx.Dintor.desktop", .fallback_icon = "text-editor" },
    .{ .desktop_id = "octopi.desktop", .fallback_icon = "system-software-install" },
    .{ .desktop_id = "dinxpanel.desktop", .fallback_icon = "org.dinx.DinxPanel" },
};

const max_favorites = 16;

const Slot = struct {
    favorite: usize,
    info: ?*c.GAppInfo = null,
    running: bool = false,
};

var active_favorites: [max_favorites]Favorite = undefined;
var active_favorite_count: usize = 0;
var owned_favorite_ids: [max_favorites][:0]u8 = undefined;
var owned_favorite_id_count: usize = 0;
var slots: [max_favorites]Slot = undefined;
var slot_count: usize = 0;
var session_io: std.Io = undefined;
/// Absolute path of appearance.json, kept for the SIGHUP handler.
var appearance_path: []const u8 = "";
var main_loop: ?*c.GMainLoop = null;
var current_edge: Edge = .none;
var dock_window: ?*c.GtkWidget = null;
var destroying: bool = false;
/// Held open for the process lifetime on purpose: closing it would release the
/// single-instance lock, and the kernel releases it even on a crash.
var lock_fd: c_int = -1;

/// Absolute environment values only: a relative or empty base has no safe
/// meaning for a config directory, so the caller treats it as "no dock".
fn envAbsolute(environ: *const std.process.Environ.Map, key: []const u8) ?[]const u8 {
    const value = environ.get(key) orelse return null;
    if (value.len == 0 or value[0] != '/') return null;
    return value;
}

fn configHome(environ: *const std.process.Environ.Map, arena: std.mem.Allocator) []const u8 {
    if (envAbsolute(environ, "XDG_CONFIG_HOME")) |path| return path;
    const home = envAbsolute(environ, "HOME") orelse return "";
    return std.fmt.allocPrint(arena, "{s}/.config", .{home}) catch "";
}

/// Records the absolute appearance.json path. Without an absolute config base
/// there is no file to read, and the empty path then resolves as "config
/// missing", which readEdge answers with the default placement.
fn captureAppearancePath(environ: *const std.process.Environ.Map, arena: std.mem.Allocator) void {
    const home = configHome(environ, arena);
    if (home.len == 0) return;
    appearance_path = std.fmt.allocPrint(arena, "{s}/dinx/appearance.json", .{home}) catch "";
}

fn readConfig() ?Config {
    if (appearance_path.len == 0) return null;
    const text = std.Io.Dir.cwd().readFileAlloc(session_io, appearance_path, allocator, .limited(config_limit)) catch return null;
    defer allocator.free(text);
    return std.json.parseFromSliceLeaky(
        Config,
        allocator,
        text,
        .{ .ignore_unknown_fields = true, .duplicate_field_behavior = .use_last },
    ) catch null;
}

fn validDesktopId(id: []const u8) bool {
    if (id.len < ".desktop".len or id.len > 127 or !std.mem.endsWith(u8, id, ".desktop")) return false;
    for (id) |char| {
        if (!std.ascii.isAlphanumeric(char) and char != '.' and char != '_' and char != '-') return false;
    }
    return true;
}

fn clearLoadedFavorites() void {
    for (owned_favorite_ids[0..owned_favorite_id_count]) |id| allocator.free(id);
    owned_favorite_id_count = 0;
    active_favorite_count = 0;
}

fn appendFavorite(id: []const u8, fallback_icon: [*:0]const u8) void {
    if (active_favorite_count >= active_favorites.len or !validDesktopId(id)) return;
    for (active_favorites[0..active_favorite_count]) |favorite| {
        if (std.mem.eql(u8, favorite.desktop_id, id)) return;
    }
    const owned = allocator.dupeSentinel(u8, id, 0) catch return;
    owned_favorite_ids[owned_favorite_id_count] = owned;
    owned_favorite_id_count += 1;
    active_favorites[active_favorite_count] = .{ .desktop_id = owned, .fallback_icon = fallback_icon };
    active_favorite_count += 1;
}

fn loadFavorites() void {
    clearLoadedFavorites();
    if (readConfig()) |config| {
        if (config.favorites) |configured| {
            for (configured) |id| appendFavorite(id, "application-x-executable");
        }
    }
    if (active_favorite_count == 0) {
        for (default_favorites) |favorite| {
            active_favorites[active_favorite_count] = favorite;
            active_favorite_count += 1;
        }
    }
}


/// Reads `$XDG_CONFIG_HOME/dinx/appearance.json`.
/// The dock is a core shell component, so a missing, unreadable or malformed
/// state file falls back to the default placement instead of removing it: a
/// recovery shell, a hand-deleted file or a truncated write must not silently
/// leave the user without their launchers. Only an explicit `"none"` value,
/// the answer the first-run wizard records when the owner chooses no dock,
/// keeps the window unmapped.
fn readEdge() Edge {
    const config = readConfig() orelse return default_edge;
    return Edge.parse(config.dock);
}

/// Advisory `flock` on `$XDG_RUNTIME_DIR/dinx-dock.lock`. A lock file the dock
/// cannot create or open is no reason to skip the panel, so only a lock held by
/// another process counts as a second instance.
fn otherInstanceHoldsLock(environ: *const std.process.Environ.Map, arena: std.mem.Allocator) bool {
    const dir = envAbsolute(environ, "XDG_RUNTIME_DIR") orelse "/tmp";
    // open() wants a sentinel slice: joinZ is not available in this toolchain,
    // so the terminating byte is written explicitly.
    const raw = std.fmt.allocPrint(arena, "{s}/{s}", .{ dir, lock_name }) catch return false;
    const path = arena.alloc(u8, raw.len + 1) catch return false;
    @memcpy(path[0..raw.len], raw);
    path[raw.len] = 0;
    const fd = c.open(path.ptr, c.O_RDWR | c.O_CREAT | c.O_CLOEXEC, @as(c_int, 0o600));
    if (fd < 0) return false;
    if (c.flock(fd, c.LOCK_EX | c.LOCK_NB) != 0) {
        _ = c.close(fd);
        return true;
    }
    lock_fd = fd;
    return false;
}

/// Missing, hidden or unparsable desktop entries resolve to null and their
/// button is simply left out: the dock never fails because an app is absent.
fn resolveFavorites() void {
    slot_count = 0;
    for (active_favorites[0..active_favorite_count], 0..) |favorite, index| {
        const app_info = c.g_desktop_app_info_new(favorite.desktop_id.ptr) orelse continue;
        slots[slot_count] = .{ .favorite = index, .info = @ptrCast(app_info) };
        slot_count += 1;
    }
}

fn releaseFavorites() void {
    for (slots[0..slot_count]) |*slot| {
        if (slot.info) |info| c.g_object_unref(@ptrCast(info));
        slot.* = .{ .favorite = 0 };
    }
    slot_count = 0;
    clearLoadedFavorites();
}

fn makeButton(slot: *Slot) ?*c.GtkWidget {
    const favorite = active_favorites[slot.favorite];
    const info = slot.info orelse return null;
    const button = c.gtk_button_new() orelse return null;
    c.gtk_widget_add_css_class(button, css_class);
    if (slot.running) c.gtk_widget_add_css_class(button, "running");

    const image = if (c.g_app_info_get_icon(info)) |icon|
        c.gtk_image_new_from_gicon(icon) orelse c.gtk_image_new_from_icon_name(favorite.fallback_icon)
    else
        c.gtk_image_new_from_icon_name(favorite.fallback_icon);
    if (image) |widget| c.gtk_button_set_child(@ptrCast(button), widget);

    // The tooltip is the entry Name resolved by GIO in the current locale,
    // exactly as a desktop menu would show it.
    const tooltip = c.g_app_info_get_display_name(info) orelse favorite.desktop_id.ptr;
    c.gtk_widget_set_tooltip_text(button, tooltip);
    if (slot.running) {
        const running_tooltip = std.fmt.allocPrintSentinel(
            allocator,
            "Running: {s}",
            .{std.mem.span(tooltip)},
            0,
        ) catch null;
        if (running_tooltip) |text| c.gtk_widget_set_tooltip_text(button, text.ptr);
    }

    connect(button, "clicked", &onFavoriteClicked, slot);
    return button;
}

/// Tiny style sheet and nothing else: colours and fonts come from the toolkit
/// theme the session already chose, so the dock never forces a theme here.
fn applyStyle() void {
    const provider = c.gtk_css_provider_new() orelse return;
    defer c.g_object_unref(@ptrCast(provider));
    c.gtk_css_provider_load_from_data(provider, css.ptr, @intCast(css.len));
    const display = c.gdk_display_get_default() orelse return;
    c.gtk_style_context_add_provider_for_display(display, @ptrCast(provider), c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
}

/// Desktop entries do not expose a portable running-state API. Check the
/// resolved executable name without a shell and refresh only when a state
/// changes, so the dock remains stable while an app is open.
fn checkRunningApps() void {
    var changed = false;
    for (slots[0..slot_count]) |*slot| {
        const info = slot.info orelse continue;
        const executable = c.g_app_info_get_executable(info) orelse continue;
        const executable_path = std.mem.span(@as([*:0]const u8, @ptrCast(executable)));
        const executable_name = std.fs.path.basename(executable_path);
        var child = std.process.spawn(session_io, .{
            .argv = &.{ "pgrep", "-x", executable_name },
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .ignore,
        }) catch {
            if (slot.running) {
                slot.running = false;
                changed = true;
            }
            continue;
        };
        const status = child.wait(session_io) catch {
            if (slot.running) {
                slot.running = false;
                changed = true;
            }
            continue;
        };
        const running = status.success();
        if (running != slot.running) {
            slot.running = running;
            changed = true;
        }
    }
    if (changed and dock_window != null) {
        destroyDock();
        buildDock();
    }
}

fn onTimeout(_: ?*anyopaque) callconv(.c) c.gboolean {
    checkRunningApps();
    return 1;
}

fn buildDock() void {
    if (current_edge == .none) return;
    const window = c.gtk_window_new() orelse return;
    c.gtk_window_set_title(@ptrCast(window), app_name);

    const box = c.gtk_box_new(current_edge.orientation(), box_spacing) orelse return;
    c.gtk_widget_set_halign(box, c.GTK_ALIGN_CENTER);
    c.gtk_widget_set_valign(box, c.GTK_ALIGN_CENTER);
    for (slots[0..slot_count]) |*slot| {
        const button = makeButton(slot) orelse continue;
        c.gtk_box_append(@ptrCast(box), button);
    }
    if (c.gtk_widget_get_first_child(box) == null) {
        c.gtk_window_destroy(@ptrCast(window));
        log.warn("no favorite desktop entry resolved; staying hidden", .{});
        return;
    }
    c.gtk_window_set_child(@ptrCast(window), box);

    const gtk_window: *c.GtkWindow = @ptrCast(window);
    c.gtk_layer_init_for_window(gtk_window);
    c.gtk_layer_set_namespace(gtk_window, shell_namespace);
    c.gtk_layer_set_layer(gtk_window, c.GTK_LAYER_SHELL_LAYER_TOP);
    c.gtk_layer_set_keyboard_mode(gtk_window, c.GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND);
    for ([_]c.GtkLayerShellEdge{
        c.GTK_LAYER_SHELL_EDGE_LEFT,
        c.GTK_LAYER_SHELL_EDGE_RIGHT,
        c.GTK_LAYER_SHELL_EDGE_TOP,
        c.GTK_LAYER_SHELL_EDGE_BOTTOM,
    }) |edge| c.gtk_layer_set_margin(gtk_window, edge, edge_margin);
    for (current_edge.anchors()) |edge| c.gtk_layer_set_anchor(gtk_window, edge, 1);
    // kwm and river reserve the dock strip through the automatic exclusive zone.
    c.gtk_layer_auto_exclusive_zone_enable(gtk_window);

    connect(window, "destroy", &onWindowDestroyed, null);
    dock_window = window;
    c.gtk_window_present(@ptrCast(window));
}

fn destroyDock() void {
    const window = dock_window orelse return;
    dock_window = null;
    destroying = true;
    c.gtk_window_destroy(@ptrCast(window));
    destroying = false;
}

fn quitLoop() void {
    if (main_loop) |loop| c.g_main_loop_quit(loop);
}

fn onWindowDestroyed(_: ?*c.GtkWidget, _: ?*anyopaque) callconv(.c) void {
    dock_window = null;
    if (destroying) return;
    // A compositor that drops the layer surface takes the dock with it: exit
    // so the session supervisor, not a dead window, owns the next decision.
    quitLoop();
}

fn onFavoriteClicked(_: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const slot: *Slot = @ptrCast(@alignCast(data orelse return));
    const info = slot.info orelse return;
    var error_: ?*c.GError = null;
    if (c.g_app_info_launch(info, null, null, &error_) == 0) {
        const detail = if (error_) |e| std.mem.span(@as([*:0]const u8, @ptrCast(e.message))) else "launch failed";
        log.warn("cannot launch {s}: {s}", .{ active_favorites[slot.favorite].desktop_id, detail });
    }
    if (error_) |e| c.g_error_free(e);
}

/// The first-run wizard and the dock-control helper signal the dock instead of
/// restarting the session, so placement and favorite changes apply on the fly.
fn onHangup(_: ?*anyopaque) callconv(.c) c.gboolean {
    const next = readEdge();
    destroyDock();
    releaseFavorites();
    current_edge = next;
    if (next == .none) {
        log.info("dock disabled; exiting", .{});
        quitLoop();
        return 0;
    }
    loadFavorites();
    resolveFavorites();
    checkRunningApps();
    buildDock();
    if (dock_window == null) quitLoop();
    return 1;
}

fn connect(instance: anytype, signal: [*:0]const u8, callback: anytype, data: ?*anyopaque) void {
    _ = c.g_signal_connect_data(@ptrCast(instance), signal, @ptrCast(callback), data, null, 0);
}

pub fn main(init: std.process.Init) !void {
    const environ = init.environ_map;
    const arena = init.arena.allocator();
    session_io = init.io;

    // The placement answer is read before GTK opens a display: "no dock" must
    // exit with status 0 even where no compositor exists at all.
    captureAppearancePath(environ, arena);
    current_edge = readEdge();
    if (current_edge == .none) return;

    c.g_set_prgname(app_id);
    c.g_set_application_name(app_name);
    if (c.gtk_init_check() == 0) {
        log.warn("no display available; the dock needs a Wayland session", .{});
        return;
    }
    if (c.gdk_display_get_default() == null or otherInstanceHoldsLock(environ, arena)) {
        log.info("another dinx-dock is already running", .{});
        return;
    }

    loadFavorites();
    resolveFavorites();
    checkRunningApps();
    applyStyle();
    buildDock();
    if (dock_window == null) {
        releaseFavorites();
        return;
    }

    _ = c.g_unix_signal_add(sighup, &onHangup, null);
    _ = c.g_timeout_add_seconds(5, &onTimeout, null);

    const loop = c.g_main_loop_new(null, 0) orelse return error.MainLoopUnavailable;
    main_loop = loop;
    c.g_main_loop_run(loop);
    c.g_main_loop_unref(loop);
    main_loop = null;
    destroyDock();
    releaseFavorites();
    if (lock_fd >= 0) _ = c.close(lock_fd);
}
