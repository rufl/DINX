const std = @import("std");
const dinit = @import("dinit.zig");

const c = @import("c");

const allocator = std.heap.c_allocator;

const action_order = [_]dinit.Action{
    .start,
    .stop,
    .restart,
    .reload,
    .enable,
    .disable,
    .wake,
    .release,
    .unpin,
    .unload,
    .trigger,
    .untrigger,
    .is_started,
    .is_failed,
    .add_dep,
    .rm_dep,
    .setenv,
    .unsetenv,
    .catlog,
    .clear_log,
    .signal,
    .signal_list,
    .shutdown,
};

const action_strings = [_:null]?[*:0]const u8{
    "Start",
    "Stop",
    "Restart",
    "Reload description",
    "Enable via boot",
    "Disable via boot",
    "Wake",
    "Release activation",
    "Unpin",
    "Unload",
    "Trigger",
    "Untrigger",
    "Check started",
    "Check failed",
    "Add dependency",
    "Remove dependency",
    "Set environment",
    "Unset environment",
    "Show log",
    "Clear log",
    "Send signal",
    "List signals",
    "Shutdown Dinit",
    null,
};

const scope_strings = [_:null]?[*:0]const u8{ "System services", "User services", null };

const App = struct {
    application: *c.AdwApplication,
    io: std.Io,
    home: []const u8,
    service_list: *c.GtkListBox = undefined,
    search_entry: *c.GtkSearchEntry = undefined,
    scope_dropdown: *c.GtkDropDown = undefined,
    action_dropdown: *c.GtkDropDown = undefined,
    signal_entry: *c.GtkEntry = undefined,
    arguments_entry: *c.GtkEntry = undefined,
    service_title: *c.GtkLabel = undefined,
    service_state: *c.GtkLabel = undefined,
    service_summary: *c.GtkLabel = undefined,
    output_view: *c.GtkTextView = undefined,
    log_view: *c.GtkTextView = undefined,
    status_label: *c.GtkLabel = undefined,
    spinner: *c.GtkSpinner = undefined,
    services: std.ArrayList(dinit.Service) = .empty,
    selected_name: ?[]u8 = null,
    scope: dinit.Scope = .system,
    smoke: bool = false,
    window_ready: bool = false,
    fn init(application: *c.AdwApplication, io: std.Io, home: []const u8, smoke: bool) App {
        return .{
            .application = application,
            .io = io,
            .home = home,
            .smoke = smoke,
        };
    }

    fn deinit(self: *App) void {
        dinit.deinitServices(allocator, &self.services);
        if (self.selected_name) |name| allocator.free(name);
    }

    fn buildWindow(self: *App) void {
        if (self.window_ready) return;
        self.window_ready = true;

        const window_widget = c.adw_application_window_new(@ptrCast(self.application)) orelse return;
        const window: *c.AdwApplicationWindow = @ptrCast(window_widget);
        c.gtk_window_set_title(@ptrCast(window), "DinitUI");
        c.gtk_window_set_default_size(@ptrCast(window), 1180, 760);
        c.gtk_window_set_resizable(@ptrCast(window), 1);

        const toolbar = c.adw_toolbar_view_new() orelse return;
        const header = c.adw_header_bar_new() orelse return;
        c.adw_header_bar_set_show_title(@ptrCast(header), 1);
        c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar), @ptrCast(header));

        const title = c.gtk_label_new("DinitUI") orelse return;
        c.gtk_widget_add_css_class(title, "title-2");
        c.adw_header_bar_set_title_widget(@ptrCast(header), title);

        const refresh_button = c.gtk_button_new_from_icon_name("view-refresh-symbolic") orelse return;
        c.gtk_widget_set_tooltip_text(refresh_button, "Refresh services");
        connect(refresh_button, "clicked", &onRefreshClicked, self);
        c.adw_header_bar_pack_end(@ptrCast(header), refresh_button);

        const scope = c.gtk_drop_down_new_from_strings(&scope_strings);
        if (scope == null) return;
        self.scope_dropdown = @ptrCast(scope.?);
        c.gtk_drop_down_set_selected(self.scope_dropdown, 0);
        c.gtk_widget_set_tooltip_text(scope.?, "Choose the Dinit instance to control");
        connect(scope.?, "notify::selected", &onScopeChanged, self);
        c.adw_header_bar_pack_start(@ptrCast(header), scope.?);

        const paned = c.gtk_paned_new(c.GTK_ORIENTATION_HORIZONTAL) orelse return;
        c.gtk_widget_set_vexpand(paned, 1);
        c.gtk_widget_set_hexpand(paned, 1);
        c.gtk_paned_set_position(@ptrCast(paned), 360);

        const sidebar = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse return;
        c.gtk_widget_set_size_request(sidebar, 280, -1);
        const search = c.gtk_search_entry_new() orelse return;
        self.search_entry = @ptrCast(search);
        c.gtk_widget_set_margin_start(search, 12);
        c.gtk_widget_set_margin_end(search, 12);
        c.gtk_widget_set_margin_top(search, 12);
        c.gtk_widget_set_margin_bottom(search, 8);
        c.gtk_widget_set_tooltip_text(search, "Filter loaded and discovered services");
        connect(search, "search-changed", &onSearchChanged, self);
        c.gtk_box_append(@ptrCast(sidebar), search);

        const list_scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_widget_set_vexpand(list_scroll, 1);
        c.gtk_scrolled_window_set_policy(@ptrCast(list_scroll), c.GTK_POLICY_NEVER, c.GTK_POLICY_AUTOMATIC);
        const list = c.gtk_list_box_new() orelse return;
        self.service_list = @ptrCast(list);
        c.gtk_list_box_set_selection_mode(self.service_list, c.GTK_SELECTION_SINGLE);
        c.gtk_list_box_set_activate_on_single_click(self.service_list, 1);
        c.gtk_widget_set_margin_start(list, 8);
        c.gtk_widget_set_margin_end(list, 8);
        c.gtk_scrolled_window_set_child(@ptrCast(list_scroll), list);
        c.gtk_box_append(@ptrCast(sidebar), list_scroll);
        c.gtk_paned_set_start_child(@ptrCast(paned), sidebar);

        const content = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse return;
        c.gtk_widget_set_vexpand(content, 1);
        c.gtk_widget_set_hexpand(content, 1);
        c.gtk_widget_set_margin_start(content, 20);
        c.gtk_widget_set_margin_end(content, 20);
        c.gtk_widget_set_margin_top(content, 16);
        c.gtk_widget_set_margin_bottom(content, 16);

        const service_header = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 4) orelse return;
        self.service_title = @ptrCast(c.gtk_label_new("Select a service") orelse return);
        c.gtk_label_set_xalign(self.service_title, 0.0);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.service_title)), "title-1");
        self.service_state = @ptrCast(c.gtk_label_new("No service selected") orelse return);
        c.gtk_label_set_xalign(self.service_state, 0.0);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.service_state)), "dim-label");
        self.service_summary = @ptrCast(c.gtk_label_new("Dinit services are supervised through dinitctl.") orelse return);
        c.gtk_label_set_xalign(self.service_summary, 0.0);
        c.gtk_label_set_wrap(self.service_summary, 1);
        c.gtk_label_set_wrap_mode(self.service_summary, c.PANGO_WRAP_WORD_CHAR);
        c.gtk_box_append(@ptrCast(service_header), @ptrCast(@alignCast(self.service_title)));
        c.gtk_box_append(@ptrCast(service_header), @ptrCast(@alignCast(self.service_state)));
        c.gtk_box_append(@ptrCast(service_header), @ptrCast(@alignCast(self.service_summary)));
        c.gtk_box_append(@ptrCast(content), service_header);

        const action_row = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_widget_set_margin_top(action_row, 16);
        c.gtk_widget_set_margin_bottom(action_row, 12);
        const action_dropdown = c.gtk_drop_down_new_from_strings(&action_strings);
        if (action_dropdown == null) return;
        self.action_dropdown = @ptrCast(action_dropdown.?);
        c.gtk_widget_set_hexpand(action_dropdown.?, 1);
        c.gtk_widget_set_tooltip_text(action_dropdown.?, "Dinit service operation");
        c.gtk_box_append(@ptrCast(action_row), action_dropdown.?);

        self.signal_entry = @ptrCast(c.gtk_entry_new() orelse return);
        c.gtk_editable_set_text(@ptrCast(self.signal_entry), "TERM");
        c.gtk_entry_set_placeholder_text(self.signal_entry, "Signal");
        c.gtk_widget_set_size_request(@ptrCast(@alignCast(self.signal_entry)), 72, -1);
        c.gtk_box_append(@ptrCast(action_row), @ptrCast(@alignCast(self.signal_entry)));

        const run_button = c.gtk_button_new_with_label("Run action") orelse return;
        c.gtk_widget_add_css_class(run_button, "suggested-action");
        c.gtk_widget_set_tooltip_text(run_button, "Run the selected dinitctl action");
        connect(run_button, "clicked", &onActionClicked, self);
        c.gtk_box_append(@ptrCast(action_row), run_button);
        c.gtk_box_append(@ptrCast(content), action_row);
        const arguments_row = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_widget_set_margin_bottom(arguments_row, 12);
        const arguments_label = c.gtk_label_new("Extra arguments") orelse return;
        c.gtk_label_set_xalign(@ptrCast(arguments_label), 0.0);
        c.gtk_widget_set_size_request(arguments_label, 140, -1);
        c.gtk_widget_set_tooltip_text(arguments_label, "Whitespace-separated safe arguments for dependency and environment actions");
        self.arguments_entry = @ptrCast(c.gtk_entry_new() orelse return);
        c.gtk_entry_set_placeholder_text(self.arguments_entry, "need target-service  |  KEY=value");
        c.gtk_widget_set_hexpand(@ptrCast(@alignCast(self.arguments_entry)), 1);
        c.gtk_widget_set_tooltip_text(
            @ptrCast(@alignCast(self.arguments_entry)),
            "No shell syntax. Use service names, dependency type plus target, KEY=value tokens, or CONFIRM for shutdown.",
        );
        c.gtk_box_append(@ptrCast(arguments_row), arguments_label);
        c.gtk_box_append(@ptrCast(arguments_row), @ptrCast(@alignCast(self.arguments_entry)));
        c.gtk_box_append(@ptrCast(content), arguments_row);

        const output_label = c.gtk_label_new("Service output") orelse return;
        c.gtk_label_set_xalign(@ptrCast(output_label), 0.0);
        c.gtk_widget_add_css_class(output_label, "heading");
        c.gtk_box_append(@ptrCast(content), output_label);
        const output_scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_widget_set_vexpand(output_scroll, 1);
        c.gtk_widget_set_size_request(output_scroll, -1, 220);
        self.output_view = @ptrCast(c.gtk_text_view_new() orelse return);
        c.gtk_text_view_set_editable(self.output_view, 0);
        c.gtk_text_view_set_cursor_visible(self.output_view, 0);
        c.gtk_text_view_set_monospace(self.output_view, 1);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.output_view)), "dinit-output");
        c.gtk_scrolled_window_set_child(@ptrCast(output_scroll), @ptrCast(@alignCast(self.output_view)));
        c.gtk_box_append(@ptrCast(content), output_scroll);

        const log_label = c.gtk_label_new("Service log buffer") orelse return;
        c.gtk_label_set_xalign(@ptrCast(log_label), 0.0);
        c.gtk_widget_add_css_class(log_label, "heading");
        c.gtk_widget_set_margin_top(log_label, 12);
        c.gtk_box_append(@ptrCast(content), log_label);
        const log_scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_widget_set_vexpand(log_scroll, 1);
        c.gtk_widget_set_size_request(log_scroll, -1, 160);
        self.log_view = @ptrCast(c.gtk_text_view_new() orelse return);
        c.gtk_text_view_set_editable(self.log_view, 0);
        c.gtk_text_view_set_cursor_visible(self.log_view, 0);
        c.gtk_text_view_set_monospace(self.log_view, 1);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.log_view)), "dinit-output");
        c.gtk_scrolled_window_set_child(@ptrCast(log_scroll), @ptrCast(@alignCast(self.log_view)));
        c.gtk_box_append(@ptrCast(content), log_scroll);
        const footer = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_widget_set_margin_top(footer, 12);
        self.spinner = @ptrCast(c.gtk_spinner_new() orelse return);
        c.gtk_widget_set_size_request(@ptrCast(@alignCast(self.spinner)), 24, 24);
        self.status_label = @ptrCast(c.gtk_label_new("Ready") orelse return);
        c.gtk_label_set_xalign(self.status_label, 0.0);
        c.gtk_widget_set_hexpand(@ptrCast(@alignCast(self.status_label)), 1);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.status_label)), "dim-label");
        c.gtk_box_append(@ptrCast(footer), @ptrCast(@alignCast(self.spinner)));
        c.gtk_box_append(@ptrCast(footer), @ptrCast(@alignCast(self.status_label)));
        c.gtk_box_append(@ptrCast(content), footer);

        c.gtk_paned_set_end_child(@ptrCast(paned), content);
        c.adw_toolbar_view_set_content(@ptrCast(toolbar), paned);
        c.adw_application_window_set_content(window, toolbar);
        applyTheme();
        c.gtk_window_present(@ptrCast(window));
        connect(self.service_list, "row-selected", &onRowSelected, self);
        self.setStatus("Ready");

        if (self.smoke) {
            _ = c.g_timeout_add(900, @ptrCast(&onSmokeTimeout), self);
        }
    }

    fn refresh(self: *App) void {
        self.setBusy("Refreshing service list…");
        var result = dinit.list(allocator, self.io, self.scope) catch |err| {
            self.setStatusError(@errorName(err));
            self.renderServices(&.{}) catch {};
            return;
        };
        defer result.deinit(allocator);

        var parsed = dinit.parseList(allocator, result.output) catch |err| {
            self.setStatusError(@errorName(err));
            return;
        };
        dinit.appendServiceFiles(allocator, self.io, &parsed, self.scope, self.home) catch {};
        dinit.deinitServices(allocator, &self.services);
        self.services = parsed;
        self.renderServices(self.services.items) catch |err| self.setStatusError(@errorName(err));
        if (!result.success) {
            self.setStatusError(preferredOutput(result));
        } else {
            self.setStatusFmt("{d} services discovered · {s}", .{ self.services.items.len, self.scope.label() });
        }
    }

    fn renderServices(self: *App, services: []const dinit.Service) !void {
        c.gtk_list_box_remove_all(self.service_list);
        const filter = std.mem.trim(u8, std.mem.span(c.gtk_editable_get_text(@ptrCast(self.search_entry))), " \t\r\n");
        var shown: usize = 0;
        for (services) |service| {
            if (filter.len > 0 and std.mem.indexOf(u8, service.name, filter) == null) continue;
            const row = try self.makeServiceRow(service);
            c.gtk_list_box_append(self.service_list, row);
            shown += 1;
        }
        if (shown == 0) {
            const empty = c.gtk_label_new(if (services.len == 0) "No loaded or discovered services" else "No services match the filter") orelse return;
            c.gtk_widget_set_margin_top(empty, 20);
            c.gtk_widget_set_margin_bottom(empty, 20);
            c.gtk_widget_add_css_class(empty, "dim-label");
            c.gtk_list_box_append(self.service_list, empty);
        } else if (self.selected_name) |selected| {
            var child = c.gtk_widget_get_first_child(@ptrCast(@alignCast(self.service_list)));
            while (child) |current| : (child = c.gtk_widget_get_next_sibling(current)) {
                if (std.mem.eql(u8, std.mem.span(c.gtk_widget_get_name(current)), selected)) {
                    c.gtk_list_box_select_row(self.service_list, @ptrCast(current));
                    break;
                }
            }
        }
    }

    fn makeServiceRow(self: *App, service: dinit.Service) !*c.GtkWidget {
        _ = self;
        const row = c.gtk_list_box_row_new() orelse return error.WidgetCreationFailed;
        const name_z = try allocator.dupeSentinel(u8, service.name, 0);
        defer allocator.free(name_z);
        c.gtk_widget_set_name(row, name_z);
        const summary_z = try allocator.dupeSentinel(u8, service.summary, 0);
        defer allocator.free(summary_z);
        c.gtk_widget_set_tooltip_text(row, summary_z);
        const box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10) orelse return error.WidgetCreationFailed;
        c.gtk_widget_set_margin_start(box, 10);
        c.gtk_widget_set_margin_end(box, 10);
        c.gtk_widget_set_margin_top(box, 8);
        c.gtk_widget_set_margin_bottom(box, 8);
        const name = c.gtk_label_new(name_z) orelse return error.WidgetCreationFailed;
        c.gtk_label_set_xalign(@ptrCast(name), 0.0);
        c.gtk_widget_set_hexpand(name, 1);
        const state_z = try allocator.dupeSentinel(u8, service.state.label(), 0);
        defer allocator.free(state_z);
        const state = c.gtk_label_new(state_z) orelse return error.WidgetCreationFailed;
        c.gtk_label_set_xalign(@ptrCast(state), 1.0);
        c.gtk_widget_add_css_class(state, stateClass(service.state));
        c.gtk_box_append(@ptrCast(box), name);
        c.gtk_box_append(@ptrCast(box), state);
        c.gtk_list_box_row_set_child(@ptrCast(row), box);
        return row;
    }

    fn selectService(self: *App, name: []const u8) void {
        if (self.selected_name) |old| allocator.free(old);
        self.selected_name = allocator.dupe(u8, name) catch null;
        const service = self.findService(name) orelse {
            self.setText(self.service_title, "Service not found");
            return;
        };
        self.setText(self.service_title, service.name);
        self.setTextFmt(self.service_state, "{s} · {s}", .{ service.state.label(), self.scope.label() });
        self.setText(self.service_summary, service.summary);
        self.loadStatus(service.name);
        self.loadLog(service.name);
    }

    fn loadStatus(self: *App, name: []const u8) void {
        self.setBusy("Loading service status…");
        var result = dinit.status(allocator, self.io, self.scope, name) catch |err| {
            self.setStatusError(@errorName(err));
            return;
        };
        defer result.deinit(allocator);
        const text = preferredOutput(result);
        self.setTextView(self.output_view, text);
        self.setStatus(if (result.success) "Status loaded" else "Status command failed");
        if (!result.success) self.setTextView(self.output_view, text);
    }

    fn performAction(self: *App) void {
        const index = c.gtk_drop_down_get_selected(self.action_dropdown);
        if (index >= action_order.len) return;
        const action = action_order[index];
        const name = self.selected_name;
        if (action.requiresService() and name == null) {
            self.setStatusError("Select a service first");
            return;
        }
        const signal = std.mem.span(c.gtk_editable_get_text(@ptrCast(self.signal_entry)));
        const extra = std.mem.span(c.gtk_editable_get_text(@ptrCast(self.arguments_entry)));
        self.setBusy("Running dinitctl action…");
        var result = dinit.runAction(allocator, self.io, self.scope, action, name, signal, extra) catch |err| {
            self.setStatusError(@errorName(err));
            return;
        };
        defer result.deinit(allocator);
        const output = preferredOutput(result);
        self.setTextView(self.output_view, output);
        if (result.success) {
            if (name) |service_name| {
                self.setStatusFmt("{s} completed · {s}", .{ action.label(), service_name });
            } else {
                self.setStatusFmt("{s} completed", .{action.label()});
            }
        } else {
            self.setStatusError(output);
        }
        if (action != .shutdown) self.refresh();
        if (name) |service_name| {
            self.loadLog(service_name);
        } else {
            self.setTextView(self.log_view, "Select a service to view its log buffer.");
        }
    }

    fn loadLog(self: *App, name: []const u8) void {
        var result = dinit.command(allocator, self.io, self.scope, &.{ "catlog", name }, true) catch |err| {
            self.setTextView(self.log_view, @errorName(err));
            return;
        };
        defer result.deinit(allocator);
        self.setTextView(self.log_view, preferredOutput(result));
    }

    fn findService(self: *App, name: []const u8) ?dinit.Service {
        for (self.services.items) |service| {
            if (std.mem.eql(u8, service.name, name)) return service;
        }
        return null;
    }

    fn setStatus(self: *App, text: []const u8) void {
        self.setText(self.status_label, text);
        c.gtk_spinner_stop(self.spinner);
    }

    fn setStatusError(self: *App, text: []const u8) void {
        self.setText(self.status_label, text);
        c.gtk_spinner_stop(self.spinner);
    }

    fn setBusy(self: *App, text: []const u8) void {
        self.setText(self.status_label, text);
        c.gtk_spinner_start(self.spinner);
    }

    fn setStatusFmt(self: *App, comptime format: []const u8, args: anytype) void {
        var buffer: [256]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, format, args) catch return;
        self.setStatus(text);
    }

    fn setText(self: *App, label: *c.GtkLabel, text: []const u8) void {
        _ = self;
        const text_z = allocator.dupeSentinel(u8, text, 0) catch return;
        defer allocator.free(text_z);
        c.gtk_label_set_text(label, text_z);
    }

    fn setTextFmt(self: *App, label: *c.GtkLabel, comptime format: []const u8, args: anytype) void {
        var buffer: [256]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, format, args) catch return;
        self.setText(label, text);
    }

    fn setTextView(self: *App, view: *c.GtkTextView, text: []const u8) void {
        _ = self;
        const text_z = allocator.dupeSentinel(u8, text, 0) catch return;
        defer allocator.free(text_z);
        const buffer = c.gtk_text_view_get_buffer(view) orelse return;
        c.gtk_text_buffer_set_text(buffer, text_z, @intCast(text.len));
    }
};

fn onActivate(_: *c.GApplication, data: ?*anyopaque) callconv(.c) void {
    const app = asApp(data);
    app.buildWindow();
    app.refresh();
}

fn onRefreshClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).refresh();
}

fn onScopeChanged(_: *c.GtkDropDown, _: *c.GParamSpec, data: ?*anyopaque) callconv(.c) void {
    const app = asApp(data);
    app.scope = if (c.gtk_drop_down_get_selected(app.scope_dropdown) == 0) .system else .user;
    app.selected_name = if (app.selected_name) |name| blk: {
        allocator.free(name);
        break :blk null;
    } else null;
    app.refresh();
}

fn onSearchChanged(_: *c.GtkSearchEntry, data: ?*anyopaque) callconv(.c) void {
    const app = asApp(data);
    app.renderServices(app.services.items) catch |err| app.setStatusError(@errorName(err));
}

fn onRowSelected(_: *c.GtkListBox, row: ?*c.GtkListBoxRow, data: ?*anyopaque) callconv(.c) void {
    const app = asApp(data);
    const selected = row orelse return;
    const name = std.mem.span(c.gtk_widget_get_name(@ptrCast(selected)));
    if (name.len > 0) app.selectService(name);
}

fn onActionClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).performAction();
}

fn onSmokeTimeout(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app = asApp(data);
    std.debug.print("dinitui_smoke surface=true services={d} selected={s}\n", .{
        app.services.items.len,
        if (app.selected_name) |name| name else "none",
    });
    c.g_application_quit(@ptrCast(app.application));
    return 0;
}

fn asApp(data: ?*anyopaque) *App {
    return @ptrCast(@alignCast(data.?));
}

fn connect(instance: anytype, signal: [*:0]const u8, callback: anytype, app: *App) void {
    _ = c.g_signal_connect_data(
        @ptrCast(instance),
        signal,
        @ptrCast(callback),
        @ptrCast(app),
        null,
        0,
    );
}

fn preferredOutput(result: dinit.CommandResult) []const u8 {
    if (result.output.len > 0) return result.output;
    if (result.error_output.len > 0) return result.error_output;
    return if (result.success) "Command completed without output" else "dinitctl failed without output";
}

fn stateClass(state: dinit.State) [*:0]const u8 {
    return switch (state) {
        .started => "state-started",
        .starting => "state-starting",
        .stopping => "state-stopping",
        .failed => "state-failed",
        .stopped, .unknown => "state-stopped",
    };
}

fn applyTheme() void {
    const provider = c.gtk_css_provider_new() orelse return;
    const css =
        ".dinit-output { font-family: monospace; background: #0b0d12; color: #d7dde8; }\n" ++
        ".state-started { color: #9ece6a; }\n" ++
        ".state-starting, .state-stopping { color: #e0af68; }\n" ++
        ".state-failed { color: #f7768e; font-weight: 700; }\n" ++
        ".state-stopped { color: #7f8a9c; }\n" ++
        "button.suggested-action { background-color: #8fb8ff; color: #0b0d12; }\n" ++
        "list row:selected { background-color: #263249; }\n" ++
        "entry, dropdown, textview, scrolledwindow { border-color: #222a38; }\n";
    c.gtk_css_provider_load_from_data(provider, css.ptr, @intCast(css.len));
    const display = c.gdk_display_get_default() orelse return;
    c.gtk_style_context_add_provider_for_display(
        display,
        @ptrCast(provider),
        c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
    c.g_object_unref(@ptrCast(provider));
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var smoke = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--smoke")) smoke = true;
    }

    const application = c.adw_application_new("org.dinx.DinitUI", c.G_APPLICATION_DEFAULT_FLAGS) orelse
        return error.ApplicationCreationFailed;
    const app = try allocator.create(App);
    app.* = App.init(application, init.io, init.environ_map.get("HOME") orelse "", smoke);
    defer {
        app.deinit();
        allocator.destroy(app);
        c.g_object_unref(@ptrCast(application));
    }
    connect(application, "activate", &onActivate, app);
    const status = c.g_application_run(@ptrCast(application), 0, null);
    if (status != 0) return error.ApplicationFailed;
}
