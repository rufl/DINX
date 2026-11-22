// SPDX-FileCopyrightText: 2026 DINX Contributors
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");
const c = @import("c");

const allocator = std.heap.c_allocator;
fn dupSentinel(value: []const u8) ![:0]u8 {
    return std.fmt.allocPrintSentinel(allocator, "{s}", .{value}, 0);
}

const log = std.log.scoped(.redbean);

const app_id = "com.dinx.Redbean";
const app_name = "Redbean";
const lock_name = "redbean.lock";
const config_limit: usize = 16 * 1024;
const panel_height: c_int = 56;

const css =
    \\window.redbean-panel {
    \\  background-color: transparent;
    \\}
    \\window.redbean-menu {
    \\  background-color: transparent;
    \\}
    \\.redbean-surface {
    \\  background-color: alpha(@window_bg_color, 0.98);
    \\  color: @theme_fg_color;
    \\  border: 1px solid @borders;
    \\  border-radius: 14px;
    \\  padding: 14px;
    \\}
    \\.redbean-panel-surface {
    \\  background-color: alpha(@window_bg_color, 0.96);
    \\  color: @theme_fg_color;
    \\  border-top: 1px solid @borders;
    \\  padding: 7px 12px;
    \\}
    \\.redbean-title {
    \\  font-weight: 700;
    \\  font-size: 18px;
    \\}
    \\.redbean-caption {
    \\  color: @insensitive_fg_color;
    \\  font-size: 12px;
    \\}
    \\.redbean-search {
    \\  min-height: 42px;
    \\  border-radius: 10px;
    \\  margin-top: 10px;
    \\  margin-bottom: 12px;
    \\}
    \\.redbean-sidebar {
    \\  background-color: alpha(@card_bg_color, 0.55);
    \\  border-radius: 10px;
    \\  padding: 8px;
    \\}
    \\.redbean-category {
    \\  min-height: 40px;
    \\  padding: 4px 10px;
    \\  text-align: left;
    \\}
    \\.redbean-list {
    \\  background-color: transparent;
    \\  padding: 0 0 0 12px;
    \\}
    \\.redbean-flow-list {
    \\  background-color: transparent;
    \\  padding: 0;
    \\}
    \\.redbean-app {
    \\  min-height: 62px;
    \\  margin-bottom: 6px;
    \\  padding: 8px 10px;
    \\  border-radius: 10px;
    \\  text-align: left;
    \\.redbean-app-row {
    \\  margin-bottom: 6px;
    \\}
    \\.redbean-pin {
    \\  min-width: 64px;
    \\  min-height: 62px;
    \\}
    \\.redbean-notification {
    \\  padding: 8px 10px;
    \\  border-radius: 10px;
    \\  text-align: left;
    \\}
    \\.redbean-app-description {
    \\  color: @insensitive_fg_color;
    \\  font-size: 12px;
    \\}
    \\.redbean-footer {
    \\  min-height: 40px;
    \\  padding: 4px 10px;
    \\}
    \\.redbean-start {
    \\  min-height: 40px;
    \\  padding: 4px 16px;
    \\  font-weight: 700;
    \\}
    \\.redbean-shortcut {
    \\  min-height: 40px;
    \\  padding: 4px 12px;
    \\}
    \\.redbean-mode {
    \\  min-height: 40px;
    \\  padding: 4px 12px;
    \\}
    \\.redbean-status {
    \\  color: @insensitive_fg_color;
    \\  padding: 0 8px;
    \\}
    \\button:focus-visible,
    \\entry:focus-visible {
    \\  outline: 2px solid @theme_selected_bg_color;
    \\  outline-offset: 2px;
    \\}
    \\button.redbean-start,
    \\button.redbean-mode {
    \\  background-color: @theme_selected_bg_color;
    \\  color: @theme_selected_fg_color;
    \\}
    \\button.redbean-start:hover,
    \\button.redbean-mode:hover {
    \\  background-color: alpha(@theme_selected_bg_color, 0.86);
    \\}
    \\button.redbean-category:hover,
    \\button.redbean-app:hover {
    \\  background-color: alpha(@theme_selected_bg_color, 0.12);
    \\}
    \\.redbean-header {
    \\  padding-bottom: 2px;
    \\}
    \\.redbean-hint {
    \\  margin-top: -4px;
    \\  margin-bottom: 4px;
    \\}
;

const Mode = enum { windows, flow };
const Category = enum { all, internet, office, graphics, system, utilities };

const Config = struct {
    version: ?i64 = null,
    mode: ?[]const u8 = null,
    pinned: ?[][]const u8 = null,
};

const default_pins = [_][:0]const u8{
    "org.dinx.Deetty.desktop",
    "pcmanfm.desktop",
    "firefox.desktop",
};

const SettingItem = struct {
    id: [*:0]const u8,
    label: [*:0]const u8,
    description: [*:0]const u8,
};

const settings_items = [_]SettingItem{
    .{ .id = "dinxpanel.desktop", .label = "DINX Control Center", .description = "Hardware, network, audio, display, updates, and services" },
    .{ .id = "nm-connection-editor.desktop", .label = "Network connections", .description = "Manage Wi-Fi, wired, and VPN connections" },
    .{ .id = "blueman-manager.desktop", .label = "Bluetooth", .description = "Pair and manage Bluetooth devices" },
    .{ .id = "com.saivert.pwvucontrol.desktop", .label = "Audio", .description = "Manage PipeWire devices and streams" },
    .{ .id = "com.pori.app.desktop", .label = "Storage", .description = "Inspect disks and persistent mounts" },
    .{ .id = "wdisplays.desktop", .label = "Displays", .description = "Configure monitors and saved display profiles" },
    .{ .id = "octopi.desktop", .label = "Packages", .description = "Install, remove, and update packages" },
};

const App = struct {
    home: [:0]const u8,
    mode_path: []const u8,
    apps: *anyopaque,
    mode: Mode,
    category: Category = .all,
    pinned: std.ArrayList([:0]const u8) = .empty,
    custom_pins: bool = false,
    panel_window: ?*c.GtkWidget = null,
    menu_window: ?*c.GtkWidget = null,
    search_entry: ?*c.GtkWidget = null,
    windows_content: ?*c.GtkWidget = null,
    flow_content: ?*c.GtkWidget = null,
    windows_list: ?*c.GtkWidget = null,
    flow_list: ?*c.GtkWidget = null,
    pinned_panel: ?*c.GtkWidget = null,
    panel_mode_button: ?*c.GtkWidget = null,
    menu_mode_button: ?*c.GtkWidget = null,
    menu_title: ?*c.GtkWidget = null,
    notifications_list: ?*c.GtkWidget = null,
    notifications_button: ?*c.GtkWidget = null,
    tray_button: ?*c.GtkWidget = null,
};

var lock_fd: c_int = -1;

fn envAbsolute(environ: *const std.process.Environ.Map, key: []const u8) ?[]const u8 {
    const value = environ.get(key) orelse return null;
    if (value.len == 0 or value[0] != '/') return null;
    return value;
}

fn modePath(environ: *const std.process.Environ.Map, arena: std.mem.Allocator) []const u8 {
    const base = envAbsolute(environ, "XDG_CONFIG_HOME") orelse blk: {
        const home = envAbsolute(environ, "HOME") orelse return "";
        break :blk std.fmt.allocPrint(arena, "{s}/.config", .{home}) catch return "";
    };
    return std.fmt.allocPrint(arena, "{s}/dinx/redbean.json", .{base}) catch "";
}

fn parseMode(value: []const u8) Mode {
    if (std.mem.eql(u8, value, "flow")) return .flow;
    return .windows;
}

fn validDesktopId(value: []const u8) bool {
    if (value.len < 9 or !std.mem.endsWith(u8, value, ".desktop")) return false;
    for (value) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and byte != '.' and byte != '_' and byte != '-') return false;
    }
    return true;
}

fn readConfig(io: std.Io, path: []const u8) Config {
    if (path.len == 0) return .{};
    const text = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(config_limit)) catch return .{};
    defer allocator.free(text);
    return std.json.parseFromSliceLeaky(Config, allocator, text, .{
        .ignore_unknown_fields = true,
        .duplicate_field_behavior = .use_last,
    }) catch .{};
}

fn modeName(mode: Mode) [*:0]const u8 {
    return switch (mode) {
        .windows => "Windows mode",
        .flow => "Flow mode",
    };
}

fn persistConfig(self: *App) void {
    if (self.mode_path.len == 0) return;
    const directory = std.fs.path.dirname(self.mode_path) orelse return;
    const directory_z = std.fmt.allocPrintSentinel(allocator, "{s}", .{directory}, 0) catch return;
    defer allocator.free(directory_z);
    if (c.redbean_mkdir(directory_z.ptr) != 0) return;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    output.appendSlice(allocator, "{\"version\":1,\"mode\":\"") catch return;
    output.appendSlice(allocator, if (self.mode == .flow) "flow" else "windows") catch return;
    output.appendSlice(allocator, "\",\"pinned\":[") catch return;
    for (self.pinned.items, 0..) |pin, index| {
        if (index > 0) output.append(allocator, ',') catch return;
        output.append(allocator, '"') catch return;
        output.appendSlice(allocator, pin) catch return;
        output.append(allocator, '"') catch return;
    }
    output.appendSlice(allocator, "]}\n") catch return;
    const path_z = std.fmt.allocPrintSentinel(allocator, "{s}", .{self.mode_path}, 0) catch return;
    defer allocator.free(path_z);
    _ = c.g_file_set_contents(path_z.ptr, output.items.ptr, @intCast(output.items.len), null);
}

fn otherInstanceHoldsLock(environ: *const std.process.Environ.Map, arena: std.mem.Allocator) bool {
    const runtime_dir = envAbsolute(environ, "XDG_RUNTIME_DIR") orelse "/tmp";
    const raw = std.fmt.allocPrint(arena, "{s}/{s}", .{ runtime_dir, lock_name }) catch return false;
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

fn connect(instance: anytype, signal: [*:0]const u8, callback: anytype, data: *App) void {
    _ = c.g_signal_connect_data(@ptrCast(instance), signal, @ptrCast(callback), data, null, 0);
}

fn applyStyle() void {
    const provider = c.gtk_css_provider_new() orelse return;
    defer c.g_object_unref(@ptrCast(provider));
    c.gtk_css_provider_load_from_data(provider, css.ptr, @intCast(css.len));
    const display = c.gdk_display_get_default() orelse return;
    c.gtk_style_context_add_provider_for_display(display, @ptrCast(provider), c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
}

fn makeButton(self: *App, text: [*:0]const u8, class_name: [*:0]const u8, callback: anytype) ?*c.GtkWidget {
    const button = c.gtk_button_new_with_label(text) orelse return null;
    c.gtk_widget_add_css_class(button, class_name);
    connect(button, "clicked", callback, self);
    return button;
}

fn makeLabel(text: [*:0]const u8, class_name: ?[*:0]const u8) ?*c.GtkWidget {
    const label = c.gtk_label_new(text) orelse return null;
    c.gtk_label_set_xalign(@ptrCast(label), 0.0);
    if (class_name) |name| c.gtk_widget_add_css_class(label, name);
    return label;
}

fn categoryToken(category: Category) ?[*:0]const u8 {
    return switch (category) {
        .all => null,
        .internet => "Network",
        .office => "Office",
        .graphics => "Graphics",
        .system => "System",
        .utilities => "Utility",
    };
}

fn categoryFromLabel(label: [*:0]const u8) Category {
    const text = std.mem.span(label);
    if (std.mem.eql(u8, text, "Internet")) return .internet;
    if (std.mem.eql(u8, text, "Office")) return .office;
    if (std.mem.eql(u8, text, "Graphics")) return .graphics;
    if (std.mem.eql(u8, text, "System")) return .system;
    if (std.mem.eql(u8, text, "Utilities")) return .utilities;
    return .all;
}

fn clearList(list: *c.GtkWidget) void {
    while (c.gtk_widget_get_first_child(list)) |child| {
        c.gtk_list_box_remove(@ptrCast(list), child);
    }
}

fn appendEmptyResult(list: *c.GtkWidget, text: [*:0]const u8) void {
    const label = makeLabel(text, "redbean-caption") orelse return;
    c.gtk_widget_set_margin_start(label, 12);
    c.gtk_widget_set_margin_top(label, 12);
    c.gtk_list_box_append(@ptrCast(list), label);
}

fn isPinned(self: *App, entry: []const u8) bool {
    for (self.pinned.items) |pin| {
        if (std.mem.eql(u8, pin, entry)) return true;
    }
    return false;
}

fn togglePin(self: *App, application: *anyopaque) void {
    const entry_ptr = c.redbean_app_entry(application) orelse return;
    const entry = std.mem.span(entry_ptr);
    if (!validDesktopId(entry)) return;
    self.custom_pins = true;
    for (self.pinned.items, 0..) |pin, index| {
        if (std.mem.eql(u8, pin, entry)) {
            allocator.free(pin);
            _ = self.pinned.orderedRemove(index);
            persistConfig(self);
            rebuildPinnedPanel(self);
            rebuildResults(self);
            _ = c.redbean_spawn_fixed_args("/usr/bin/pkill", "-HUP", "dinx-dock", null);
            return;
        }
    }
    const copy = dupSentinel(entry) catch return;
    self.pinned.append(allocator, copy) catch {
        allocator.free(copy);
        return;
    };
    persistConfig(self);
    rebuildPinnedPanel(self);
    rebuildResults(self);
    _ = c.redbean_spawn_fixed_args("/usr/bin/pkill", "-HUP", "dinx-dock", null);
}

fn makeAppRow(self: *App, application: *anyopaque) ?*c.GtkWidget {
    const container = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 6) orelse return null;
    c.gtk_widget_add_css_class(container, "redbean-app-row");

    const app_button = c.gtk_button_new() orelse return null;
    c.gtk_widget_add_css_class(app_button, "redbean-app");
    c.gtk_widget_add_css_class(app_button, "redbean-app-launch");
    c.redbean_set_app_pointer(app_button, application);
    connect(app_button, "clicked", &onAppClicked, self);

    const app_content = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 12) orelse return null;
    const icon_name: [*:0]const u8 = if (c.redbean_app_icon_name(application)) |name| @ptrCast(name) else "application-x-executable";
    const icon = c.gtk_image_new_from_icon_name(icon_name) orelse return null;
    c.gtk_image_set_pixel_size(@ptrCast(icon), 32);
    c.gtk_widget_set_valign(icon, c.GTK_ALIGN_CENTER);

    const text_box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 2) orelse return null;
    c.gtk_widget_set_hexpand(text_box, 1);
    const name: [*:0]const u8 = if (c.redbean_app_name(application)) |value| @ptrCast(value) else "Application";
    const description: [*:0]const u8 = if (c.redbean_app_description(application)) |value| @ptrCast(value) else "Launch application";
    const name_label = makeLabel(name, "redbean-app-name") orelse return null;
    const description_label = makeLabel(description, "redbean-app-description") orelse return null;
    c.gtk_label_set_ellipsize(@ptrCast(description_label), c.PANGO_ELLIPSIZE_END);
    c.gtk_label_set_max_width_chars(@ptrCast(description_label), 64);
    c.gtk_box_append(@ptrCast(text_box), name_label);
    c.gtk_box_append(@ptrCast(text_box), description_label);
    c.gtk_box_append(@ptrCast(app_content), icon);
    c.gtk_box_append(@ptrCast(app_content), text_box);
    c.gtk_button_set_child(@ptrCast(app_button), app_content);
    c.gtk_widget_set_hexpand(app_button, 1);
    c.gtk_widget_set_tooltip_text(app_button, name);

    const entry = c.redbean_app_entry(application) orelse return null;
    const pin = c.gtk_button_new_with_label(if (isPinned(self, std.mem.span(entry))) "Unpin" else "Pin") orelse return null;
    c.gtk_widget_add_css_class(pin, "redbean-pin");
    c.redbean_set_app_pointer(pin, application);
    c.gtk_widget_set_tooltip_text(pin, "Add or remove this application from Redbean and the DINX Dock");
    connect(pin, "clicked", &onPinClicked, self);
    const manage = c.gtk_button_new_with_label("Manage") orelse return null;
    c.gtk_widget_add_css_class(manage, "redbean-pin");
    c.redbean_set_app_pointer(manage, application);
    c.gtk_widget_set_tooltip_text(manage, "Uninstall this application package");
    connect(manage, "clicked", &onManageClicked, self);
    c.gtk_box_append(@ptrCast(container), app_button);
    c.gtk_box_append(@ptrCast(container), pin);
    c.gtk_box_append(@ptrCast(container), manage);
    return container;
}

fn makeSettingButton(self: *App, item: SettingItem) ?*c.GtkWidget {
    const button = c.gtk_button_new() orelse return null;
    c.gtk_widget_add_css_class(button, "redbean-app");
    c.redbean_set_string_data(button, "redbean-desktop-id", item.id);
    const row = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 2) orelse return null;
    const title = makeLabel(item.label, "redbean-app-name") orelse return null;
    const description = makeLabel(item.description, "redbean-app-description") orelse return null;
    c.gtk_box_append(@ptrCast(row), title);
    c.gtk_box_append(@ptrCast(row), description);
    c.gtk_button_set_child(@ptrCast(button), row);
    c.gtk_widget_set_tooltip_text(button, item.description);
    connect(button, "clicked", &onSettingClicked, self);
    return button;
}

fn makeFileButton(self: *App, path: [*:0]const u8) ?*c.GtkWidget {
    const button = c.gtk_button_new() orelse return null;
    c.gtk_widget_add_css_class(button, "redbean-app");
    c.redbean_set_string_data(button, "redbean-file-path", path);
    const row = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 2) orelse return null;
    const name = std.fs.path.basename(std.mem.span(path));
    const name_z = dupSentinel(name) catch return null;
    defer allocator.free(name_z);
    const title = makeLabel(name_z.ptr, "redbean-app-name") orelse return null;
    const description = makeLabel(path, "redbean-app-description") orelse return null;
    c.gtk_box_append(@ptrCast(row), title);
    c.gtk_box_append(@ptrCast(row), description);
    c.gtk_button_set_child(@ptrCast(button), row);
    c.gtk_widget_set_tooltip_text(button, path);
    connect(button, "clicked", &onFileClicked, self);
    return button;
}

fn appendSettings(self: *App, list: *c.GtkWidget, query: []const u8, limit: usize, shown: *usize) void {
    for (settings_items) |item| {
        if (shown.* >= limit) break;
        if (query.len != 0 and
            c.redbean_text_matches(item.label, query.ptr) == 0 and
            c.redbean_text_matches(item.description, query.ptr) == 0 and
            c.redbean_text_matches(item.id, query.ptr) == 0) continue;
        const button = makeSettingButton(self, item) orelse continue;
        c.gtk_list_box_append(@ptrCast(list), button);
        shown.* += 1;
    }
}

fn appendFiles(self: *App, list: *c.GtkWidget, query: []const u8, limit: usize, shown: *usize) void {
    if (self.home.len == 0 or query.len == 0) return;
    const results = c.redbean_file_search(self.home.ptr, query.ptr, @intCast(limit -| shown.*));
    defer c.redbean_file_list_free(results);
    var node = results;
    while (node) |current| : (node = c.redbean_list_next(current)) {
        if (shown.* >= limit) break;
        const path = c.redbean_list_data(current) orelse continue;
        const button = makeFileButton(self, @ptrCast(path)) orelse continue;
        c.gtk_list_box_append(@ptrCast(list), button);
        shown.* += 1;
    }
}

fn populateList(self: *App, list: *c.GtkWidget, category: Category, limit: usize) void {
    clearList(list);
    const raw = std.mem.span(c.gtk_editable_get_text(@ptrCast(self.search_entry.?)));
    if (std.mem.startsWith(u8, raw, "file:")) {
        var shown: usize = 0;
        appendFiles(self, list, raw["file:".len..], limit, &shown);
        if (shown == 0) appendEmptyResult(list, "No matching files");
        return;
    }
    if (std.mem.startsWith(u8, raw, "settings:")) {
        var shown: usize = 0;
        appendSettings(self, list, raw["settings:".len..], limit, &shown);
        if (shown == 0) appendEmptyResult(list, "No matching settings");
        return;
    }

    const results = if (raw.len == 0)
        c.redbean_apps_list(self.apps)
    else
        c.redbean_apps_query(self.apps, raw.ptr);
    defer c.redbean_list_free(results);

    var node = results;
    var shown: usize = 0;
    while (node) |current| : (node = c.redbean_list_next(current)) {
        if (shown >= limit) break;
        const application = c.redbean_list_data(current) orelse continue;
        if (categoryToken(category)) |token| {
            if (c.redbean_app_has_category(application, token) == 0) continue;
        }
        const row = makeAppRow(self, application) orelse continue;
        c.gtk_list_box_append(@ptrCast(list), row);
        shown += 1;
    }
    if (raw.len != 0 and category == .all) appendSettings(self, list, raw, limit, &shown);
    if (shown == 0) appendEmptyResult(list, if (raw.len == 0) "No applications found" else "No matching applications or settings");
}

fn rebuildResults(self: *App) void {
    if (self.windows_list) |list| populateList(self, list, self.category, 18);
    if (self.flow_list) |list| populateList(self, list, .all, 24);
}

fn updateModeSurface(self: *App) void {
    const windows_visible: c.gboolean = if (self.mode == .windows) 1 else 0;
    const flow_visible: c.gboolean = if (self.mode == .flow) 1 else 0;
    if (self.windows_content) |widget| c.gtk_widget_set_visible(widget, windows_visible);
    if (self.flow_content) |widget| c.gtk_widget_set_visible(widget, flow_visible);
    if (self.panel_mode_button) |button| c.gtk_button_set_label(@ptrCast(button), modeName(self.mode));
    if (self.menu_mode_button) |button| c.gtk_button_set_label(@ptrCast(button), modeName(self.mode));
    if (self.menu_title) |title| c.gtk_label_set_text(@ptrCast(title), if (self.mode == .windows) "Start here" else "Quick launch");
    if (self.search_entry) |entry| {
        c.gtk_entry_set_placeholder_text(@ptrCast(entry), if (self.mode == .windows) "Search apps, settings, and files" else "Type to launch");
    }
    rebuildResults(self);
}

fn setMode(self: *App, mode: Mode) void {
    self.mode = mode;
    self.category = .all;
    persistConfig(self);
    updateModeSurface(self);
}

fn toggleMenu(self: *App) void {
    const menu = self.menu_window orelse return;
    const visible = c.gtk_widget_get_visible(menu) != 0;
    c.gtk_widget_set_visible(menu, if (visible) 0 else 1);
    if (!visible) {
        c.gtk_window_present(@ptrCast(menu));
        if (self.search_entry) |entry| {
            _ = c.gtk_widget_grab_focus(entry);
            c.gtk_editable_set_position(@ptrCast(entry), -1);
        }
    }
}

fn launchFirst(self: *App) void {
    const search_ptr = c.gtk_editable_get_text(@ptrCast(self.search_entry.?));
    const raw = std.mem.span(search_ptr);
    if (std.mem.startsWith(u8, raw, "file:")) {
        const query = raw["file:".len..];
        if (query.len == 0 or self.home.len == 0) return;
        const results = c.redbean_file_search(self.home.ptr, query.ptr, 1);
        defer c.redbean_file_list_free(results);
        if (results) |node| {
            if (c.redbean_list_data(node)) |path| {
                if (c.redbean_launch_path(@ptrCast(path)) != 0) {
                    c.gtk_widget_set_visible(self.menu_window.?, 0);
                }
            }
        }
        return;
    }
    if (std.mem.startsWith(u8, raw, "settings:")) {
        const query = raw["settings:".len..];
        for (settings_items) |item| {
            if (query.len == 0 or
                c.redbean_text_matches(item.label, query.ptr) != 0 or
                c.redbean_text_matches(item.description, query.ptr) != 0 or
                c.redbean_text_matches(item.id, query.ptr) != 0)
            {
                if (c.redbean_launch_desktop(item.id) != 0) {
                    c.gtk_widget_set_visible(self.menu_window.?, 0);
                }
                return;
            }
        }
        return;
    }
    const results = if (raw.len == 0)
        c.redbean_apps_list(self.apps)
    else
        c.redbean_apps_query(self.apps, raw.ptr);
    defer c.redbean_list_free(results);
    const application = if (results) |node| c.redbean_list_data(node) else null;
    if (application) |item| {
        if (c.redbean_app_launch(item) == 0) log.warn("application launch failed", .{});
        c.gtk_widget_set_visible(self.menu_window.?, 0);
    }
}

fn onAppClicked(button: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    const application = c.redbean_get_app_pointer(@ptrCast(button orelse return)) orelse return;
    if (c.redbean_app_launch(application) == 0) log.warn("application launch failed", .{});
    if (self.menu_window) |menu| c.gtk_widget_set_visible(menu, 0);
}
fn onPinClicked(button: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    const application = c.redbean_get_app_pointer(@ptrCast(button orelse return)) orelse return;
    togglePin(self, application);
}
fn onManageClicked(button: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    const application = c.redbean_get_app_pointer(@ptrCast(button orelse return)) orelse return;
    const entry = c.redbean_app_entry(application) orelse return;
    if (!validDesktopId(std.mem.span(entry))) return;
    if (c.redbean_spawn_fixed_args("/usr/lib/redbean/uninstall", entry, null, null) == 0) {
        log.warn("package uninstall helper launch failed", .{});
    }
    if (self.menu_window) |menu| c.gtk_widget_set_visible(menu, 0);
}

fn onSettingClicked(button: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    const widget: *c.GtkWidget = @ptrCast(button orelse return);
    const desktop_id = c.redbean_get_string_data(widget, "redbean-desktop-id") orelse return;
    if (c.redbean_launch_desktop(desktop_id) == 0) log.warn("setting launch failed", .{});
    if (self.menu_window) |menu| c.gtk_widget_set_visible(menu, 0);
}

fn onFileClicked(button: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    const widget: *c.GtkWidget = @ptrCast(button orelse return);
    const path = c.redbean_get_string_data(widget, "redbean-file-path") orelse return;
    if (c.redbean_launch_path(path) == 0) log.warn("file launch failed", .{});
    if (self.menu_window) |menu| c.gtk_widget_set_visible(menu, 0);
}

fn onSearchChanged(_: ?*c.GtkEditable, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    rebuildResults(self);
}

fn onSearchActivate(_: ?*c.GtkSearchEntry, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    launchFirst(self);
}

fn onKeyPressed(_: ?*c.GtkEventControllerKey, keyval: c.guint, _: c.guint, _: c.GdkModifierType, data: ?*anyopaque) callconv(.c) c.gboolean {
    const self: *App = @ptrCast(@alignCast(data orelse return 0));
    if (keyval == 65307) {
        if (self.menu_window) |menu| c.gtk_widget_set_visible(menu, 0);
        return 1;
    }
    return 0;
}

fn onStartClicked(_: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    toggleMenu(@ptrCast(@alignCast(data orelse return)));
}

fn onModeClicked(_: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    setMode(self, if (self.mode == .windows) .flow else .windows);
}

fn onCategoryClicked(button: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    const label = c.gtk_button_get_label(button orelse return) orelse return;
    self.category = categoryFromLabel(label);
    if (self.windows_list) |list| populateList(self, list, self.category, 18);
}

fn onDesktopShortcutClicked(button: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    const widget: *c.GtkWidget = @ptrCast(button orelse return);
    const configured = c.redbean_get_string_data(widget, "redbean-desktop-id");
    const label = c.gtk_button_get_label(button orelse return) orelse return;
    const desktop_id: [*:0]const u8 = configured orelse blk: {
        if (std.mem.eql(u8, std.mem.span(label), "Files")) break :blk "pcmanfm.desktop";
        if (std.mem.eql(u8, std.mem.span(label), "Terminal")) break :blk "org.dinx.Deetty.desktop";
        if (std.mem.eql(u8, std.mem.span(label), "Browser")) break :blk "firefox.desktop";
        return;
    };
    if (c.redbean_launch_desktop(desktop_id) == 0) log.warn("desktop shortcut launch failed", .{});
}

fn onLockClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    if (c.redbean_spawn_fixed("/usr/local/libexec/dinx-lock") == 0) log.warn("lock helper launch failed", .{});
}

fn onFocusPreviousClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_river_command("focus-view", "previous");
}

fn onFocusNextClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_river_command("focus-view", "next");
}

fn onWorkspacePreviousClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_river_move_tag(-1);
}

fn onWorkspaceNextClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_river_move_tag(1);
}

fn onAudioDownClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_audio_change(-0.05);
}

fn onAudioUpClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_audio_change(0.05);
}

fn onAudioMuteClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_audio_toggle_mute();
}

fn onNetworkClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_spawn_fixed("/usr/bin/nm-connection-editor");
}

fn onBluetoothClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_spawn_fixed("/usr/bin/blueman-manager");
}

fn onAudioClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_spawn_fixed("/usr/bin/pwvucontrol");
}

fn onPackagesClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_spawn_fixed("/usr/bin/octopi");
}

fn onControlCenterClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = c.redbean_spawn_fixed("/usr/bin/dinxpanel");
}
fn onTrayClicked(_: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    refreshNotifications(self);
    _ = c.redbean_spawn_fixed("/usr/bin/dinxpanel");
}

fn appendNotification(
    id: c.guint,
    notification_app_name: [*:0]const u8,
    summary: [*:0]const u8,
    body: [*:0]const u8,
    data: ?*anyopaque,
) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    const list = self.notifications_list orelse return;
    const button = c.gtk_button_new() orelse return;
    c.gtk_widget_add_css_class(button, "redbean-notification");
    c.redbean_set_uint_data(button, "redbean-notification-id", id);
    const row = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 2) orelse return;
    const title_text = std.fmt.allocPrintSentinel(allocator, "{s}: {s}", .{ notification_app_name, summary }, 0) catch return;
    defer allocator.free(title_text);
    const title = makeLabel(title_text.ptr, "redbean-app-name") orelse return;
    const detail = makeLabel(body, "redbean-app-description") orelse return;
    c.gtk_label_set_wrap(@ptrCast(detail), 1);
    c.gtk_box_append(@ptrCast(row), title);
    c.gtk_box_append(@ptrCast(row), detail);
    c.gtk_button_set_child(@ptrCast(button), row);
    c.gtk_widget_set_tooltip_text(button, "Dismiss notification");
    connect(button, "clicked", &onNotificationClicked, self);
    c.gtk_box_append(@ptrCast(list), button);
}

fn refreshNotifications(self: *App) void {
    const list = self.notifications_list orelse return;
    clearBox(list);
    c.redbean_notifications_each(@ptrCast(&appendNotification), self);
    if (c.gtk_widget_get_first_child(list) == null) {
        const empty = makeLabel("No unread notifications", "redbean-caption") orelse return;
        c.gtk_box_append(@ptrCast(list), empty);
    }
    if (self.notifications_button) |button| {
        var text: [32]u8 = undefined;
        const rendered = std.fmt.bufPrint(text[0 .. text.len - 1], "Alerts ({d})", .{c.redbean_notification_count()}) catch return;
        text[rendered.len] = 0;
        c.gtk_button_set_label(@ptrCast(button), rendered.ptr);
    }
    if (self.tray_button) |button| {
        var text: [32]u8 = undefined;
        const rendered = std.fmt.bufPrint(text[0 .. text.len - 1], "Tray ({d})", .{c.redbean_tray_count()}) catch return;
        text[rendered.len] = 0;
        c.gtk_button_set_label(@ptrCast(button), rendered.ptr);
    }
}

fn onNotificationClicked(button: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    const id = c.redbean_get_uint_data(@ptrCast(button orelse return), "redbean-notification-id");
    c.redbean_dismiss_notification(id);
    refreshNotifications(self);
}

fn onAlertsClicked(_: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const self: *App = @ptrCast(@alignCast(data orelse return));
    refreshNotifications(self);
    toggleMenu(self);
}

fn onRefreshTimer(data: ?*anyopaque) callconv(.c) c.gboolean {
    const self: *App = @ptrCast(@alignCast(data orelse return 0));
    refreshNotifications(self);
    return 1;
}

fn onLogoutClicked(_: ?*c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    if (c.redbean_spawn_fixed("/usr/local/libexec/dinx-logout") == 0) log.warn("logout helper launch failed", .{});
}

fn clearBox(box: *c.GtkWidget) void {
    while (c.gtk_widget_get_first_child(box)) |child| {
        c.gtk_box_remove(@ptrCast(box), child);
    }
}

fn pinLabel(id: []const u8) []const u8 {
    if (std.mem.eql(u8, id, "org.dinx.Deetty.desktop")) return "Terminal";
    if (std.mem.eql(u8, id, "pcmanfm.desktop")) return "Files";
    if (std.mem.eql(u8, id, "firefox.desktop")) return "Browser";
    if (std.mem.eql(u8, id, "org.dinx.Dintor.desktop")) return "Editor";
    if (std.mem.eql(u8, id, "octopi.desktop")) return "Packages";
    if (std.mem.eql(u8, id, "dinxpanel.desktop")) return "Control Center";
    return std.fs.path.basename(id);
}

fn rebuildPinnedPanel(self: *App) void {
    const panel = self.pinned_panel orelse return;
    clearBox(panel);
    const ids = if (self.custom_pins) self.pinned.items else default_pins[0..];
    for (ids) |id| {
        const label = std.fmt.allocPrintSentinel(allocator, "{s}", .{pinLabel(id)}, 0) catch continue;
        defer allocator.free(label);
        const button = makeButton(self, label.ptr, "redbean-shortcut", &onDesktopShortcutClicked) orelse continue;
        c.redbean_set_string_data(button, "redbean-desktop-id", id.ptr);
        c.gtk_widget_set_tooltip_text(button, id.ptr);
        c.gtk_box_append(@ptrCast(panel), button);
    }
}

fn buildPanel(self: *App) void {
    const window = c.gtk_window_new() orelse return;
    c.gtk_window_set_title(@ptrCast(window), app_name);
    c.gtk_window_set_decorated(@ptrCast(window), 0);
    c.gtk_window_set_default_size(@ptrCast(window), 0, panel_height);

    const surface = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
    c.gtk_widget_add_css_class(surface, "redbean-panel-surface");
    const start = makeButton(self, "Start", "redbean-start", &onStartClicked) orelse return;
    c.gtk_widget_set_tooltip_text(start, "Open Redbean start menu");
    c.gtk_box_append(@ptrCast(surface), start);
    self.pinned_panel = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 6);
    if (self.pinned_panel) |panel| {
        c.gtk_box_append(@ptrCast(surface), panel);
        rebuildPinnedPanel(self);
    }
    const spacer = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0) orelse return;
    c.gtk_widget_set_hexpand(spacer, 1);
    c.gtk_box_append(@ptrCast(surface), spacer);
    const status = makeLabel("Redbean", "redbean-status") orelse return;
    c.gtk_box_append(@ptrCast(surface), status);
    self.panel_mode_button = makeButton(self, modeName(self.mode), "redbean-mode", &onModeClicked);
    if (self.panel_mode_button) |button| {
        c.gtk_widget_set_tooltip_text(button, "Switch between Windows and Flow modes");
        c.gtk_box_append(@ptrCast(surface), button);
    }
    c.gtk_window_set_child(@ptrCast(window), surface);

    const gtk_window: *c.GtkWindow = @ptrCast(window);
    c.gtk_layer_init_for_window(gtk_window);
    c.gtk_layer_set_namespace(gtk_window, "redbean-panel");
    c.gtk_layer_set_layer(gtk_window, c.GTK_LAYER_SHELL_LAYER_TOP);
    c.gtk_layer_set_keyboard_mode(gtk_window, c.GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);
    c.gtk_layer_set_anchor(gtk_window, c.GTK_LAYER_SHELL_EDGE_BOTTOM, 1);
    c.gtk_layer_set_anchor(gtk_window, c.GTK_LAYER_SHELL_EDGE_LEFT, 1);
    c.gtk_layer_set_anchor(gtk_window, c.GTK_LAYER_SHELL_EDGE_RIGHT, 1);
    c.gtk_layer_auto_exclusive_zone_enable(gtk_window);
    self.panel_window = window;
    c.gtk_window_present(@ptrCast(window));
}

fn buildMenu(self: *App) void {
    const window = c.gtk_window_new() orelse return;
    c.gtk_window_set_title(@ptrCast(window), app_name);
    c.gtk_window_set_decorated(@ptrCast(window), 0);
    c.gtk_window_set_default_size(@ptrCast(window), 720, 620);

    const surface = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 8) orelse return;
    c.gtk_widget_add_css_class(surface, "redbean-surface");
    const header = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10) orelse return;
    c.gtk_widget_add_css_class(header, "redbean-header");
    const title_group = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 2) orelse return;
    c.gtk_widget_set_hexpand(title_group, 1);
    self.menu_title = makeLabel("Start here", "redbean-title");
    if (self.menu_title) |title| c.gtk_box_append(@ptrCast(title_group), title);
    const subtitle = makeLabel("Search and launch installed apps", "redbean-caption") orelse return;
    c.gtk_box_append(@ptrCast(title_group), subtitle);
    c.gtk_box_append(@ptrCast(header), title_group);
    self.menu_mode_button = makeButton(self, modeName(self.mode), "redbean-mode", &onModeClicked);
    if (self.menu_mode_button) |button| {
        c.gtk_widget_set_tooltip_text(button, "Switch between Windows and Flow modes");
        c.gtk_box_append(@ptrCast(header), button);
    }
    c.gtk_box_append(@ptrCast(surface), header);

    self.search_entry = c.gtk_search_entry_new();
    if (self.search_entry) |entry| {
        c.gtk_widget_add_css_class(entry, "redbean-search");
        c.gtk_widget_set_hexpand(entry, 1);
        c.gtk_search_entry_set_placeholder_text(@ptrCast(entry), "Search apps, settings, and files");
        c.gtk_widget_set_tooltip_text(entry, "Search installed applications; press Enter to launch the first result");
        connect(entry, "search-changed", &onSearchChanged, self);
        connect(entry, "activate", &onSearchActivate, self);
        c.gtk_box_append(@ptrCast(surface), entry);
    }
    const search_hint = makeLabel("Enter launches the first result", "redbean-hint") orelse return;
    c.gtk_box_append(@ptrCast(surface), search_hint);
    const focus_row = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 6) orelse return;
    const focus_prev = makeButton(self, "Focus prev", "redbean-footer", &onFocusPreviousClicked) orelse return;
    const focus_next = makeButton(self, "Focus next", "redbean-footer", &onFocusNextClicked) orelse return;
    const workspace_prev = makeButton(self, "Workspace prev", "redbean-footer", &onWorkspacePreviousClicked) orelse return;
    const workspace_next = makeButton(self, "Workspace next", "redbean-footer", &onWorkspaceNextClicked) orelse return;
    c.gtk_widget_set_tooltip_text(focus_prev, "Focus the previous window");
    c.gtk_widget_set_tooltip_text(focus_next, "Focus the next window");
    c.gtk_widget_set_tooltip_text(workspace_prev, "Switch to the previous workspace");
    c.gtk_widget_set_tooltip_text(workspace_next, "Switch to the next workspace");
    c.gtk_box_append(@ptrCast(focus_row), focus_prev);
    c.gtk_box_append(@ptrCast(focus_row), focus_next);
    c.gtk_box_append(@ptrCast(focus_row), workspace_prev);
    c.gtk_box_append(@ptrCast(focus_row), workspace_next);
    c.gtk_box_append(@ptrCast(surface), focus_row);

    const system_row = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 6) orelse return;
    const audio_down = makeButton(self, "Volume -", "redbean-footer", &onAudioDownClicked) orelse return;
    const audio_up = makeButton(self, "Volume +", "redbean-footer", &onAudioUpClicked) orelse return;
    const mute = makeButton(self, "Mute", "redbean-footer", &onAudioMuteClicked) orelse return;
    self.notifications_button = makeButton(self, "Alerts", "redbean-footer", &onAlertsClicked);
    self.tray_button = makeButton(self, "Tray", "redbean-footer", &onTrayClicked);
    const network = makeButton(self, "Network", "redbean-footer", &onNetworkClicked) orelse return;
    const bluetooth = makeButton(self, "Bluetooth", "redbean-footer", &onBluetoothClicked) orelse return;
    const audio = makeButton(self, "Audio", "redbean-footer", &onAudioClicked) orelse return;
    const packages = makeButton(self, "Packages", "redbean-footer", &onPackagesClicked) orelse return;
    const controls = makeButton(self, "Controls", "redbean-footer", &onControlCenterClicked) orelse return;
    c.gtk_widget_set_tooltip_text(network, "Open network connections");
    c.gtk_widget_set_tooltip_text(bluetooth, "Open Bluetooth devices");
    c.gtk_widget_set_tooltip_text(audio, "Open PipeWire audio controls");
    c.gtk_widget_set_tooltip_text(packages, "Open package management");
    c.gtk_widget_set_tooltip_text(controls, "Open the DINX control center");
    for ([_]?*c.GtkWidget{ self.notifications_button, self.tray_button, audio_down, audio_up, mute, network, bluetooth, audio, packages, controls }) |button| {
        if (button) |item| c.gtk_box_append(@ptrCast(system_row), item);
    }
    c.gtk_box_append(@ptrCast(surface), system_row);

    const notification_scroll = c.gtk_scrolled_window_new() orelse return;
    c.gtk_scrolled_window_set_policy(@ptrCast(notification_scroll), c.GTK_POLICY_NEVER, c.GTK_POLICY_AUTOMATIC);
    c.gtk_widget_set_size_request(notification_scroll, -1, 120);
    self.notifications_list = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 4);
    if (self.notifications_list) |list| {
        c.gtk_scrolled_window_set_child(@ptrCast(notification_scroll), list);
        c.gtk_box_append(@ptrCast(surface), notification_scroll);
        refreshNotifications(self);
    }

    self.windows_content = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8);
    if (self.windows_content) |content| {
        const sidebar = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 4) orelse return;
        c.gtk_widget_add_css_class(sidebar, "redbean-sidebar");
        c.gtk_widget_set_size_request(sidebar, 150, -1);
        for ([_][*:0]const u8{ "All apps", "Internet", "Office", "Graphics", "System", "Utilities" }) |category| {
            const button = makeButton(self, category, "redbean-category", &onCategoryClicked) orelse continue;
            c.gtk_box_append(@ptrCast(sidebar), button);
        }
        const scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_scrolled_window_set_policy(@ptrCast(scroll), c.GTK_POLICY_NEVER, c.GTK_POLICY_AUTOMATIC);
        c.gtk_widget_set_vexpand(scroll, 1);
        self.windows_list = c.gtk_list_box_new();
        if (self.windows_list) |list| {
            c.gtk_widget_add_css_class(list, "redbean-list");
            c.gtk_list_box_set_selection_mode(@ptrCast(list), c.GTK_SELECTION_NONE);
            c.gtk_scrolled_window_set_child(@ptrCast(scroll), list);
        }
        c.gtk_box_append(@ptrCast(content), sidebar);
        c.gtk_box_append(@ptrCast(content), scroll);
        c.gtk_widget_set_vexpand(content, 1);
        c.gtk_box_append(@ptrCast(surface), content);
    }

    self.flow_content = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 6);
    if (self.flow_content) |content| {
        const caption = makeLabel("Search by name, category, or keyword. Press Enter to launch.", "redbean-caption") orelse return;
        c.gtk_box_append(@ptrCast(content), caption);
        const scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_scrolled_window_set_policy(@ptrCast(scroll), c.GTK_POLICY_NEVER, c.GTK_POLICY_AUTOMATIC);
        c.gtk_widget_set_vexpand(scroll, 1);
        self.flow_list = c.gtk_list_box_new();
        if (self.flow_list) |list| {
            c.gtk_widget_add_css_class(list, "redbean-flow-list");
            c.gtk_list_box_set_selection_mode(@ptrCast(list), c.GTK_SELECTION_NONE);
            c.gtk_scrolled_window_set_child(@ptrCast(scroll), list);
        }
        c.gtk_box_append(@ptrCast(content), scroll);
        c.gtk_widget_set_vexpand(content, 1);
        c.gtk_box_append(@ptrCast(surface), content);
    }

    const footer = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
    const footer_spacer = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0) orelse return;
    c.gtk_widget_set_hexpand(footer_spacer, 1);
    c.gtk_box_append(@ptrCast(footer), footer_spacer);
    const lock = makeButton(self, "Lock", "redbean-footer", &onLockClicked) orelse return;
    const logout = makeButton(self, "Log out", "redbean-footer", &onLogoutClicked) orelse return;
    c.gtk_box_append(@ptrCast(footer), lock);
    c.gtk_box_append(@ptrCast(footer), logout);
    c.gtk_box_append(@ptrCast(surface), footer);
    c.gtk_window_set_child(@ptrCast(window), surface);

    const controller = c.gtk_event_controller_key_new() orelse return;
    connect(controller, "key-pressed", &onKeyPressed, self);
    c.gtk_widget_add_controller(window, controller);

    const gtk_window: *c.GtkWindow = @ptrCast(window);
    c.gtk_layer_init_for_window(gtk_window);
    c.gtk_layer_set_namespace(gtk_window, "redbean-menu");
    c.gtk_layer_set_layer(gtk_window, c.GTK_LAYER_SHELL_LAYER_OVERLAY);
    c.gtk_layer_set_keyboard_mode(gtk_window, c.GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND);
    c.gtk_layer_set_anchor(gtk_window, c.GTK_LAYER_SHELL_EDGE_BOTTOM, 1);
    c.gtk_layer_set_anchor(gtk_window, c.GTK_LAYER_SHELL_EDGE_LEFT, 1);
    c.gtk_layer_set_margin(gtk_window, c.GTK_LAYER_SHELL_EDGE_BOTTOM, panel_height + 10);
    c.gtk_layer_set_margin(gtk_window, c.GTK_LAYER_SHELL_EDGE_LEFT, 14);
    self.menu_window = window;
    c.gtk_widget_set_visible(window, 0);
}

fn deinitPins(self: *App) void {
    for (self.pinned.items) |pin| allocator.free(pin);
    self.pinned.deinit(allocator);
}

fn deinit(self: *App) void {
    deinitPins(self);
    allocator.free(self.home);
}

pub fn main(init: std.process.Init) !void {
    const environ = init.environ_map;
    const arena = init.arena.allocator();
    const mode_path = modePath(environ, arena);
    const config = readConfig(init.io, mode_path);
    const mode = parseMode(config.mode orelse "windows");
    if (otherInstanceHoldsLock(environ, arena)) return;

    c.g_set_prgname(app_id);
    c.g_set_application_name(app_name);
    if (c.gtk_init_check() == 0) {
        log.warn("no display available; Redbean needs a Wayland session", .{});
        if (lock_fd >= 0) _ = c.close(lock_fd);
        return;
    }
    if (c.gdk_display_get_default() == null) {
        if (lock_fd >= 0) _ = c.close(lock_fd);
        return;
    }
    const apps = c.redbean_apps_new() orelse {
        if (lock_fd >= 0) _ = c.close(lock_fd);
        return error.AppDiscoveryUnavailable;
    };
    const home = dupSentinel(environ.get("HOME") orelse "") catch {
        c.redbean_object_unref(@ptrCast(apps));
        if (lock_fd >= 0) _ = c.close(lock_fd);
        return error.OutOfMemory;
    };
    var shell = App{
        .home = home,
        .mode_path = mode_path,
        .apps = @ptrCast(apps),
        .mode = mode,
        .custom_pins = config.pinned != null,
    };
    if (config.pinned) |pins| {
        for (pins) |pin| {
            if (!validDesktopId(pin)) continue;
            const copy = dupSentinel(pin) catch continue;
            shell.pinned.append(allocator, copy) catch {
                allocator.free(copy);
                continue;
            };
        }
    } else {
        for (default_pins) |pin| {
            const copy = dupSentinel(pin) catch continue;
            shell.pinned.append(allocator, copy) catch {
                allocator.free(copy);
                continue;
            };
        }
    }
    applyStyle();
    buildPanel(&shell);
    buildMenu(&shell);
    if (shell.panel_window == null or shell.menu_window == null) {
        c.redbean_object_unref(@ptrCast(apps));
        deinit(&shell);
        if (lock_fd >= 0) _ = c.close(lock_fd);
        return;
    }
    updateModeSurface(&shell);
    _ = c.g_timeout_add_seconds(2, &onRefreshTimer, &shell);

    const loop = c.g_main_loop_new(null, 0) orelse {
        c.redbean_object_unref(@ptrCast(apps));
        deinit(&shell);
        if (lock_fd >= 0) _ = c.close(lock_fd);
        return error.MainLoopUnavailable;
    };
    c.g_main_loop_run(loop);
    c.g_main_loop_unref(loop);
    c.redbean_object_unref(@ptrCast(apps));
    deinit(&shell);
    if (lock_fd >= 0) _ = c.close(lock_fd);
}
