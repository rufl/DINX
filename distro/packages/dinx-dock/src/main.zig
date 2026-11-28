// SPDX-FileCopyrightText: 2026 DINX Contributors
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");
const c = @import("c");
const KwmIpc = @import("kwm_ipc.zig");

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
const max_favorites: usize = 16;
const max_task_apps: usize = 64;
const default_icon_size: c_int = 32;
const default_edge_margin: c_int = 8;
const default_box_spacing: c_int = 8;
const sighup: c_int = 1;
/// Fallback when appearance.json is absent, unreadable or malformed.
const default_edge: Edge = .left;

const css =
    \\window.dinx-dock { background: transparent; }
    \\box.dinx-dock-box { background: alpha(@window_bg_color, 0.94); border: 1px solid alpha(@borders, 0.8); border-radius: 16px; padding: 8px; }
    \\button.dinx-dock-button { min-width: 44px; min-height: 44px; border-radius: 12px; padding: 6px; }
    \\button.dinx-dock-button:hover { background: alpha(@accent_bg_color, 0.2); transform: scale(1.14); }
    \\button.dinx-dock-button:active { background: alpha(@accent_bg_color, 0.36); }
    \\button.dinx-dock-button:focus-visible { outline: 2px solid @accent_bg_color; outline-offset: 2px; }
    \\button.dinx-dock-button.activity { box-shadow: inset 0 -3px 0 @accent_bg_color; }
    \\button.dinx-dock-button.running { box-shadow: inset 0 -3px 0 alpha(@accent_bg_color, 0.55); }
    \\button.dinx-dock-button.running.active { box-shadow: inset 0 -3px 0 @accent_bg_color; }
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
    icon_size: ?i64 = null,
    edge_margin: ?i64 = null,
    box_spacing: ?i64 = null,
    show_activity: ?bool = null,
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


const Slot = struct {
    favorite: usize,
    info: ?*c.GAppInfo = null,
    activity: bool = false,
    button: ?*c.GtkWidget = null,
};

const TaskApp = struct {
    app_id: []const u8,
    info: ?*c.GAppInfo,
    favorite: ?usize,
    window_ids: [max_task_apps]u64 = undefined,
    window_count: usize = 0,
    focused_id: u64 = 0,
    focused: bool = false,
    title: []const u8 = "",
    button: ?*c.GtkWidget = null,
};

const CloseAction = struct {
    session_id: u64,
    window_id: u64,
};

var active_favorites: [max_favorites]Favorite = undefined;
var active_favorite_count: usize = 0;
var owned_favorite_ids: [max_favorites][:0]u8 = undefined;
var owned_favorite_id_count: usize = 0;
var slots: [max_favorites]Slot = undefined;
var slot_count: usize = 0;
var icon_size: c_int = default_icon_size;
var edge_margin: c_int = default_edge_margin;
var box_spacing: c_int = default_box_spacing;
var show_activity: bool = true;
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

var kwm_socket_path: [:0]const u8 = "";
var task_snapshot: KwmIpc.Snapshot = undefined;
var task_snapshot_valid: bool = false;
var task_apps: [max_task_apps]TaskApp = undefined;
var task_app_count: usize = 0;
var running_box: ?*c.GtkWidget = null;
var dock_box: ?*c.GtkWidget = null;
var active_close_popover: ?*c.GtkWidget = null;
var close_action: CloseAction = .{ .session_id = 0, .window_id = 0 };

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

fn captureKwmSocketPath(environ: *const std.process.Environ.Map, arena: std.mem.Allocator) void {
    const runtime_dir = envAbsolute(environ, "XDG_RUNTIME_DIR") orelse return;
    const raw = std.fmt.allocPrint(arena, "{s}/dinx-kwm.sock", .{runtime_dir}) catch return;
    kwm_socket_path = arena.dupeSentinel(u8, raw, 0) catch "";
}

fn readConfig() ?std.json.Parsed(Config) {
    if (appearance_path.len == 0) return null;
    const text = std.Io.Dir.cwd().readFileAlloc(session_io, appearance_path, allocator, .limited(config_limit)) catch return null;
    defer allocator.free(text);
    return std.json.parseFromSlice(
        Config,
        allocator,
        text,
        .{ .ignore_unknown_fields = true, .duplicate_field_behavior = .use_last },
    ) catch null;
}
fn boundedSetting(value: ?i64, fallback: c_int, minimum: i64, maximum: i64) c_int {
    const setting = value orelse return fallback;
    return @intCast(@min(maximum, @max(minimum, setting)));
}

fn loadConfig() void {
    icon_size = default_icon_size;
    edge_margin = default_edge_margin;
    box_spacing = default_box_spacing;
    show_activity = true;
    const parsed = readConfig() orelse return;
    defer parsed.deinit();
    icon_size = boundedSetting(parsed.value.icon_size, default_icon_size, 20, 48);
    edge_margin = boundedSetting(parsed.value.edge_margin, default_edge_margin, 0, 32);
    box_spacing = boundedSetting(parsed.value.box_spacing, default_box_spacing, 0, 16);
    show_activity = parsed.value.show_activity orelse true;
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
    if (readConfig()) |parsed| {
        defer parsed.deinit();
        if (parsed.value.favorites) |configured| {
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
    if (readConfig()) |parsed| {
        defer parsed.deinit();
        return Edge.parse(parsed.value.dock);
    }
    return default_edge;
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

fn removeClosePopover() void {
    const popover = active_close_popover orelse return;
    active_close_popover = null;
    _ = c.g_signal_handlers_disconnect_matched(@as(c.gpointer, @ptrCast(popover)), c.G_SIGNAL_MATCH_DATA, 0, 0, null, null, @as(c.gpointer, null));
    c.gtk_widget_unparent(popover);
}

fn clearRunningButtons() void {
    removeClosePopover();
    const box = running_box orelse return;
    var child = c.gtk_widget_get_first_child(box);
    while (child) |widget| {
        const next = c.gtk_widget_get_next_sibling(widget);
        c.gtk_box_remove(@ptrCast(box), widget);
        child = next;
    }

}
fn clearTaskApps() void {
    for (task_apps[0..task_app_count]) |*task| {
        if (task.info) |info| c.g_object_unref(@ptrCast(info));
        task.* = undefined;
    }
    task_app_count = 0;
}

fn baseDesktopId(id: []const u8) []const u8 {
    return if (std.mem.endsWith(u8, id, ".desktop")) id[0 .. id.len - ".desktop".len] else id;
}

fn appIdMatches(left: []const u8, right: []const u8) bool {
    return std.ascii.eqlIgnoreCase(baseDesktopId(left), baseDesktopId(right));
}

fn appInfoMatches(info: *c.GAppInfo, identifier: []const u8) bool {
    if (c.g_app_info_get_id(info)) |id| {
        if (appIdMatches(std.mem.span(id), identifier)) return true;
    }
    if (c.g_desktop_app_info_get_string(@ptrCast(info), "StartupWMClass")) |class_name| {
        const matches = std.ascii.eqlIgnoreCase(std.mem.span(class_name), identifier);
        c.g_free(class_name);
        if (matches) return true;
    }
    return false;
}

fn resolveTaskInfo(identifier: []const u8) ?*c.GAppInfo {
    if (identifier.len == 0) return null;
    const apps = c.g_app_info_get_all() orelse return null;
    var selected: ?*c.GAppInfo = null;
    var item: ?*c.GList = apps;
    while (item) |node| {
        if (node.data) |raw| {
            const info: *c.GAppInfo = @ptrCast(raw);
            if (selected == null and appInfoMatches(info, identifier)) {
                selected = @ptrCast(c.g_object_ref(@ptrCast(info)));
            }
            c.g_object_unref(@ptrCast(info));
        }
        item = node.next;
    }
    c.g_list_free(apps);
    return selected;
}

fn favoriteForTask(info: ?*c.GAppInfo, identifier: []const u8) ?usize {
    for (active_favorites[0..active_favorite_count], 0..) |favorite, index| {
        var installed = false;
        for (slots[0..slot_count]) |slot| {
            if (slot.favorite == index) installed = true;
        }
        if (!installed) continue;
        if (appIdMatches(favorite.desktop_id, identifier)) return index;
        if (info) |app| {
            if (c.g_app_info_get_id(app)) |desktop_id| {
                if (std.mem.eql(u8, std.mem.span(desktop_id), favorite.desktop_id)) return index;
            }
        }
    }
    return null;
}

fn taskForFavorite(favorite: usize) ?*TaskApp {
    for (task_apps[0..task_app_count]) |*task| {
        if (task.favorite == favorite) return task;
    }
    return null;
}

fn setWidgetClass(widget: *c.GtkWidget, class_name: [*:0]const u8, enabled: bool) void {
    if (enabled) {
        c.gtk_widget_add_css_class(widget, class_name);
    } else {
        c.gtk_widget_remove_css_class(widget, class_name);
    }
}

fn updateFavoriteMarkers() void {
    for (slots[0..slot_count]) |*slot| {
        const button = slot.button orelse continue;
        const task = taskForFavorite(slot.favorite);
        setWidgetClass(button, "running", task != null);
        setWidgetClass(button, "active", if (task) |running| running.focused else false);
    }
}

fn rebuildTaskApps() void {
    clearRunningButtons();
    clearTaskApps();
    if (!task_snapshot_valid) return;

    for (task_snapshot.windows[0..task_snapshot.count]) |*window| {
        const identifier = window.appId();
        var task: ?*TaskApp = null;
        for (task_apps[0..task_app_count]) |*candidate| {
            const matches = if (identifier.len == 0)
                candidate.app_id.len == 0 and candidate.window_count > 0 and candidate.window_ids[0] == window.id
            else
                std.mem.eql(u8, candidate.app_id, identifier);
            if (matches) {
                task = candidate;
                break;
            }
        }
        if (task == null) {
            if (task_app_count == task_apps.len) continue;
            const info = resolveTaskInfo(identifier);
            task_apps[task_app_count] = .{
                .app_id = identifier,
                .info = info,
                .favorite = favoriteForTask(info, identifier),
            };
            task = &task_apps[task_app_count];
            task_app_count += 1;
        }
        const group = task.?;
        if (group.window_count == group.window_ids.len) continue;
        const first_window = group.window_count == 0;
        group.window_ids[group.window_count] = window.id;
        group.window_count += 1;
        if (first_window) {
            group.focused_id = window.id;
            group.title = window.titleText();
        }
        if (window.focused) {
            group.focused = true;
            group.focused_id = window.id;
            group.title = window.titleText();
        }
    }

    updateFavoriteMarkers();
    const box = running_box orelse return;
    var dynamic_count: usize = 0;
    for (task_apps[0..task_app_count]) |*task| {
        if (task.favorite != null) continue;
        const button = makeTaskButton(task) orelse continue;
        c.gtk_box_append(@ptrCast(box), button);
        task.button = button;
        dynamic_count += 1;
    }
    if (dock_box) |root| {
        if (dynamic_count > 0 and c.gtk_widget_get_parent(box) == null) {
            c.gtk_box_append(@ptrCast(root), box);
        } else if (dynamic_count == 0 and c.gtk_widget_get_parent(box) != null) {
            c.gtk_box_remove(@ptrCast(root), box);
        }
    }
}

fn sameSnapshot(left: *const KwmIpc.Snapshot, right: *const KwmIpc.Snapshot) bool {
    if (left.session_id != right.session_id or left.count != right.count) return false;
    for (left.windows[0..left.count], right.windows[0..right.count]) |a, b| {
        if (a.id != b.id or a.focused != b.focused or
            !std.mem.eql(u8, a.appId(), b.appId()) or
            !std.mem.eql(u8, a.titleText(), b.titleText()))
        {
            return false;
        }
    }
    return true;
}

fn refreshTaskSnapshot() void {
    if (kwm_socket_path.len == 0) return;
    const next = KwmIpc.query(kwm_socket_path) catch return;
    if (task_snapshot_valid and sameSnapshot(&task_snapshot, &next)) return;
    task_snapshot = next;
    task_snapshot_valid = true;
    rebuildTaskApps();
}

fn onKwmPoll(_: ?*anyopaque) callconv(.c) c.gboolean {
    refreshTaskSnapshot();
    return 1;
}

fn makeTaskButton(task: *TaskApp) ?*c.GtkWidget {
    const button = c.gtk_button_new() orelse return null;
    c.gtk_widget_add_css_class(button, css_class);
    c.gtk_widget_add_css_class(button, "running");
    if (task.focused) c.gtk_widget_add_css_class(button, "active");

    const info = task.info;
    const image = if (info) |app_info| blk: {
        const icon = c.g_app_info_get_icon(app_info) orelse break :blk c.gtk_image_new_from_icon_name("application-x-executable");
        break :blk c.gtk_image_new_from_gicon(icon) orelse c.gtk_image_new_from_icon_name("application-x-executable");
    } else c.gtk_image_new_from_icon_name("application-x-executable");
    if (image) |widget| {
        c.gtk_image_set_pixel_size(@ptrCast(widget), icon_size);
        c.gtk_button_set_child(@ptrCast(button), widget);
    }
    var fallback_tooltip: [*:0]const u8 = "Running application";
    if (info) |app_info| {
        if (c.g_app_info_get_display_name(app_info)) |name| fallback_tooltip = name;
    }
    const owned_title: ?[:0]u8 = if (task.title.len > 0) allocator.dupeSentinel(u8, task.title, 0) catch null else null;
    defer if (owned_title) |title| allocator.free(title);
    c.gtk_widget_set_tooltip_text(button, if (owned_title) |title| title.ptr else fallback_tooltip);
    connect(button, "clicked", &onTaskClicked, task);
    addRightClick(button, &onTaskRightClick, task);
    return button;
}

fn addRightClick(button: *c.GtkWidget, callback: anytype, data: ?*anyopaque) void {
    const gesture = c.gtk_gesture_click_new() orelse return;
    c.gtk_gesture_single_set_button(@ptrCast(gesture), 3);
    connect(gesture, "pressed", callback, data);
    c.gtk_widget_add_controller(button, @ptrCast(gesture));
}

fn showCloseMenu(parent: *c.GtkWidget, task: *TaskApp) void {
    if (task.window_count == 0 or kwm_socket_path.len == 0) return;
    removeClosePopover();

    close_action = .{
        .session_id = task_snapshot.session_id,
        .window_id = if (task.focused_id != 0) task.focused_id else task.window_ids[task.window_count - 1],
    };
    const popover = c.gtk_popover_new() orelse return;
    const menu = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse return;
    const close_button = c.gtk_button_new_with_label("Close window") orelse return;
    c.gtk_box_append(@ptrCast(menu), close_button);
    c.gtk_popover_set_child(@ptrCast(popover), menu);
    c.gtk_widget_set_parent(popover, parent);
    connect(popover, "closed", &onCloseMenuClosed, null);
    connect(close_button, "clicked", &onCloseClicked, null);
    active_close_popover = popover;
    c.gtk_popover_popup(@ptrCast(popover));
}

fn onTaskRightClick(_: ?*c.GtkGestureClick, _: c_int, _: f64, _: f64, data: ?*anyopaque) callconv(.c) void {
    const task: *TaskApp = @ptrCast(@alignCast(data orelse return));
    const button = task.button orelse return;
    showCloseMenu(button, task);
}

fn onFavoriteRightClick(_: ?*c.GtkGestureClick, _: c_int, _: f64, _: f64, data: ?*anyopaque) callconv(.c) void {
    const slot: *Slot = @ptrCast(@alignCast(data orelse return));
    const task = taskForFavorite(slot.favorite) orelse return;
    const button = slot.button orelse return;
    showCloseMenu(button, task);
}

fn onCloseClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    KwmIpc.closeWindow(kwm_socket_path, close_action.session_id, close_action.window_id) catch |err| {
        log.warn("cannot request graceful window close: {}", .{err});
    };
    if (active_close_popover) |popover| c.gtk_popover_popdown(@ptrCast(popover));
}

fn onCloseMenuClosed(popover: ?*c.GtkPopover, _: ?*anyopaque) callconv(.c) void {
    const widget: *c.GtkWidget = @ptrCast(popover orelse return);
    if (active_close_popover == widget) active_close_popover = null;
    c.gtk_widget_unparent(widget);
}

fn onTaskClicked(_: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const task: *TaskApp = @ptrCast(@alignCast(data orelse return));
    if (task.focused_id == 0) return;
    KwmIpc.focus(kwm_socket_path, task_snapshot.session_id, task.focused_id) catch |err| {
        log.warn("cannot focus DINX window: {}", .{err});
    };
}

fn makeButton(slot: *Slot) ?*c.GtkWidget {
    const favorite = active_favorites[slot.favorite];
    const info = slot.info orelse return null;
    const button = c.gtk_button_new() orelse return null;
    c.gtk_widget_add_css_class(button, css_class);
    slot.button = button;
    if (slot.activity and show_activity) c.gtk_widget_add_css_class(button, "activity");

    const image = if (c.g_app_info_get_icon(info)) |icon|
        c.gtk_image_new_from_gicon(icon) orelse c.gtk_image_new_from_icon_name(favorite.fallback_icon)
    else
        c.gtk_image_new_from_icon_name(favorite.fallback_icon);
    if (image) |widget| {
        c.gtk_image_set_pixel_size(@ptrCast(widget), icon_size);
        c.gtk_button_set_child(@ptrCast(button), widget);
    }

    const tooltip = c.g_app_info_get_display_name(info) orelse favorite.desktop_id.ptr;
    c.gtk_widget_set_tooltip_text(button, tooltip);
    connect(button, "clicked", &onFavoriteClicked, slot);
    addRightClick(button, &onFavoriteRightClick, slot);
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

fn buildDock() void {
    if (current_edge == .none) return;
    const window = c.gtk_window_new() orelse return;
    c.gtk_window_set_title(@ptrCast(window), app_name);
    c.gtk_widget_add_css_class(window, "dinx-dock");
    c.gtk_window_set_decorated(@ptrCast(window), 0);
    c.gtk_window_set_resizable(@ptrCast(window), 0);

    const box = c.gtk_box_new(current_edge.orientation(), box_spacing) orelse return;
    c.gtk_widget_add_css_class(box, "dinx-dock-box");
    c.gtk_widget_set_halign(box, c.GTK_ALIGN_CENTER);
    c.gtk_widget_set_valign(box, c.GTK_ALIGN_CENTER);
    dock_box = box;
    for (slots[0..slot_count]) |*slot| {
        const button = makeButton(slot) orelse continue;
        c.gtk_box_append(@ptrCast(box), button);
    }

    const running = c.gtk_box_new(current_edge.orientation(), box_spacing) orelse return;
    running_box = running;
    refreshTaskSnapshot();
    if (task_snapshot_valid) rebuildTaskApps();
    if (c.gtk_widget_get_first_child(box) == null and c.gtk_widget_get_first_child(running) == null) {
        c.gtk_window_destroy(@ptrCast(window));
        dock_box = null;
        running_box = null;
        log.warn("no favorite desktop entry or running window resolved; staying hidden", .{});
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
    c.gtk_layer_auto_exclusive_zone_enable(gtk_window);

    connect(window, "destroy", &onWindowDestroyed, null);
    dock_window = window;
    c.gtk_window_present(@ptrCast(window));
}

fn destroyDock() void {
    removeClosePopover();
    const window = dock_window orelse return;
    dock_window = null;
    dock_box = null;
    running_box = null;
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

fn onFavoriteClicked(button: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const slot: *Slot = @ptrCast(@alignCast(data orelse return));
    refreshTaskSnapshot();
    if (taskForFavorite(slot.favorite)) |task| {
        if (task.focused_id != 0) {
            KwmIpc.focus(kwm_socket_path, task_snapshot.session_id, task.focused_id) catch |err| {
                log.warn("cannot focus DINX window: {}", .{err});
            };
            return;
        }
    }
    const info = slot.info orelse return;
    var error_: ?*c.GError = null;
    if (c.g_app_info_launch(info, null, null, &error_) != 0) {
        slot.activity = true;
        if (show_activity) {
            if (button) |widget| c.gtk_widget_add_css_class(@ptrCast(widget), "activity");
        }
    } else {
        const detail = if (error_) |e| std.mem.span(@as([*:0]const u8, @ptrCast(e.message))) else "launch failed";
        log.warn("cannot launch {s}: {s}", .{ active_favorites[slot.favorite].desktop_id, detail });
    }
    if (error_) |e| c.g_error_free(e);
}


/// The first-run wizard and the dock-control helper signal the dock instead of
/// restarting the session, so placement and favorite changes apply on the fly.
fn onHangup(_: ?*anyopaque) callconv(.c) c.gboolean {
    loadConfig();
    const next = readEdge();
    destroyDock();
    clearTaskApps();
    releaseFavorites();
    current_edge = next;
    if (next == .none) {
        log.info("dock disabled; exiting", .{});
        quitLoop();
        return 0;
    }
    loadFavorites();
    resolveFavorites();
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

    captureAppearancePath(environ, arena);
    captureKwmSocketPath(environ, arena);
    loadConfig();
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
    applyStyle();
    refreshTaskSnapshot();
    buildDock();
    if (dock_window == null) {
        clearTaskApps();
        releaseFavorites();
        return;
    }

    _ = c.g_unix_signal_add(sighup, &onHangup, null);
    _ = c.g_timeout_add_seconds(1, &onKwmPoll, null);
    const loop = c.g_main_loop_new(null, 0) orelse return error.MainLoopUnavailable;
    main_loop = loop;
    c.g_main_loop_run(loop);
    c.g_main_loop_unref(loop);
    main_loop = null;
    destroyDock();
    clearTaskApps();
    releaseFavorites();
    if (lock_fd >= 0) _ = c.close(lock_fd);
}