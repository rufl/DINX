const std = @import("std");
const kernels = @import("kernels.zig");
const c = @import("c");
const optional_packages = @import("optional_packages.zig");

const allocator = std.heap.c_allocator;

const App = struct {
    application: *c.AdwApplication,
    io: std.Io,
    home: []const u8,
    live_session: bool,
    kernel_dropdown: *c.GtkDropDown = undefined,
    kernel_status: *c.GtkLabel = undefined,
    output_view: *c.GtkTextView = undefined,
    status_label: *c.GtkLabel = undefined,
    spinner: *c.GtkSpinner = undefined,
    navigation: *c.GtkListBox = undefined,
    stack: *c.GtkStack = undefined,
    window_ready: bool = false,
    kernel_status_loaded: bool = false,
    kernel_status_completed: bool = false,
    smoke: bool = false,
    busy: bool = false,
    active_tasks: usize = 0,

    fn init(application: *c.AdwApplication, io: std.Io, home: []const u8, smoke: bool, live_session: bool) App {
        return .{ .application = application, .io = io, .home = home, .smoke = smoke, .live_session = live_session };
    }


    fn buildWindow(self: *App) void {
        if (self.window_ready) return;
        self.window_ready = true;

        const window_widget = c.adw_application_window_new(@ptrCast(self.application)) orelse return;
        const window: *c.AdwApplicationWindow = @ptrCast(window_widget);
        c.gtk_window_set_title(@ptrCast(window), "DINX Control Panel");
        c.gtk_window_set_default_size(@ptrCast(window), 1180, 780);
        c.gtk_window_set_resizable(@ptrCast(window), 1);

        const toolbar = c.adw_toolbar_view_new() orelse return;
        const header = c.adw_header_bar_new() orelse return;
        c.adw_header_bar_set_show_title(@ptrCast(header), 1);
        c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar), @ptrCast(header));
        const title = c.gtk_label_new("Control Panel") orelse return;
        c.gtk_widget_add_css_class(title, "title-2");
        c.adw_header_bar_set_title_widget(@ptrCast(header), title);
        const refresh = c.gtk_button_new_with_label("Refresh") orelse return;
        c.gtk_widget_set_tooltip_text(refresh, "Refresh kernel and device status");
        connect(refresh, "clicked", &onRefreshClicked, self);
        c.adw_header_bar_pack_end(@ptrCast(header), refresh);

        const shell = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0) orelse return;
        c.gtk_widget_add_css_class(shell, "dinx-shell");

        const sidebar = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse return;
        c.gtk_widget_set_size_request(sidebar, 236, -1);
        c.gtk_widget_add_css_class(sidebar, "dinx-sidebar");
        const brand = c.gtk_label_new("DINX") orelse return;
        c.gtk_label_set_xalign(@ptrCast(brand), 0.0);
        c.gtk_widget_add_css_class(brand, "dinx-brand");
        c.gtk_widget_set_margin_start(brand, 20);
        c.gtk_widget_set_margin_top(brand, 20);
        c.gtk_widget_set_margin_bottom(brand, 4);
        c.gtk_box_append(@ptrCast(sidebar), brand);
        const sidebar_hint = c.gtk_label_new("System settings") orelse return;
        c.gtk_label_set_xalign(@ptrCast(sidebar_hint), 0.0);
        c.gtk_widget_add_css_class(sidebar_hint, "dim-label");
        c.gtk_widget_set_margin_start(sidebar_hint, 20);
        c.gtk_widget_set_margin_bottom(sidebar_hint, 16);
        c.gtk_box_append(@ptrCast(sidebar), sidebar_hint);

        const navigation = c.gtk_list_box_new() orelse return;
        self.navigation = @ptrCast(navigation);
        c.gtk_list_box_set_selection_mode(@ptrCast(navigation), c.GTK_SELECTION_SINGLE);
        c.gtk_widget_add_css_class(navigation, "dinx-navigation");
        connect(navigation, "row-selected", &onNavigationRowSelected, self);
        const nav_items = [_]struct { name: [*:0]const u8, label: [*:0]const u8 }{
            .{ .name = "overview", .label = "Overview" },
            .{ .name = "redbean", .label = "Redbean shell" },
            .{ .name = "appearance", .label = "Appearance" },
            .{ .name = "compositor", .label = "Compositor & windows" },
            .{ .name = "displays", .label = "Displays" },
            .{ .name = "devices", .label = "Devices" },
            .{ .name = "network", .label = "Network" },
            .{ .name = "audio", .label = "Audio" },
            .{ .name = "hardware", .label = "Hardware" },
            .{ .name = "services", .label = "Services & updates" },
        };
        for (nav_items) |item| appendNavigationRow(navigation, item.name, item.label);
        c.gtk_box_append(@ptrCast(sidebar), navigation);
        c.gtk_box_append(@ptrCast(shell), sidebar);

        const right = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse return;
        c.gtk_widget_set_hexpand(right, 1);
        const page_scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_scrolled_window_set_policy(@ptrCast(page_scroll), c.GTK_POLICY_NEVER, c.GTK_POLICY_AUTOMATIC);
        c.gtk_widget_set_vexpand(page_scroll, 1);
        const stack = c.gtk_stack_new() orelse return;
        self.stack = @ptrCast(stack);
        c.gtk_widget_set_hexpand(stack, 1);
        c.gtk_widget_set_vexpand(stack, 1);

        const overview = makePage("Overview", "Quiet, fixed-argv controls for the DINX session.");
        appendAction(overview, "Open Redbean", "Open the Redbean shell surface", &onRedbeanClicked, self);
        appendAction(overview, "Display setup", "Open display layout and persist the DINX Shikane profile", &onDisplayClicked, self);
        appendAction(overview, "Network connections", "Manage NetworkManager connections", &onNetworkClicked, self);
        appendAction(overview, "Audio controls", "Open PipeWire volume controls", &onAudioClicked, self);
        _ = c.gtk_stack_add_titled(@ptrCast(stack), overview, "overview", "Overview");

        const redbean = makePage("Redbean shell", "Launcher, workspace, notification and application actions live in the Redbean surface.");
        appendAction(redbean, "Open Redbean", "Open the Redbean shell surface", &onRedbeanClicked, self);
        appendAction(redbean, "Edit Redbean settings", "Open the persisted Redbean mode and pin configuration", &onRedbeanSettingsClicked, self);
        appendAction(redbean, "Open display layout", "Configure display placement used by the shell", &onDisplayClicked, self);
        _ = c.gtk_stack_add_titled(@ptrCast(stack), redbean, "redbean", "Redbean shell");

        const appearance = makePage("Appearance", "DINX stays dark while preserving the active theme family's semantic accent and surfaces.");
        appendAction(appearance, "Qt appearance", "Open Qt6ct with the DINX palette", &onQtClicked, self);
        appendAction(appearance, "Open Morghulis", "Open the active desktop shell", &onMorghulisClicked, self);
        appendAction(appearance, "Refresh session theme", "Reapply the saved DINX appearance to GTK and Qt", &onThemeRefreshClicked, self);
        _ = c.gtk_stack_add_titled(@ptrCast(stack), appearance, "appearance", "Appearance");

        const compositor = makePage("Compositor & windows", "River owns the compositor; KWM owns tiling and KWIM owns input. Changes stay in the user's config.");
        appendAction(compositor, "Edit KWM config", "Open the persistent KWM configuration", &onKwmConfigClicked, self);
        appendAction(compositor, "DinitUI profiles", "Manage session service and performance profiles", &onServicesClicked, self);
        if (!self.live_session) {
            appendAction(compositor, "Lock screen", "Lock the installed DINX session", &onLockClicked, self);
        }
        _ = c.gtk_stack_add_titled(@ptrCast(stack), compositor, "compositor", "Compositor & windows");

        const displays = makePage("Displays", "Edit layouts with wdisplays and save them back into Shikane atomically.");
        appendAction(displays, "Open display setup", "Configure and save the DINX display profile", &onDisplayClicked, self);
        appendAction(displays, "Hardware report", "Inspect graphics devices and active drivers", &onHardwareClicked, self);
        _ = c.gtk_stack_add_titled(@ptrCast(stack), displays, "displays", "Displays");

        const devices = makePage("Devices", "Common hardware controls without a resident daemon.");
        appendAction(devices, "Bluetooth", "Open the adapter-aware Blueman launcher", &onBluetoothClicked, self);
        appendAction(devices, "Brightness down", "Lower display brightness by five percent", &onBrightnessDownClicked, self);
        appendAction(devices, "Brightness up", "Raise display brightness by five percent", &onBrightnessUpClicked, self);
        appendAction(devices, "Hardware report", "Open the read-only inxi hardware report", &onHardwareClicked, self);
        _ = c.gtk_stack_add_titled(@ptrCast(stack), devices, "devices", "Devices");

        const network = makePage("Network", "NetworkManager and the DINX firewall remain separate, visible controls.");
        appendAction(network, "Network connections", "Open NetworkManager connection editor", &onNetworkClicked, self);
        appendAction(network, "Firewall", "Manage network access with Firewalld", &onFirewallClicked, self);
        _ = c.gtk_stack_add_titled(@ptrCast(stack), network, "network", "Network");

        const audio = makePage("Audio", "PipeWire volume and mute controls through the native DINX-friendly mixer.");
        appendAction(audio, "Audio controls", "Open pwvucontrol", &onAudioClicked, self);
        appendAction(audio, "Brightness down", "Lower display brightness by five percent", &onBrightnessDownClicked, self);
        appendAction(audio, "Brightness up", "Raise display brightness by five percent", &onBrightnessUpClicked, self);
        _ = c.gtk_stack_add_titled(@ptrCast(stack), audio, "audio", "Audio");

        const hardware = makePage("Hardware", "Driver plans are delegated to DinitUI; kernel installation never removes the running kernel.");
        appendAction(hardware, "Detect GPU drivers", "Read the fixed AMD, Intel or NVIDIA driver plan", &onGpuDetectClicked, self);
        appendAction(hardware, "Install GPU plan", "Install the detected fixed GPU driver plan", &onGpuInstallClicked, self);
        const kernel_row = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        const kernel_label = c.gtk_label_new("Kernel") orelse return;
        c.gtk_label_set_xalign(@ptrCast(kernel_label), 0.0);
        c.gtk_widget_set_size_request(kernel_label, 110, -1);
        self.kernel_dropdown = @ptrCast(c.gtk_drop_down_new_from_strings(&kernel_strings) orelse return);
        c.gtk_widget_set_hexpand(@ptrCast(@alignCast(self.kernel_dropdown)), 1);
        c.gtk_widget_set_tooltip_text(@ptrCast(@alignCast(self.kernel_dropdown)), "Install a supported kernel and headers; DINX never removes the running kernel");
        c.gtk_box_append(@ptrCast(kernel_row), kernel_label);
        c.gtk_box_append(@ptrCast(kernel_row), @ptrCast(@alignCast(self.kernel_dropdown)));
        c.gtk_box_append(@ptrCast(kernel_row), makeButton("Install kernel", "Install the selected kernel and headers; reboot after installation", &onKernelInstallClicked, self));
        c.gtk_box_append(@ptrCast(hardware), kernel_row);
        self.kernel_status = @ptrCast(c.gtk_label_new("Kernel status unavailable") orelse return);
        c.gtk_label_set_xalign(self.kernel_status, 0.0);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.kernel_status)), "dim-label");
        c.gtk_box_append(@ptrCast(hardware), @ptrCast(@alignCast(self.kernel_status)));
        _ = c.gtk_stack_add_titled(@ptrCast(stack), hardware, "hardware", "Hardware");

        const services = makePage("Services & updates", "Review first, then choose the explicit action. Missing optional tools stay visible in the output.");
        appendAction(services, "Dinit services", "Open DinitUI service and profile manager", &onServicesClicked, self);
        appendAction(services, "Check upgrades", "Refresh package and firmware metadata without installing", &onUpgradeCheckClicked, self);
        appendAction(services, "Topgrade preview", "Review the complete update plan", &onTopgradePreviewClicked, self);
        appendAction(services, "Topgrade", "Run the complete update workflow", &onTopgradeClicked, self);
        appendAction(services, "Shelly upgrade", "Run Shelly's all-backend upgrade workflow", &onShellyClicked, self);
        appendAction(services, "Install CUPS", "Install optional printing support", &onCupsInstallClicked, self);
        _ = c.gtk_stack_add_titled(@ptrCast(stack), services, "services", "Services & updates");

        c.gtk_stack_set_visible_child_name(@ptrCast(stack), "overview");
        c.gtk_scrolled_window_set_child(@ptrCast(page_scroll), stack);
        c.gtk_box_append(@ptrCast(right), page_scroll);

        const output_scroll = c.gtk_scrolled_window_new() orelse return;
        c.gtk_widget_set_size_request(output_scroll, -1, 150);
        self.output_view = @ptrCast(c.gtk_text_view_new() orelse return);
        c.gtk_text_view_set_editable(self.output_view, 0);
        c.gtk_text_view_set_cursor_visible(self.output_view, 0);
        c.gtk_text_view_set_monospace(self.output_view, 1);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.output_view)), "dinx-output");
        c.gtk_scrolled_window_set_child(@ptrCast(output_scroll), @ptrCast(@alignCast(self.output_view)));
        c.gtk_box_append(@ptrCast(right), output_scroll);

        const footer = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_widget_set_margin_start(footer, 18);
        c.gtk_widget_set_margin_end(footer, 18);
        c.gtk_widget_set_margin_top(footer, 8);
        c.gtk_widget_set_margin_bottom(footer, 10);
        self.spinner = @ptrCast(c.gtk_spinner_new() orelse return);
        c.gtk_widget_set_size_request(@ptrCast(@alignCast(self.spinner)), 24, 24);
        self.status_label = @ptrCast(c.gtk_label_new("Ready") orelse return);
        c.gtk_label_set_xalign(self.status_label, 0.0);
        c.gtk_widget_set_hexpand(@ptrCast(@alignCast(self.status_label)), 1);
        c.gtk_widget_add_css_class(@ptrCast(@alignCast(self.status_label)), "dim-label");
        c.gtk_box_append(@ptrCast(footer), @ptrCast(@alignCast(self.spinner)));
        c.gtk_box_append(@ptrCast(footer), @ptrCast(@alignCast(self.status_label)));
        c.gtk_box_append(@ptrCast(right), footer);

        c.gtk_box_append(@ptrCast(shell), right);
        c.adw_toolbar_view_set_content(@ptrCast(toolbar), shell);
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

fn makePage(title_text: [*:0]const u8, subtitle_text: [*:0]const u8) *c.GtkWidget {
    const page = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 12) orelse return c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0).?;
    c.gtk_widget_add_css_class(page, "dinx-page");
    c.gtk_widget_set_margin_start(page, 28);
    c.gtk_widget_set_margin_end(page, 28);
    c.gtk_widget_set_margin_top(page, 28);
    c.gtk_widget_set_margin_bottom(page, 32);

    const title = c.gtk_label_new(title_text) orelse return page;
    c.gtk_label_set_xalign(@ptrCast(title), 0.0);
    c.gtk_widget_add_css_class(title, "dinx-page-title");
    c.gtk_box_append(@ptrCast(page), title);

    const subtitle = c.gtk_label_new(subtitle_text) orelse return page;
    c.gtk_label_set_xalign(@ptrCast(subtitle), 0.0);
    c.gtk_label_set_wrap(@ptrCast(subtitle), 1);
    c.gtk_widget_add_css_class(subtitle, "dinx-page-subtitle");
    c.gtk_box_append(@ptrCast(page), subtitle);
    return page;
}

fn appendAction(parent: *c.GtkWidget, label: [*:0]const u8, tooltip: [*:0]const u8, callback: anytype, app: *App) void {
    const row = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0) orelse return;
    const button = makeButton(label, tooltip, callback, app);
    c.gtk_widget_add_css_class(button, "dinx-action");
    c.gtk_widget_set_hexpand(button, 1);
    c.gtk_box_append(@ptrCast(row), button);
    c.gtk_box_append(@ptrCast(parent), row);
}

fn appendNavigationRow(parent: *c.GtkWidget, name: [*:0]const u8, label: [*:0]const u8) void {
    const row = c.gtk_list_box_row_new() orelse return;
    c.gtk_widget_set_name(row, name);
    c.gtk_widget_add_css_class(row, "dinx-nav-row");
    const text = c.gtk_label_new(label) orelse return;
    c.gtk_label_set_xalign(@ptrCast(text), 0.0);
    c.gtk_widget_set_margin_start(text, 12);
    c.gtk_widget_set_margin_end(text, 12);
    c.gtk_widget_set_margin_top(text, 8);
    c.gtk_widget_set_margin_bottom(text, 8);
    c.gtk_list_box_row_set_child(@ptrCast(row), text);
    c.gtk_list_box_append(@ptrCast(parent), row);
}


fn makeButton(label: [*:0]const u8, tooltip: [*:0]const u8, callback: anytype, app: *App) *c.GtkWidget {
    const button = c.gtk_button_new_with_label(label) orelse return c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0).?;
    c.gtk_widget_set_tooltip_text(button, tooltip);
    connect(button, "clicked", callback, app);
    return button;
}

fn onNavigationRowSelected(_: *c.GtkListBox, row: ?*c.GtkListBoxRow, data: ?*anyopaque) callconv(.c) void {
    const app = asApp(data);
    const selected = row orelse return;
    c.gtk_stack_set_visible_child_name(app.stack, c.gtk_widget_get_name(@ptrCast(selected)));
}


fn onActivate(_: *c.GApplication, data: ?*anyopaque) callconv(.c) void {
    asApp(data).buildWindow();
}
fn onRedbeanClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"redbean"});
}

fn onRedbeanSettingsClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "deetty", "-e", "dintor", ".config/dinx/redbean.json" });
}

fn onMorghulisClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"morghulis"});
}

fn onThemeRefreshClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"/usr/local/libexec/dinx-sync-session-theme"});
}

fn onKwmConfigClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "deetty", "-e", "dintor", ".config/kwm/config.zon" });
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
    asApp(data).launch(&.{"/usr/local/libexec/dinx-bluetooth-manager"});
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


fn onFirewallClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"firewall-config"});
}
fn onUpgradeCheckClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).runUpgradeCheck();
}

fn onTopgradePreviewClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "deetty", "-e", "topgrade", "--dry-run", "--show-skipped", "--no-self-update", "--no-tmux" });
}

fn onTopgradeClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "deetty", "-e", "topgrade" });
}
fn onCupsInstallClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).installCups();
}

fn onShellyClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "deetty", "-e", "shelly", "upgrade", "all" });
}

fn onDisplayClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"dinx-wdisplays"});
}

fn onHardwareClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "deetty", "-e", "inxi", "-GSC" });
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
    const manager = c.adw_style_manager_get_default();
    c.adw_style_manager_set_color_scheme(manager, c.ADW_COLOR_SCHEME_FORCE_DARK);
    const provider = c.gtk_css_provider_new() orelse return;
    const css =
        ".dinx-shell { background-color: @window_bg_color; color: @window_fg_color; }\n" ++
        ".dinx-sidebar { background-color: @view_bg_color; border-right: 1px solid @borders; }\n" ++
        ".dinx-brand { color: @accent_color; font-size: 1.45rem; font-weight: 800; }\n" ++
        ".dinx-navigation { background-color: transparent; padding: 0 8px; }\n" ++
        ".dinx-nav-row { min-height: 42px; border-radius: 10px; margin: 2px 0; }\n" ++
        ".dinx-nav-row:selected { background-color: @accent_bg_color; color: @accent_fg_color; }\n" ++
        ".dinx-nav-row:hover { background-color: @accent_bg_color; }\n" ++
        ".dinx-page { background-color: @window_bg_color; }\n" ++
        ".dinx-page-title { font-size: 1.6rem; font-weight: 700; }\n" ++
        ".dinx-page-subtitle { color: @dim_color; margin-bottom: 12px; }\n" ++
        "button.dinx-action { min-height: 40px; }\n" ++
        ".dinx-output { font-family: monospace; background-color: @card_bg_color; color: @view_fg_color; padding: 12px; }\n";
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
    const live_session = std.mem.eql(u8, init.environ_map.get("DINX_LIVE_SESSION") orelse "", "1");
    app.* = App.init(application, init.io, init.environ_map.get("HOME") orelse "", smoke, live_session);
    defer {
        allocator.destroy(app);
        c.g_object_unref(@ptrCast(application));
    }
    connect(application, "activate", &onActivate, app);
    const status = c.g_application_run(@ptrCast(application), 0, null);
    if (status != 0) return error.ApplicationFailed;
}
