// SPDX-FileCopyrightText: 2026 DINX Contributors
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");
const c = @import("c");

const allocator = std.heap.c_allocator;

const version_string = "0.1.0";
const app_id = "com.dinx.FirstRun";
const window_title = "DINX | Configuração inicial / Initial setup";
const morghulis_schema = "com.arkye.morghulis";
const morghulis_bar_key = "navbar-anchor";
const dconf_color_scheme_path = "/org/gnome/desktop/interface/color-scheme";

// Five lines: the GTK theme family belongs to gtk-theme-name (resolved by
// dinx-sync-session-theme), so main.css only carries dock-safe shell tweaks.
const shell_css =
    \\/* DINX shell adjustments */
    \\/* The GTK theme family follows gtk-theme-name. */
    \\/* dinx-sync-session-theme resolves theme, variant and corners. */
    \\/* This file carries only dock-safe shell tweaks. */
    \\.dock { padding: 4px; } window.dinx-shell { font-family: "Noto Sans"; }
;

const Language = enum { pt_br, en_us };
const Location = enum { sao_paulo, utc };
const Theme = enum { dinx, skeuos, orchis, fluent, jasper };
const Variant = enum { dark, light };
const Corners = enum { rounded, square };
const Bar = enum { top, bottom };
const Dock = enum { none, left, right, bottom };

const Selections = struct {
    language: Language = .pt_br,
    location: Location = .sao_paulo,
    theme: Theme = .dinx,
    variant: Variant = .dark,
    corners: Corners = .rounded,
    bar: Bar = .bottom,
    dock: Dock = .left,

    fn languageCode(self: Selections) []const u8 {
        return switch (self.language) {
            .pt_br => "pt-BR",
            .en_us => "en-US",
        };
    }

    fn locale(self: Selections) []const u8 {
        return switch (self.language) {
            .pt_br => "pt_BR.UTF-8",
            .en_us => "en_US.UTF-8",
        };
    }

    fn timezone(self: Selections) []const u8 {
        return switch (self.location) {
            .sao_paulo => "America/Sao_Paulo",
            .utc => "UTC",
        };
    }

    fn keyboard(self: Selections) []const u8 {
        return switch (self.language) {
            .pt_br => "br",
            .en_us => "us",
        };
    }

    fn themeName(self: Selections) []const u8 {
        return switch (self.theme) {
            .dinx => "DINX",
            .skeuos => "Skeuos",
            .orchis => "Orchis",
            .fluent => "Fluent",
            .jasper => "Jasper",
        };
    }

    fn variantName(self: Selections) []const u8 {
        return switch (self.variant) {
            .dark => "dark",
            .light => "light",
        };
    }

    fn cornersName(self: Selections) []const u8 {
        return switch (self.corners) {
            .rounded => "rounded",
            .square => "square",
        };
    }

    fn barName(self: Selections) []const u8 {
        return switch (self.bar) {
            .top => "top",
            .bottom => "bottom",
        };
    }

    fn dockName(self: Selections) []const u8 {
        return switch (self.dock) {
            .none => "none",
            .left => "left",
            .right => "right",
            .bottom => "bottom",
        };
    }

    fn colorScheme(self: Selections) []const u8 {
        return switch (self.variant) {
            .dark => "prefer-dark",
            .light => "prefer-light",
        };
    }

    fn appearanceJson(self: Selections) ![]u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"version":1,"language":"{s}","locale":"{s}","timezone":"{s}","keyboard":"{s}","theme":"{s}","variant":"{s}","corners":"{s}","bar":"{s}","dock":"{s}"}}
        , .{
            self.languageCode(),
            self.locale(),
            self.timezone(),
            self.keyboard(),
            self.themeName(),
            self.variantName(),
            self.cornersName(),
            self.barName(),
            self.dockName(),
        });
    }

    fn installerPreferencesJson(self: Selections) ![]u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"version":1,"language":"{s}","locale":"{s}","timezone":"{s}","keyboard":"{s}"}}
        , .{ self.languageCode(), self.locale(), self.timezone(), self.keyboard() });
    }
};

// Presets may only select values from this fixed vocabulary. Anything a
// hand-edited file fails to match keeps the DINX default, so no preset string
// can reach an environment, gsettings or dconf value verbatim.
fn parseLanguage(value: []const u8) ?Language {
    if (std.mem.eql(u8, value, "pt-BR")) return .pt_br;
    if (std.mem.eql(u8, value, "en-US")) return .en_us;
    return null;
}

fn parseLocation(value: []const u8) ?Location {
    if (std.mem.eql(u8, value, "America/Sao_Paulo")) return .sao_paulo;
    if (std.mem.eql(u8, value, "UTC")) return .utc;
    return null;
}

fn parseTheme(value: []const u8) ?Theme {
    if (std.mem.eql(u8, value, "DINX")) return .dinx;
    if (std.mem.eql(u8, value, "Skeuos")) return .skeuos;
    if (std.mem.eql(u8, value, "Orchis")) return .orchis;
    if (std.mem.eql(u8, value, "Fluent")) return .fluent;
    if (std.mem.eql(u8, value, "Jasper")) return .jasper;
    return null;
}

fn parseVariant(value: []const u8) ?Variant {
    if (std.mem.eql(u8, value, "dark")) return .dark;
    if (std.mem.eql(u8, value, "light")) return .light;
    return null;
}

fn parseCorners(value: []const u8) ?Corners {
    if (std.mem.eql(u8, value, "rounded")) return .rounded;
    if (std.mem.eql(u8, value, "square")) return .square;
    return null;
}

fn parseBar(value: []const u8) ?Bar {
    if (std.mem.eql(u8, value, "top")) return .top;
    if (std.mem.eql(u8, value, "bottom")) return .bottom;
    return null;
}

fn parseDock(value: []const u8) ?Dock {
    if (std.mem.eql(u8, value, "none")) return .none;
    if (std.mem.eql(u8, value, "left")) return .left;
    if (std.mem.eql(u8, value, "right")) return .right;
    if (std.mem.eql(u8, value, "bottom")) return .bottom;
    return null;
}

fn presetString(root: std.json.Value, key: []const u8) ?[]const u8 {
    if (root != .object) return null;
    const item = root.object.get(key) orelse return null;
    if (item != .string) return null;
    return item.string;
}

fn applyPreset(root: std.json.Value, selections: *Selections) void {
    if (presetString(root, "language")) |value| {
        if (parseLanguage(value)) |parsed| selections.language = parsed;
    }
    if (presetString(root, "timezone")) |value| {
        if (parseLocation(value)) |parsed| selections.location = parsed;
    }
    if (presetString(root, "theme")) |value| {
        if (parseTheme(value)) |parsed| selections.theme = parsed;
    }
    if (presetString(root, "variant")) |value| {
        if (parseVariant(value)) |parsed| selections.variant = parsed;
    }
    if (presetString(root, "corners")) |value| {
        if (parseCorners(value)) |parsed| selections.corners = parsed;
    }
    if (presetString(root, "bar")) |value| {
        if (parseBar(value)) |parsed| selections.bar = parsed;
    }
    if (presetString(root, "dock")) |value| {
        if (parseDock(value)) |parsed| selections.dock = parsed;
    }
}

const Paths = struct {
    marker: []const u8,
    appearance: []const u8,
    installer_preferences: []const u8,
    shell_css: []const u8,
};

/// Absolute environment values only: a relative or empty base has no safe
/// meaning for a config directory, and the caller falls back to exit 0.
fn envAbsolute(environ: *std.process.Environ.Map, key: []const u8) ?[]const u8 {
    const value = environ.get(key) orelse return null;
    if (value.len == 0 or value[0] != '/') return null;
    return value;
}

fn join(allocator_to_use: std.mem.Allocator, base: []const u8, suffix: []const u8) ?[]const u8 {
    return std.fmt.allocPrint(allocator_to_use, "{s}{s}", .{ base, suffix }) catch null;
}

/// `${XDG_CONFIG_HOME:-$HOME/.config}` and the matching state-home rule; no
/// usable base means there is nowhere private to write, so nothing happens.
fn resolvePaths(environ: *std.process.Environ.Map) ?Paths {
    const arena = environ.allocator;
    const home = envAbsolute(environ, "HOME");
    const config_home: []const u8 = envAbsolute(environ, "XDG_CONFIG_HOME") orelse
        (if (home) |base| join(arena, base, "/.config") orelse return null else return null);
    const state_home: []const u8 = envAbsolute(environ, "XDG_STATE_HOME") orelse
        (if (home) |base| join(arena, base, "/.local/state") orelse return null else return null);
    return .{
        .marker = join(arena, state_home, "/dinx/desktop-first-run-complete") orelse return null,
        .appearance = join(arena, config_home, "/dinx/appearance.json") orelse return null,
        .installer_preferences = join(arena, config_home, "/dinx/installer-preferences.json") orelse return null,
        .shell_css = join(arena, config_home, "/morghulis/main.css") orelse return null,
    };
}

/// Every failure path exits 0: the DINX desktop must always come up, with
/// defaults, even when the wizard has no display or no writable config home.
fn finishOk() noreturn {
    std.process.exit(0);
}

fn stdoutWrite(io: std.Io, text: []const u8) void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    writer.interface.writeAll(text) catch return;
    writer.interface.flush() catch {};
}

fn pathExists(io: std.Io, absolute_path: []const u8) bool {
    std.Io.Dir.accessAbsolute(io, absolute_path, .{}) catch return false;
    return true;
}

fn isReadable(io: std.Io, absolute_path: []const u8) bool {
    std.Io.Dir.accessAbsolute(io, absolute_path, .{ .read = true }) catch return false;
    return true;
}

fn createOneDir(io: std.Io, absolute_path: []const u8) void {
    if (pathExists(io, absolute_path)) return;
    std.Io.Dir.createDirAbsolute(io, absolute_path, std.Io.Dir.Permissions.fromMode(0o700)) catch return;
    // mkdir obeys the process umask, so the private mode is re-applied.
    std.Io.Dir.setFilePermissions(.cwd(), io, absolute_path, std.Io.Dir.Permissions.fromMode(0o700), .{}) catch {};
}

fn ensurePrivateDir(io: std.Io, absolute_path: []const u8) void {
    var index: usize = 1;
    while (index < absolute_path.len) : (index += 1) {
        if (absolute_path[index] != '/') continue;
        createOneDir(io, absolute_path[0..index]);
    }
    createOneDir(io, absolute_path);
}

/// Owner-only atomic write: a 0600 temporary file is chmod'ed (the same effect
/// as `umask 077`) and renamed over the target, never clobbering on failure.
fn writePrivateFileAtomic(io: std.Io, absolute_path: []const u8, data: []const u8) void {
    const directory = std.fs.path.dirname(absolute_path) orelse return;
    ensurePrivateDir(io, directory);
    const temporary = std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ absolute_path, std.c.getpid() }) catch return;
    defer allocator.free(temporary);
    const file = std.Io.Dir.createFileAbsolute(io, temporary, .{
        .truncate = true,
        .permissions = std.Io.Dir.Permissions.fromMode(0o600),
    }) catch return;
    defer file.close(io);
    file.writeStreamingAll(io, data) catch {
        std.Io.Dir.deleteFileAbsolute(io, temporary) catch {};
        return;
    };
    file.setPermissions(io, std.Io.Dir.Permissions.fromMode(0o600)) catch {
        std.Io.Dir.deleteFileAbsolute(io, temporary) catch {};
        return;
    };
    std.Io.Dir.renameAbsolute(temporary, absolute_path, io) catch {
        std.Io.Dir.deleteFileAbsolute(io, temporary) catch {};
        return;
    };
}

/// Fire-and-forget spawn; every caller ignores the child result on purpose.
fn spawnIgnored(argv: []const [*:0]const u8, search_path: bool) void {
    var child_argv: [8]?[*:0]u8 = @splat(null);
    if (argv.len >= child_argv.len) return;
    for (argv, 0..) |arg, index| child_argv[index] = @constCast(arg);
    var error_value: ?*c.GError = null;
    const flags: c.GSpawnFlags = if (search_path) @intCast(c.G_SPAWN_SEARCH_PATH) else 0;
    _ = c.g_spawn_sync(null, @ptrCast(&child_argv), null, flags, null, null, null, null, null, &error_value);
    if (error_value) |failure| c.g_error_free(failure);
}

fn programAvailable(name: [*:0]const u8) bool {
    const found = c.g_find_program_in_path(name) orelse return false;
    c.g_free(@ptrCast(found));
    return true;
}

fn barAnchorSchemaAvailable() bool {
    const source = c.g_settings_schema_source_get_default() orelse return false;
    const schema = c.g_settings_schema_source_lookup(source, morghulis_schema, 1) orelse return false;
    defer c.g_settings_schema_unref(schema);
    return c.g_settings_schema_has_key(schema, morghulis_bar_key) != 0;
}

fn applyBarSetting(bar: Bar) void {
    // g_settings_new aborts when the schema id is unknown, so the explicit
    // schema and key lookup is what keeps a system without Morghulis alive.
    if (!barAnchorSchemaAvailable()) return;
    const settings = c.g_settings_new(morghulis_schema) orelse return;
    defer c.g_object_unref(@ptrCast(settings));
    const anchor: [*:0]const u8 = switch (bar) {
        .top => "top",
        .bottom => "bottom",
    };
    _ = c.g_settings_set_string(settings, morghulis_bar_key, anchor);
}

fn applyDconfColorScheme(selections: Selections) void {
    if (!programAvailable("dconf")) return;
    const value = std.fmt.allocPrintSentinel(allocator, "'{s}'", .{selections.colorScheme()}, 0) catch return;
    defer allocator.free(value);
    spawnIgnored(&.{ "dconf", "write", dconf_color_scheme_path, value.ptr }, true);
}

fn reloadDock() void {
    spawnIgnored(&.{ "/usr/bin/pkill", "-HUP", "dinx-dock" }, false);
}

const App = struct {
    application: *c.AdwApplication,
    io: std.Io,
    paths: Paths,
    selections: Selections = .{},
    settled: bool = false,
    window_ready: bool = false,
    stack: ?*c.GtkStack = null,
    language_dropdown: ?*c.GtkDropDown = null,
    location_dropdown: ?*c.GtkDropDown = null,
    theme_dropdown: ?*c.GtkDropDown = null,
    dark_button: ?*c.GtkCheckButton = null,
    corners_button: ?*c.GtkCheckButton = null,
    bar_top_button: ?*c.GtkCheckButton = null,
    bar_bottom_button: ?*c.GtkCheckButton = null,
    dock_none_button: ?*c.GtkCheckButton = null,
    dock_left_button: ?*c.GtkCheckButton = null,
    dock_right_button: ?*c.GtkCheckButton = null,
    dock_bottom_button: ?*c.GtkCheckButton = null,

    /// Reads the live widget state into the selection record.
    fn collect(self: *App) void {
        if (self.language_dropdown) |dropdown| {
            self.selections.language = if (c.gtk_drop_down_get_selected(dropdown) == 1) .en_us else .pt_br;
        }
        if (self.location_dropdown) |dropdown| {
            self.selections.location = if (c.gtk_drop_down_get_selected(dropdown) == 1) .utc else .sao_paulo;
        }
        if (self.theme_dropdown) |dropdown| {
            self.selections.theme = switch (c.gtk_drop_down_get_selected(dropdown)) {
                1 => .skeuos,
                2 => .orchis,
                3 => .fluent,
                4 => .jasper,
                else => .dinx,
            };
        }
        if (self.dark_button) |button| {
            self.selections.variant = if (c.gtk_check_button_get_active(button) != 0) .dark else .light;
        }
        if (self.corners_button) |button| {
            self.selections.corners = if (c.gtk_check_button_get_active(button) != 0) .rounded else .square;
        }
        if (self.bar_top_button) |button| {
            self.selections.bar = if (c.gtk_check_button_get_active(button) != 0) .top else .bottom;
        }
        if (self.dock_none_button) |button| {
            if (c.gtk_check_button_get_active(button) != 0) self.selections.dock = .none;
        }
        if (self.dock_left_button) |button| {
            if (c.gtk_check_button_get_active(button) != 0) self.selections.dock = .left;
        }
        if (self.dock_right_button) |button| {
            if (c.gtk_check_button_get_active(button) != 0) self.selections.dock = .right;
        }
        if (self.dock_bottom_button) |button| {
            if (c.gtk_check_button_get_active(button) != 0) self.selections.dock = .bottom;
        }
    }

    /// Writes every output, applies the shell settings, and leaves the marker
    /// so the first-run wizard never nags a second time.
    fn commit(self: *App, selections: Selections) void {
        if (self.settled) return;
        self.settled = true;
        if (selections.appearanceJson()) |json| {
            defer allocator.free(json);
            writePrivateFileAtomic(self.io, self.paths.appearance, json);
        } else |_| {}
        if (!pathExists(self.io, self.paths.installer_preferences)) {
            if (selections.installerPreferencesJson()) |json| {
                defer allocator.free(json);
                writePrivateFileAtomic(self.io, self.paths.installer_preferences, json);
            } else |_| {}
        }
        applyBarSetting(selections.bar);
        reloadDock();
        writePrivateFileAtomic(self.io, self.paths.shell_css, shell_css);
        applyDconfColorScheme(selections);
        writePrivateFileAtomic(self.io, self.paths.marker, "");
    }

    fn gotoPage(self: *App, name: [*:0]const u8) void {
        if (self.stack) |stack| c.gtk_stack_set_visible_child_name(stack, name);
    }

    fn makePage(self: *App, name: [*:0]const u8, heading: [*:0]const u8) ?*c.GtkWidget {
        const page = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 10) orelse return null;
        c.gtk_widget_set_margin_start(page, 24);
        c.gtk_widget_set_margin_end(page, 24);
        c.gtk_widget_set_margin_top(page, 20);
        c.gtk_widget_set_margin_bottom(page, 24);
        const title = c.gtk_label_new(heading) orelse return page;
        c.gtk_label_set_xalign(@ptrCast(title), 0.0);
        c.gtk_widget_add_css_class(title, "title-3");
        c.gtk_widget_set_margin_bottom(title, 8);
        c.gtk_box_append(@ptrCast(page), title);
        if (self.stack) |stack| _ = c.gtk_stack_add_titled(stack, page, name, heading);
        return page;
    }

    fn addLabel(self: *App, page: *c.GtkWidget, text: [*:0]const u8) void {
        _ = self;
        const label = c.gtk_label_new(text) orelse return;
        c.gtk_label_set_xalign(@ptrCast(label), 0.0);
        c.gtk_box_append(@ptrCast(page), label);
    }

    fn addDropdown(self: *App, page: *c.GtkWidget, strings: anytype) ?*c.GtkDropDown {
        _ = self;
        const widget = c.gtk_drop_down_new_from_strings(strings) orelse return null;
        c.gtk_widget_set_hexpand(widget, 1);
        c.gtk_box_append(@ptrCast(page), widget);
        return @ptrCast(widget);
    }

    /// Radio behaviour comes from a GtkCheckButton group: the first member is
    /// the group leader and later members join it.
    fn addCheck(self: *App, page: *c.GtkWidget, label: [*:0]const u8, group: ?*c.GtkCheckButton, active: bool) ?*c.GtkCheckButton {
        _ = self;
        const widget = c.gtk_check_button_new_with_label(label) orelse return null;
        const button: *c.GtkCheckButton = @ptrCast(widget);
        if (group) |leader| c.gtk_check_button_set_group(button, leader);
        c.gtk_check_button_set_active(button, if (active) 1 else 0);
        c.gtk_box_append(@ptrCast(page), widget);
        return button;
    }

    fn addButton(self: *App, page: *c.GtkWidget, label: [*:0]const u8, callback: anytype) void {
        const button = c.gtk_button_new_with_label(label) orelse return;
        connect(button, "clicked", callback, self);
        c.gtk_widget_set_halign(button, c.GTK_ALIGN_END);
        c.gtk_widget_add_css_class(button, "suggested-action");
        c.gtk_box_append(@ptrCast(page), button);
    }

    fn buildWindow(self: *App) void {
        if (self.window_ready) return;
        self.window_ready = true;

        const window_widget = c.adw_application_window_new(@ptrCast(self.application)) orelse return;
        const window: *c.AdwApplicationWindow = @ptrCast(window_widget);
        c.gtk_window_set_title(@ptrCast(window), window_title);
        c.gtk_window_set_resizable(@ptrCast(window), 0);
        c.gtk_window_set_default_size(@ptrCast(window), 560, 420);
        connect(window, "close-request", &onCloseRequest, self);

        const toolbar = c.adw_toolbar_view_new() orelse return;
        const header = c.adw_header_bar_new() orelse return;
        c.adw_header_bar_set_show_title(@ptrCast(header), 1);
        const heading = c.adw_window_title_new("DINX", "Configuração inicial / Initial setup") orelse return;
        c.adw_header_bar_set_title_widget(@ptrCast(header), heading);
        c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar), @ptrCast(header));

        const stack_widget = c.gtk_stack_new() orelse return;
        const stack: *c.GtkStack = @ptrCast(stack_widget);
        self.stack = stack;
        c.gtk_stack_set_hhomogeneous(stack, 1);
        c.gtk_stack_set_vhomogeneous(stack, 1);
        c.gtk_widget_set_vexpand(stack_widget, 1);
        c.gtk_widget_set_margin_top(stack_widget, 8);
        c.gtk_widget_set_margin_bottom(stack_widget, 8);

        // P1 language.
        const language_page = self.makePage("language", "Idioma / Language") orelse return;
        self.addLabel(language_page, "Idioma do sistema / System language");
        self.language_dropdown = self.addDropdown(language_page, &language_strings);
        if (self.language_dropdown) |dropdown| c.gtk_drop_down_set_selected(dropdown, 0);
        self.addButton(language_page, "Continuar / Continue", &onLanguageContinue);

        // P2 location.
        const location_page = self.makePage("location", "Localização / Location") orelse return;
        self.addLabel(location_page, "Fuso horário / Time zone");
        self.location_dropdown = self.addDropdown(location_page, &location_strings);
        if (self.location_dropdown) |dropdown| c.gtk_drop_down_set_selected(dropdown, 0);
        self.addButton(location_page, "Continuar / Continue", &onLocationContinue);

        // P3 appearance.
        const appearance_page = self.makePage("appearance", "Aparência / Appearance") orelse return;
        self.addLabel(appearance_page, "Tema / Theme");
        self.theme_dropdown = self.addDropdown(appearance_page, &theme_strings);
        if (self.theme_dropdown) |dropdown| c.gtk_drop_down_set_selected(dropdown, 0);
        self.dark_button = self.addCheck(appearance_page, "Tema escuro / Dark theme", null, true);
        self.corners_button = self.addCheck(appearance_page, "Cantos arredondados / Rounded corners", null, true);
        self.addButton(appearance_page, "Continuar / Continue", &onAppearanceContinue);

        // P4 bar: the top button leads the group, bottom is the DINX default.
        const bar_page = self.makePage("bar", "Barra / Bar") orelse return;
        self.bar_top_button = self.addCheck(bar_page, "Barra superior / Top bar", null, false);
        self.bar_bottom_button = self.addCheck(bar_page, "Barra inferior / Bottom bar", self.bar_top_button, true);
        self.addButton(bar_page, "Continuar / Continue", &onBarContinue);

        // P5 dock plus the single Apply action that commits the wizard.
        const dock_page = self.makePage("dock", "Dock") orelse return;
        self.dock_none_button = self.addCheck(dock_page, "Nenhum / None", null, false);
        self.dock_left_button = self.addCheck(dock_page, "Esquerda / Left", self.dock_none_button, true);
        self.dock_right_button = self.addCheck(dock_page, "Direita / Right", self.dock_none_button, false);
        self.dock_bottom_button = self.addCheck(dock_page, "Inferior / Bottom", self.dock_none_button, false);
        self.addButton(dock_page, "Aplicar / Apply", &onApplyClicked);

        c.adw_application_window_set_content(window, stack_widget);
        c.gtk_stack_set_visible_child_name(stack, "language");
        c.gtk_window_present(@ptrCast(window));
    }
};

const language_strings = [_:null]?[*:0]const u8{
    "Português (Brasil)",
    "English (United States)",
    null,
};

const location_strings = [_:null]?[*:0]const u8{
    "Brasil — São Paulo (America/Sao_Paulo)",
    "United States — UTC",
    null,
};

const theme_strings = [_:null]?[*:0]const u8{
    "DINX",
    "Skeuos",
    "Orchis",
    "Fluent",
    "Jasper",
    null,
};

fn connect(instance: anytype, signal: [*:0]const u8, callback: anytype, app: *App) void {
    _ = c.g_signal_connect_data(@ptrCast(instance), signal, @ptrCast(callback), @ptrCast(app), null, 0);
}

fn asApp(data: ?*anyopaque) *App {
    return @ptrCast(@alignCast(data));
}

fn onActivate(_: *c.GApplication, data: ?*anyopaque) callconv(.c) void {
    asApp(data).buildWindow();
}

/// Closing before Apply is a skip, not a cancel: unchanged defaults, marker
/// written, exit 0, because first-run must never re-nag.
fn onCloseRequest(_: *c.GtkWindow, data: ?*anyopaque) callconv(.c) c.gboolean {
    asApp(data).commit(.{});
    return 0;
}

fn onLanguageContinue(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).gotoPage("location");
}

fn onLocationContinue(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).gotoPage("appearance");
}

fn onAppearanceContinue(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).gotoPage("bar");
}

fn onBarContinue(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).gotoPage("dock");
}

fn onApplyClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const app = asApp(data);
    app.collect();
    app.commit(app.selections);
    c.g_application_quit(@ptrCast(app.application));
}

/// Reads $DINX_FIRST_RUN_PRESET. null covers unset, non-absolute, unreadable
/// and corrupt files, each of which falls back to the interactive wizard.
fn readPreset(io: std.Io, environ: *std.process.Environ.Map) ?Selections {
    const preset_path = envAbsolute(environ, "DINX_FIRST_RUN_PRESET") orelse return null;
    if (!isReadable(io, preset_path)) return null;
    const data = std.Io.Dir.readFileAlloc(.cwd(), io, preset_path, allocator, .limited(64 * 1024)) catch return null;
    defer allocator.free(data);
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch return null;
    defer parsed.deinit();
    var selections = Selections{};
    applyPreset(parsed.value, &selections);
    return selections;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 0) finishOk();
    var dry_run = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--version")) {
            stdoutWrite(io, version_string ++ "\n");
            finishOk();
        }
        if (std.mem.eql(u8, arg, "--dry-run")) dry_run = true;
    }

    // --dry-run and --version never open a display and never write anything.
    if (dry_run) {
        const selections = readPreset(io, init.environ_map) orelse Selections{};
        if (selections.appearanceJson()) |json| {
            defer allocator.free(json);
            stdoutWrite(io, json);
            stdoutWrite(io, "\n");
        } else |_| {}
        finishOk();
    }

    const paths = resolvePaths(init.environ_map) orelse finishOk();
    if (pathExists(io, paths.marker)) finishOk();

    var app = try allocator.create(App);
    app.* = .{
        .application = undefined,
        .io = io,
        .paths = paths,
    };

    // A preset means unattended setup: apply it and leave without a display.
    if (readPreset(io, init.environ_map)) |selections| {
        app.commit(selections);
        finishOk();
    }

    // No display means the wizard cannot nag, so the session gets exactly the
    // same defaults-plus-marker result as closing the window early.
    if (c.gtk_init_check() == 0) {
        app.commit(.{});
        finishOk();
    }

    const application = c.adw_application_new(app_id, c.G_APPLICATION_NON_UNIQUE) orelse {
        app.commit(.{});
        finishOk();
    };
    app.application = application;
    connect(application, "activate", &onActivate, app);
    _ = c.g_application_run(@ptrCast(application), 0, null);
    // Closing the window makes GTK quit the loop; under some window managers
    // no close-request is emitted, so leaving unsettled is itself the skip
    // signal: unchanged defaults, marker written, exit 0, never re-nag.
    app.commit(.{});
    finishOk();
}
