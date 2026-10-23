const std = @import("std");
const kernels = @import("kernels.zig");
const c = @import("c");
const optional_packages = @import("optional_packages.zig");

const allocator = std.heap.c_allocator;

const App = struct {
    application: *c.AdwApplication,
    io: std.Io,
    home: []const u8,
    kernel_dropdown: *c.GtkDropDown = undefined,
    kernel_status: *c.GtkLabel = undefined,
    output_view: *c.GtkTextView = undefined,
    status_label: *c.GtkLabel = undefined,
    spinner: *c.GtkSpinner = undefined,
    window_ready: bool = false,
    kernel_status_loaded: bool = false,
    kernel_status_completed: bool = false,
    smoke: bool = false,
    busy: bool = false,
    active_tasks: usize = 0,

    fn init(application: *c.AdwApplication, io: std.Io, home: []const u8, smoke: bool) App {
        return .{ .application = application, .io = io, .home = home, .smoke = smoke };
    }

    fn buildWindow(self: *App) void {
        if (self.window_ready) return;
        self.window_ready = true;

        const window_widget = c.adw_application_window_new(@ptrCast(self.application)) orelse return;
        const window: *c.AdwApplicationWindow = @ptrCast(window_widget);
        c.gtk_window_set_title(@ptrCast(window), "DINXPanel");
        c.gtk_window_set_default_size(@ptrCast(window), 1080, 760);
        c.gtk_window_set_resizable(@ptrCast(window), 1);

        const toolbar = c.adw_toolbar_view_new() orelse return;
        const header = c.adw_header_bar_new() orelse return;
        c.adw_header_bar_set_show_title(@ptrCast(header), 1);
        c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar), @ptrCast(header));
        const title = c.gtk_label_new("DINXPanel") orelse return;
        c.gtk_widget_add_css_class(title, "title-2");
        c.adw_header_bar_set_title_widget(@ptrCast(header), title);

        const refresh = c.gtk_button_new_with_label("Refresh") orelse return;
        c.gtk_widget_set_tooltip_text(refresh, "Refresh kernel status");
        connect(refresh, "clicked", &onRefreshClicked, self);
        c.adw_header_bar_pack_end(@ptrCast(header), refresh);

        const scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_scrolled_window_set_policy(@ptrCast(scroll), c.GTK_POLICY_NEVER, c.GTK_POLICY_AUTOMATIC);
        const content = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse return;
        c.gtk_widget_set_margin_start(content, 24);
        c.gtk_widget_set_margin_end(content, 24);
        c.gtk_widget_set_margin_top(content, 20);
        c.gtk_widget_set_margin_bottom(content, 24);

        const heading = c.gtk_label_new("System control center") orelse return;
        c.gtk_label_set_xalign(@ptrCast(heading), 0.0);
        c.gtk_widget_add_css_class(heading, "title-1");
        c.gtk_box_append(@ptrCast(content), heading);
        const intro = c.gtk_label_new("YaST-inspired access to DINX hardware, services, desktop, updates, firmware and recovery tools. Actions use fixed argv; package operations are explicit and non-destructive.") orelse return;
        c.gtk_label_set_xalign(@ptrCast(intro), 0.0);
        c.gtk_label_set_wrap(@ptrCast(intro), 1);
        c.gtk_widget_add_css_class(intro, "dim-label");
        c.gtk_widget_set_margin_bottom(intro, 18);
        c.gtk_box_append(@ptrCast(content), intro);

        appendSectionTitle(content, "Hardware");
        const hardware = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_box_append(@ptrCast(hardware), makeButton("GPU drivers", "Detect and install fixed AMD, Intel, or NVIDIA Artix driver plans", &onGpuDetectClicked, self));
        c.gtk_box_append(@ptrCast(hardware), makeButton("Install GPU plan", "Install the detected fixed GPU driver plan", &onGpuInstallClicked, self));
        c.gtk_box_append(@ptrCast(hardware), makeButton("Display", "Open DINX display setup; closing it saves the Shikane profile", &onDisplayClicked, self));
        c.gtk_box_append(@ptrCast(hardware), makeButton("Hardware info", "Open the read-only inxi hardware report", &onHardwareClicked, self));
        c.gtk_box_append(@ptrCast(content), hardware);

        appendSectionTitle(content, "Desktop and devices");
        const desktop = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_box_append(@ptrCast(desktop), makeButton("Network", "Open NetworkManager connection editor", &onNetworkClicked, self));
        c.gtk_box_append(@ptrCast(desktop), makeButton("Bluetooth", "Open Blueman device manager", &onBluetoothClicked, self));
        c.gtk_box_append(@ptrCast(desktop), makeButton("Audio", "Open PipeWire volume controls", &onAudioClicked, self));
        c.gtk_box_append(@ptrCast(desktop), makeButton("Brightness down", "Lower display brightness by 5 percent", &onBrightnessDownClicked, self));
        c.gtk_box_append(@ptrCast(desktop), makeButton("Brightness up", "Raise display brightness by 5 percent", &onBrightnessUpClicked, self));
        c.gtk_box_append(@ptrCast(desktop), makeButton("Lock screen", "Lock the DINX session immediately", &onLockClicked, self));
        c.gtk_box_append(@ptrCast(desktop), makeButton("Qt appearance", "Open Qt6 appearance settings", &onQtClicked, self));
        c.gtk_box_append(@ptrCast(content), desktop);

        appendSectionTitle(content, "DINX services and compositor");
        const services = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_box_append(@ptrCast(services), makeButton("Dinit services", "Open DinitUI service and profile manager", &onServicesClicked, self));
        c.gtk_box_append(@ptrCast(services), makeButton("Labwc options", "Edit the user labwc configuration in a terminal", &onLabwcClicked, self));
        c.gtk_box_append(@ptrCast(services), makeButton("Firewall", "Open the UFW graphical policy editor", &onFirewallClicked, self));
        c.gtk_box_append(@ptrCast(content), services);

        appendSectionTitle(content, "Updates and firmware");
        const updates = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_box_append(@ptrCast(updates), makeButton("Check upgrades", "Refresh package and firmware metadata, then show available upgrades without installing them", &onUpgradeCheckClicked, self));
        c.gtk_box_append(@ptrCast(updates), makeButton("Topgrade preview", "Show Topgrade's package, firmware and tool upgrade plan without applying it", &onTopgradePreviewClicked, self));
        c.gtk_box_append(@ptrCast(updates), makeButton("Topgrade", "Run the complete Topgrade update workflow in a terminal", &onTopgradeClicked, self));
        c.gtk_box_append(@ptrCast(updates), makeButton("Shelly upgrade", "Run Shelly's all-backend upgrade workflow in a terminal", &onShellyClicked, self));
        c.gtk_box_append(@ptrCast(content), updates);

        appendSectionTitle(content, "Optional packages");
        const optional = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_box_append(@ptrCast(optional), makeButton("Install CUPS", "Download and install optional CUPS printing support from the configured Artix repository", &onCupsInstallClicked, self));
        c.gtk_box_append(@ptrCast(content), optional);

        appendSectionTitle(content, "Kernel installer");
        const kernel_row = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        const kernel_label = c.gtk_label_new("Kernel") orelse return;
        c.gtk_label_set_xalign(@ptrCast(kernel_label), 0.0);
        c.gtk_widget_set_size_request(kernel_label, 120, -1);
        self.kernel_dropdown = @ptrCast(c.gtk_drop_down_new_from_strings(&kernel_strings) orelse return);
        c.gtk_widget_set_hexpand(@ptrCast(@alignCast(self.kernel_dropdown)), 1);
        c.gtk_widget_set_tooltip_text(@ptrCast(@alignCast(self.kernel_dropdown)), "Install an additional fixed Artix kernel plus headers; DINX never removes the running kernel");
        const kernel_install = makeButton("Install kernel", "Install the selected kernel and headers; reboot after installation", &onKernelInstallClicked, self);
        c.gtk_box_append(@ptrCast(kernel_row), kernel_label);
        c.gtk_box_append(@ptrCast(kernel_row), @ptrCast(@alignCast(self.kernel_dropdown)));
        c.gtk_box_append(@ptrCast(kernel_row), kernel_install);
        c.gtk_box_append(@ptrCast(content), kernel_row);
        self.kernel_status = @ptrCast(c.gtk_label_new("Kernel status unavailable") orelse return);
        c.gtk_label_set_xalign(self.kernel_status, 0.0);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.kernel_status)), "dim-label");
        c.gtk_widget_set_margin_top(@ptrCast(@alignCast(self.kernel_status)), 6);
        c.gtk_box_append(@ptrCast(content), @ptrCast(@alignCast(self.kernel_status)));

        appendSectionTitle(content, "Operation output");
        const output_scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_widget_set_size_request(output_scroll, -1, 240);
        self.output_view = @ptrCast(c.gtk_text_view_new() orelse return);
        c.gtk_text_view_set_editable(self.output_view, 0);
        c.gtk_text_view_set_cursor_visible(self.output_view, 0);
        c.gtk_text_view_set_monospace(self.output_view, 1);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.output_view)), "dinx-output");
        c.gtk_scrolled_window_set_child(@ptrCast(output_scroll), @ptrCast(@alignCast(self.output_view)));
        c.gtk_box_append(@ptrCast(content), output_scroll);

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

        c.gtk_scrolled_window_set_child(@ptrCast(scroll), content);
        c.adw_toolbar_view_set_content(@ptrCast(toolbar), scroll);
        c.adw_application_window_set_content(window, toolbar);
        applyTheme();
        c.gtk_window_present(@ptrCast(window));
        self.refreshKernelStatus();
        if (self.smoke) _ = c.g_timeout_add(900, @ptrCast(&onSmokeTimeout), self);
    }

    fn beginAsync(self: *App, text: []const u8) bool {
        if (self.busy) return false;
        self.setBusy(text);
        return true;
    }

    fn startAsync(self: *App, task: *AsyncTask) void {
        self.active_tasks += 1;
        c.g_application_hold(@ptrCast(self.application));
        const thread = std.Thread.spawn(.{}, asyncWorker, .{task}) catch |err| {
            self.active_tasks -= 1;
            c.g_application_release(@ptrCast(self.application));
            if (task.kind == .kernel_status) self.kernel_status_completed = true;
            task.deinit();
            self.setStatusError(@errorName(err));
            return;
        };
        thread.detach();
    }

    fn refreshKernelStatus(self: *App) void {
        if (!self.beginAsync("Reading kernel status…")) return;
        self.kernel_status_loaded = false;
        const task = allocator.create(AsyncTask) catch {
            self.setStatusError("Unable to allocate kernel status operation");
            return;
        };
        task.* = .{ .app = self, .kind = .kernel_status };
        self.startAsync(task);
    }

    fn installKernel(self: *App) void {
        if (!self.beginAsync("Installing kernel and headers…")) return;
        const index = c.gtk_drop_down_get_selected(self.kernel_dropdown);
        if (index >= kernels.catalog.len) {
            self.setStatusError("Select a supported kernel");
            return;
        }
        const task = allocator.create(AsyncTask) catch {
            self.setStatusError("Unable to allocate kernel installation operation");
            return;
        };
        task.* = .{
            .app = self,
            .kind = .kernel_install,
            .kernel = &kernels.catalog[index],
        };
        self.startAsync(task);
    }
    fn installCups(self: *App) void {
        if (!self.beginAsync("Downloading CUPS printing support…")) return;
        const task = allocator.create(AsyncTask) catch {
            self.setStatusError("Unable to allocate CUPS installation operation");
            return;
        };
        task.* = .{ .app = self, .kind = .optional_package_install };
        self.startAsync(task);
    }

    fn runDinitUi(self: *App, command: []const u8) void {
        self.runCommand(command);
    }

    fn runCommand(self: *App, command: []const u8) void {
        if (!self.beginAsync("Running control-panel action…")) return;
        const task = allocator.create(AsyncTask) catch {
            self.setStatusError("Unable to allocate control-panel operation");
            return;
        };
        task.* = .{ .app = self, .kind = .command, .dinitui_command = command };
        self.startAsync(task);
    }

    fn runUpgradeCheck(self: *App) void {
        if (!self.beginAsync("Checking package and firmware upgrades…")) return;
        const task = allocator.create(AsyncTask) catch {
            self.setStatusError("Unable to allocate upgrade operation");
            return;
        };
        task.* = .{ .app = self, .kind = .upgrade_check };
        self.startAsync(task);
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
            } else self.setStatusError("Unable to launch control panel");
            return;
        }
        self.setStatus("Control panel launched");
    }

    fn launchLabwcOptions(self: *App) void {
        const path = std.fs.path.join(allocator, &.{ self.home, ".config", "labwc", "rc.xml" }) catch {
            self.setStatusError("Unable to resolve labwc configuration");
            return;
        };
        defer allocator.free(path);
        self.launch(&.{ "foot", "--app-id=dinx-labwc-options", "-e", "nano", path });
    }

    fn detectGpu(self: *App) void {
        self.runDinitUi("--gpu-status");
    }

    fn installGpu(self: *App) void {
        self.runDinitUi("--install-gpu-drivers");
    }

    fn setBusy(self: *App, text: []const u8) void {
        self.busy = true;
        self.setText(self.status_label, text);
        c.gtk_widget_remove_css_class(@ptrCast(@alignCast(self.status_label)), "error");
        c.gtk_spinner_start(self.spinner);
    }

    fn setStatus(self: *App, text: []const u8) void {
        self.busy = false;
        self.setText(self.status_label, text);
        c.gtk_widget_remove_css_class(@ptrCast(@alignCast(self.status_label)), "error");
        c.gtk_spinner_stop(self.spinner);
    }

    fn setStatusError(self: *App, text: []const u8) void {
        self.busy = false;
        const visible = if (text.len > 180) "Action failed; see output for details" else text;
        self.setText(self.status_label, visible);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.status_label)), "error");
        c.gtk_spinner_stop(self.spinner);
    }

    fn setStatusFmt(self: *App, comptime format: []const u8, args: anytype) void {
        var buffer: [256]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, format, args) catch return;
        self.setStatus(text);
    }

    fn setText(self: *App, label: *c.GtkLabel, text: []const u8) void {
        _ = self;
        const value = allocator.dupeSentinel(u8, text, 0) catch return;
        defer allocator.free(value);
        c.gtk_label_set_text(label, value);
    }

    fn setTextFmt(self: *App, label: *c.GtkLabel, comptime format: []const u8, args: anytype) void {
        var buffer: [256]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, format, args) catch return;
        self.setText(label, text);
    }

    fn setTextView(self: *App, text: []const u8) void {
        const value = allocator.dupeSentinel(u8, text, 0) catch return;
        defer allocator.free(value);
        const buffer = c.gtk_text_view_get_buffer(self.output_view) orelse return;
        c.gtk_text_buffer_set_text(buffer, value, @intCast(text.len));
    }
};

const AsyncKind = enum {
    kernel_status,
    kernel_install,
    optional_package_install,
    command,
    upgrade_check,
};

const AsyncTask = struct {
    app: *App,
    kind: AsyncKind,
    kernel: ?*const kernels.Kernel = null,
    dinitui_command: []const u8 = "",
    process_result: ?std.process.RunResult = null,
    kernel_report: ?kernels.Report = null,
    kernel_result: ?kernels.CommandResult = null,
    optional_package_result: ?optional_packages.CommandResult = null,
    upgrade_output: ?[]u8 = null,
    upgrade_all_succeeded: bool = true,
    error_value: ?anyerror = null,

    fn deinit(self: *AsyncTask) void {
        if (self.process_result) |result| {
            allocator.free(result.stdout);
            allocator.free(result.stderr);
        }
        if (self.kernel_report) |*report| report.deinit(allocator);
        if (self.kernel_result) |*result| result.deinit(allocator);
        if (self.optional_package_result) |*result| result.deinit(allocator);
        if (self.upgrade_output) |output| allocator.free(output);
        allocator.destroy(self);
    }
};

fn asyncWorker(task: *AsyncTask) void {
    defer _ = c.g_idle_add(@ptrCast(&onAsyncTaskReady), task);
    switch (task.kind) {
        .kernel_status => task.kernel_report = kernels.detect(allocator, task.app.io) catch |err| {
            task.error_value = err;
            return;
        },
        .kernel_install => {
            const kernel = task.kernel orelse {
                task.error_value = error.UnsupportedKernel;
                return;
            };
            task.kernel_result = kernels.install(allocator, task.app.io, kernel.id) catch |err| {
                task.error_value = err;
                return;
            };
        },
        .optional_package_install => task.optional_package_result = optional_packages.install(allocator, task.app.io) catch |err| {
            task.error_value = err;
            return;
        },
        .command => {
            const argv = [_][]const u8{ "dinitui", task.dinitui_command };
            task.process_result = std.process.run(allocator, task.app.io, .{
                .argv = argv[0..],
                .stdout_limit = std.Io.Limit.limited(512 * 1024),
                .stderr_limit = std.Io.Limit.limited(512 * 1024),
            }) catch |err| {
                task.error_value = err;
                return;
            };
        },
        .upgrade_check => task.upgrade_output = collectUpgradeReport(task) catch |err| {
            task.error_value = err;
            return;
        },
    }
}

fn upgradeCommandSucceeded(result: *const std.process.RunResult, no_action_ok: bool) bool {
    if (result.term.success()) return true;
    if (!no_action_ok) return false;
    return switch (result.term) {
        .exited => |code| code == 2,
        else => false,
    };
}

fn collectUpgradeReport(task: *AsyncTask) ![]u8 {
    var report: std.Io.Writer.Allocating = .init(allocator);
    errdefer report.deinit();
    const commands = [_]struct { argv: []const []const u8, label: []const u8, no_action_ok: bool }{
        .{ .argv = &.{ "shelly", "sync" }, .label = "shelly sync", .no_action_ok = false },
        .{ .argv = &.{ "shelly", "list-updates", "all" }, .label = "shelly list-updates all", .no_action_ok = false },
        .{ .argv = &.{ "fwupdmgr", "refresh" }, .label = "fwupdmgr refresh", .no_action_ok = false },
        .{ .argv = &.{ "fwupdmgr", "get-updates" }, .label = "fwupdmgr get-updates", .no_action_ok = true },
    };
    for (commands) |command| {
        try report.writer.print("$ {s}\n", .{command.label});
        const result = std.process.run(allocator, task.app.io, .{
            .argv = command.argv,
            .stdout_limit = std.Io.Limit.limited(512 * 1024),
            .stderr_limit = std.Io.Limit.limited(512 * 1024),
        }) catch |err| {
            task.upgrade_all_succeeded = false;
            try report.writer.print("unavailable: {s}\n\n", .{@errorName(err)});
            continue;
        };
        const output = if (result.stdout.len > 0) result.stdout else result.stderr;
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        if (output.len > 0) try report.writer.writeAll(output);
        try report.writer.writeByte('\n');
        if (!upgradeCommandSucceeded(&result, command.no_action_ok)) task.upgrade_all_succeeded = false;
    }
    return report.toOwnedSlice();
}

fn completeAsyncTask(task: *AsyncTask) void {
    const app = task.app;
    if (task.error_value) |err| {
        if (task.kind == .kernel_status) app.kernel_status_completed = true;
        app.setStatusError(@errorName(err));
        return;
    }
    switch (task.kind) {
        .kernel_status => {
            var report = task.kernel_report orelse {
                app.kernel_status_completed = true;
                app.setStatusError("Kernel status operation returned no report");
                return;
            };
            task.kernel_report = null;
            defer report.deinit(allocator);
            const text = kernels.formatReport(allocator, &report) catch |err| {
                app.kernel_status_completed = true;
                app.setStatusError(@errorName(err));
                return;
            };
            defer allocator.free(text);
            app.setTextView(text);
            app.setTextFmt(app.kernel_status, "Running: {s} · installed alternatives: {d}", .{ report.running, report.installed.items.len });
            app.kernel_status_loaded = true;
            app.kernel_status_completed = true;
            app.setStatus("Kernel status loaded");
        },
        .kernel_install => {
            var result = task.kernel_result orelse {
                app.setStatusError("Kernel installation returned no result");
                return;
            };
            task.kernel_result = null;
            defer result.deinit(allocator);
            const output = if (result.output.len > 0) result.output else result.error_output;
            app.setTextView(if (output.len > 0) output else "Kernel installation completed without output");
            const kernel = task.kernel orelse {
                app.setStatusError("Kernel installation returned no kernel");
                return;
            };
            if (result.success) {
                app.setStatusFmt("{s} installed · reboot required", .{kernel.label});
                app.refreshKernelStatus();
            } else {
                app.setStatusError(if (result.error_output.len > 0) result.error_output else "Kernel installation failed");
            }
        },
        .optional_package_install => {
            var result = task.optional_package_result orelse {
                app.setStatusError("CUPS installation returned no result");
                return;
            };
            task.optional_package_result = null;
            defer result.deinit(allocator);
            const output = if (result.output.len > 0) result.output else result.error_output;
            app.setTextView(if (output.len > 0) output else "CUPS installation completed without output");
            if (result.success) {
                app.setStatus("CUPS installed; enable cupsd in DinitUI");
            } else {
                app.setStatusError(if (result.error_output.len > 0) result.error_output else "CUPS installation failed");
            }
        },
        .command => {
            var result = task.process_result orelse {
                app.setStatusError("Control-panel action returned no result");
                return;
            };
            task.process_result = null;
            defer {
                allocator.free(result.stdout);
                allocator.free(result.stderr);
            }
            const output = if (result.stdout.len > 0) result.stdout else result.stderr;
            app.setTextView(if (output.len > 0) output else "Command completed without output");
            if (result.term.success()) app.setStatus("Action completed") else app.setStatusError(if (output.len > 0) output else "Action failed");
        },
        .upgrade_check => {
            const text = task.upgrade_output orelse {
                app.setStatusError("Upgrade check returned no report");
                return;
            };
            task.upgrade_output = null;
            defer allocator.free(text);
            app.setTextView(text);
            if (task.upgrade_all_succeeded) {
                app.setStatus("Upgrade check complete");
            } else {
                app.setStatus("Upgrade check complete; review output");
            }
        },
    }
}

fn onAsyncTaskReady(data: ?*anyopaque) callconv(.c) c.gboolean {
    const task: *AsyncTask = @ptrCast(@alignCast(data.?));
    const app = task.app;
    completeAsyncTask(task);
    if (app.active_tasks > 0) app.active_tasks -= 1;
    c.g_application_release(@ptrCast(app.application));
    task.deinit();
    return 0;
}

const kernel_strings = [_:null]?[*:0]const u8{
    "Linux (default)",
    "Linux LTS",
    "Linux Zen",
    "Linux Hardened",
    null,
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

fn onRefreshClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).refreshKernelStatus();
}

fn onGpuDetectClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).detectGpu();
}

fn onGpuInstallClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).installGpu();
}

fn onNetworkClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"nm-connection-editor"});
}

fn onBluetoothClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"blueman-manager"});
}

fn onAudioClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"pwvucontrol"});
}
fn onBrightnessDownClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "brightnessctl", "set", "5%-" });
}

fn onBrightnessUpClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "brightnessctl", "set", "5%+" });
}

fn onLockClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "swaylock", "-f" });
}

fn onQtClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"qt6ct"});
}

fn onServicesClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"dinitui"});
}

fn onLabwcClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launchLabwcOptions();
}

fn onFirewallClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"gufw"});
}
fn onUpgradeCheckClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).runUpgradeCheck();
}

fn onTopgradePreviewClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "foot", "--app-id=dinx-topgrade-preview", "-e", "topgrade", "--dry-run", "--show-skipped", "--no-self-update", "--no-tmux" });
}

fn onTopgradeClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "foot", "--app-id=dinx-topgrade", "-e", "topgrade" });
}
fn onCupsInstallClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).installCups();
}

fn onShellyClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "foot", "--app-id=dinx-shelly", "-e", "shelly", "upgrade", "all" });
}

fn onDisplayClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"dinx-wdisplays"});
}

fn onHardwareClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "foot", "--app-id=dinx-hardware", "-e", "inxi", "-GSC" });
}

fn onKernelInstallClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).installKernel();
}
fn onSmokeTimeout(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app = asApp(data);
    if (app.active_tasks != 0 or !app.kernel_status_completed) return 1;
    std.debug.print("dinxpanel_smoke surface=true kernel_status={s}\n", .{if (app.kernel_status_loaded) "true" else "false"});
    c.g_application_quit(@ptrCast(app.application));
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
        ".dinx-output { font-family: monospace; background: #0b0d12; color: #d7dde8; }\n" ++
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
    const application = c.adw_application_new("org.dinx.DinxPanel", c.G_APPLICATION_DEFAULT_FLAGS) orelse return error.ApplicationCreationFailed;
    const app = try allocator.create(App);
    app.* = App.init(application, init.io, init.environ_map.get("HOME") orelse "", smoke);
    defer {
        allocator.destroy(app);
        c.g_object_unref(@ptrCast(application));
    }
    connect(application, "activate", &onActivate, app);
    const status = c.g_application_run(@ptrCast(application), 0, null);
    if (status != 0) return error.ApplicationFailed;
}
