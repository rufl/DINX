const std = @import("std");
const c = @import("c");

const allocator = std.heap.c_allocator;

const App = struct {
    application: *c.AdwApplication,
    home: []const u8,
    status_label: *c.GtkLabel = undefined,
    window_ready: bool = false,
    smoke: bool = false,

    fn init(application: *c.AdwApplication, home: []const u8, smoke: bool) App {
        return .{ .application = application, .home = home, .smoke = smoke };
    }

    fn buildWindow(self: *App) void {
        if (self.window_ready) return;
        self.window_ready = true;

        const window_widget = c.adw_application_window_new(@ptrCast(self.application)) orelse return;
        const window: *c.AdwApplicationWindow = @ptrCast(window_widget);
        c.gtk_window_set_title(@ptrCast(window), "Seafoam Settings");
        c.gtk_window_set_default_size(@ptrCast(window), 920, 680);
        c.gtk_window_set_resizable(@ptrCast(window), 1);

        const toolbar = c.adw_toolbar_view_new() orelse return;
        const header = c.adw_header_bar_new() orelse return;
        c.adw_header_bar_set_show_title(@ptrCast(header), 1);
        c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar), @ptrCast(header));
        const title = c.gtk_label_new("Seafoam Settings") orelse return;
        c.gtk_widget_add_css_class(title, "title-2");
        c.adw_header_bar_set_title_widget(@ptrCast(header), title);

        const scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_scrolled_window_set_policy(@ptrCast(scroll), c.GTK_POLICY_NEVER, c.GTK_POLICY_AUTOMATIC);
        const content = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse return;
        c.gtk_widget_add_css_class(content, "seafoam-settings");
        c.gtk_widget_set_margin_start(content, 24);
        c.gtk_widget_set_margin_end(content, 24);
        c.gtk_widget_set_margin_top(content, 20);
        c.gtk_widget_set_margin_bottom(content, 24);

        const heading = c.gtk_label_new("Seafoam desktop settings") orelse return;
        c.gtk_label_set_xalign(@ptrCast(heading), 0.0);
        c.gtk_widget_add_css_class(heading, "title-1");
        c.gtk_box_append(@ptrCast(content), heading);

        const intro = c.gtk_label_new("One safe starting point for display, session and Seafoam tools. Specialist applications remain in control; these buttons only open fixed actions or user configuration files.") orelse return;
        c.gtk_label_set_xalign(@ptrCast(intro), 0.0);
        c.gtk_label_set_wrap(@ptrCast(intro), 1);
        c.gtk_widget_add_css_class(intro, "dim-label");
        c.gtk_widget_set_margin_bottom(intro, 18);
        c.gtk_box_append(@ptrCast(content), intro);

        appendSectionTitle(content, "Displays");
        const displays = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_box_append(@ptrCast(displays), makeButton("Display layout", "Open the interactive Wayland display editor; closing it saves a Shikane profile", &onDisplaysClicked, self));
        c.gtk_box_append(@ptrCast(displays), makeButton("Save Shikane", "Save the current Wayland layout as the DINX wdisplays profile", &onShikaneExportClicked, self));
        c.gtk_box_append(@ptrCast(displays), makeButton("Edit Shikane", "Edit the user Shikane configuration in a terminal", &onShikaneEditClicked, self));
        c.gtk_box_append(@ptrCast(content), displays);

        appendSectionTitle(content, "Session");
        const session = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_box_append(@ptrCast(session), makeButton("Dinit services", "Open the Dinit service and profile manager", &onDinitClicked, self));
        c.gtk_box_append(@ptrCast(session), makeButton("DINX controls", "Open the DINX system control center", &onDinxPanelClicked, self));
        c.gtk_box_append(@ptrCast(session), makeButton("Qt appearance", "Open Qt6 appearance settings", &onQtClicked, self));
        c.gtk_box_append(@ptrCast(content), session);

        appendSectionTitle(content, "Seafoam tools");
        const seafoam = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_box_append(@ptrCast(seafoam), makeButton("Dome", "Open the bundled Seafoam resource monitor", &onDomeClicked, self));
        c.gtk_box_append(@ptrCast(content), seafoam);

        const note = c.gtk_label_new("ZLS is bundled for Nocted and other Zig-aware editors.") orelse return;
        c.gtk_label_set_xalign(@ptrCast(note), 0.0);
        c.gtk_label_set_wrap(@ptrCast(note), 1);
        c.gtk_widget_add_css_class(note, "dim-label");
        c.gtk_widget_set_margin_top(note, 10);
        c.gtk_box_append(@ptrCast(content), note);

        const footer = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_widget_set_margin_top(footer, 18);
        self.status_label = @ptrCast(c.gtk_label_new("Ready") orelse return);
        c.gtk_label_set_xalign(self.status_label, 0.0);
        c.gtk_widget_set_hexpand(@ptrCast(@alignCast(self.status_label)), 1);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.status_label)), "dim-label");
        c.gtk_box_append(@ptrCast(footer), @ptrCast(@alignCast(self.status_label)));
        c.gtk_box_append(@ptrCast(content), footer);

        c.gtk_scrolled_window_set_child(@ptrCast(scroll), content);
        c.adw_toolbar_view_set_content(@ptrCast(toolbar), scroll);
        c.adw_application_window_set_content(window, toolbar);
        applyTheme();
        c.gtk_window_present(@ptrCast(window));
        if (self.smoke) _ = c.g_timeout_add(600, @ptrCast(&onSmokeTimeout), self);
    }

    fn launch(self: *App, argv: []const []const u8) void {
        var child_argv: [16]?[*:0]u8 = undefined;
        var owned: [16]?[]u8 = undefined;
        for (&child_argv) |*item| item.* = null;
        for (&owned) |*item| item.* = null;
        defer for (owned) |item| if (item) |value| allocator.free(value);
        if (argv.len >= child_argv.len) {
            self.setStatusError("Too many launch arguments");
            return;
        }
        for (argv, 0..) |arg, index| {
            const value = allocator.dupeSentinel(u8, arg, 0) catch {
                self.setStatusError("Unable to prepare launch arguments");
                return;
            };
            owned[index] = value;
            child_argv[index] = value.ptr;
        }
        var error_value: ?*c.GError = null;
        const launched = c.g_spawn_async(null, @ptrCast(&child_argv), null, c.G_SPAWN_SEARCH_PATH, null, null, null, &error_value);
        if (launched == 0) {
            if (error_value) |error_ptr| {
                self.setStatusError(std.mem.span(error_ptr.message));
                c.g_error_free(error_ptr);
            } else self.setStatusError("Unable to launch Seafoam tool");
            return;
        }
        self.setStatus("Tool launched");
    }

    fn launchConfig(self: *App, relative_path: []const u8, app_id: []const u8) void {
        const path = std.fs.path.join(allocator, &.{ self.home, relative_path }) catch {
            self.setStatusError("Unable to resolve configuration path");
            return;
        };
        defer allocator.free(path);
        self.launch(&.{ "foot", app_id, "-e", "nano", path });
    }

    fn setStatus(self: *App, text: []const u8) void {
        const value = allocator.dupeSentinel(u8, text, 0) catch return;
        defer allocator.free(value);
        c.gtk_label_set_text(self.status_label, value);
        c.gtk_widget_remove_css_class(@ptrCast(@alignCast(self.status_label)), "error");
    }

    fn setStatusError(self: *App, text: []const u8) void {
        const value = allocator.dupeSentinel(u8, text, 0) catch return;
        defer allocator.free(value);
        c.gtk_label_set_text(self.status_label, value);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.status_label)), "error");
    }
};

fn appendSectionTitle(parent: *c.GtkWidget, text: [*:0]const u8) void {
    const label = c.gtk_label_new(text) orelse return;
    c.gtk_label_set_xalign(@ptrCast(label), 0.0);
    c.gtk_widget_add_css_class(label, "heading");
    c.gtk_widget_set_margin_top(label, 18);
    c.gtk_widget_set_margin_bottom(label, 6);
    c.gtk_box_append(@ptrCast(parent), label);
}

fn makeButton(label: [*:0]const u8, tooltip: [*:0]const u8, callback: anytype, app: *App) *c.GtkWidget {
    const button = c.gtk_button_new_with_label(label) orelse return c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0).?;
    c.gtk_widget_set_tooltip_text(button, tooltip);
    connect(button, "clicked", callback, app);
    return button;
}

fn onActivate(_: *c.GApplication, data: ?*anyopaque) callconv(.c) void {
    asApp(data).buildWindow();
}

fn onDisplaysClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"dinx-wdisplays"});
}

fn onShikaneExportClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "foot", "--app-id=seafoam-settings-shikane-export", "-e", "dinx-save-shikane-profile" });
}

fn onShikaneEditClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launchConfig(".config/shikane/config.toml", "--app-id=seafoam-settings-shikane");
}

fn onDinitClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"dinitui"});
}

fn onDinxPanelClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"dinxpanel"});
}

fn onQtClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"qt6ct"});
}


fn onDomeClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"dome"});
}

fn onSmokeTimeout(data: ?*anyopaque) callconv(.c) c.gboolean {
    std.debug.print("seafoam_settings_smoke surface=true\n", .{});
    c.g_application_quit(@ptrCast(asApp(data).application));
    return 0;
}

fn asApp(data: ?*anyopaque) *App {
    return @ptrCast(@alignCast(data.?));
}

fn connect(instance: anytype, signal: [*:0]const u8, callback: anytype, app: *App) void {
    _ = c.g_signal_connect_data(@ptrCast(instance), signal, @ptrCast(callback), @ptrCast(app), null, 0);
}

fn applyTheme() void {
    const provider = c.gtk_css_provider_new() orelse return;
    const css =
        ".seafoam-settings { background: #0b0d12; color: #d7dde8; }\n" ++
        "button.suggested-action { background-color: #8fb8ff; color: #0b0d12; }\n" ++
        "label.heading { color: #8fb8ff; font-weight: 700; }\n";
    c.gtk_css_provider_load_from_data(provider, css.ptr, @intCast(css.len));
    const display = c.gdk_display_get_default() orelse return;
    c.gtk_style_context_add_provider_for_display(display, @ptrCast(provider), c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    c.g_object_unref(@ptrCast(provider));
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var smoke = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--smoke")) smoke = true;
    }
    const application = c.adw_application_new("org.seafoam.Settings", c.G_APPLICATION_DEFAULT_FLAGS) orelse return error.ApplicationCreationFailed;
    const app = try allocator.create(App);
    app.* = App.init(application, init.environ_map.get("HOME") orelse "", smoke);
    defer {
        allocator.destroy(app);
        c.g_object_unref(@ptrCast(application));
    }
    connect(application, "activate", &onActivate, app);
    const status = c.g_application_run(@ptrCast(application), 0, null);
    if (status != 0) return error.ApplicationFailed;
}
