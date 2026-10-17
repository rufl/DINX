const std = @import("std");
const kernels = @import("kernels.zig");
const c = @import("c");

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
    smoke: bool = false,

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
        c.gtk_box_append(@ptrCast(hardware), makeButton("Display", "Open the optional wdisplays Wayland display panel", &onDisplayClicked, self));
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
        c.gtk_box_append(@ptrCast(services), makeButton("MangoWC options", "Edit the user MangoWC configuration in a terminal", &onMangoClicked, self));
        c.gtk_box_append(@ptrCast(services), makeButton("Firewall", "Open the UFW graphical policy editor", &onFirewallClicked, self));
        c.gtk_box_append(@ptrCast(content), services);

        appendSectionTitle(content, "Updates and firmware");
        const updates = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8) orelse return;
        c.gtk_box_append(@ptrCast(updates), makeButton("Check upgrades", "Refresh package and firmware metadata, then show available upgrades without installing them", &onUpgradeCheckClicked, self));
        c.gtk_box_append(@ptrCast(updates), makeButton("Topgrade preview", "Show Topgrade's package, firmware and tool upgrade plan without applying it", &onTopgradePreviewClicked, self));
        c.gtk_box_append(@ptrCast(updates), makeButton("Topgrade", "Run the complete Topgrade update workflow in a terminal", &onTopgradeClicked, self));
        c.gtk_box_append(@ptrCast(updates), makeButton("Shelly upgrade", "Run Shelly's all-backend upgrade workflow in a terminal", &onShellyClicked, self));
        c.gtk_box_append(@ptrCast(content), updates);

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

    fn refreshKernelStatus(self: *App) void {
        self.kernel_status_loaded = false;
        self.setBusy("Reading kernel status…");
        var report = kernels.detect(allocator, self.io) catch |err| {
            self.setStatusError(@errorName(err));
            return;
        };
        defer report.deinit(allocator);
        const text = kernels.formatReport(allocator, &report) catch |err| {
            self.setStatusError(@errorName(err));
            return;
        };
        defer allocator.free(text);
        self.setTextView(text);
        self.setTextFmt(self.kernel_status, "Running: {s} · installed alternatives: {d}", .{ report.running, report.installed.items.len });
        self.kernel_status_loaded = true;
        self.setStatus("Kernel status loaded");
    }

    fn installKernel(self: *App) void {
        const index = c.gtk_drop_down_get_selected(self.kernel_dropdown);
        if (index >= kernels.catalog.len) return;
        const kernel = kernels.catalog[index];
        self.setBusy("Installing kernel and headers…");
        var result = kernels.install(allocator, self.io, kernel.id) catch |err| {
            self.setStatusError(@errorName(err));
            return;
        };
        defer result.deinit(allocator);
        self.setTextView(if (result.output.len > 0) result.output else result.error_output);
        if (result.success) {
            self.setStatusFmt("{s} installed · reboot required", .{kernel.label});
            self.refreshKernelStatus();
        } else {
            self.setStatusError(if (result.error_output.len > 0) result.error_output else "Kernel installation failed");
        }
    }

    fn runDinitUi(self: *App, command: []const u8) void {
        self.runCommand(&.{ "dinitui", command });
    }

    fn runCommand(self: *App, argv: []const []const u8) void {
        self.setBusy("Running control-panel action…");
        const result = std.process.run(allocator, self.io, .{
            .argv = argv,
            .stdout_limit = std.Io.Limit.limited(512 * 1024),
            .stderr_limit = std.Io.Limit.limited(512 * 1024),
        }) catch |err| {
            self.setStatusError(@errorName(err));
            return;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        const output = if (result.stdout.len > 0) result.stdout else result.stderr;
        self.setTextView(if (output.len > 0) output else "Command completed without output");
        if (result.term.success()) self.setStatus("Action completed") else self.setStatusError(if (output.len > 0) output else "Action failed");
    }

    fn upgradeCommandSucceeded(result: *const std.process.RunResult, no_action_ok: bool) bool {
        if (result.term.success()) return true;
        if (!no_action_ok) return false;
        return switch (result.term) {
            .exited => |code| code == 2,
            else => false,
        };
    }

    fn runUpgradeCheck(self: *App) void {
        self.setBusy("Checking package and firmware upgrades…");
        var report: std.Io.Writer.Allocating = .init(allocator);
        defer report.deinit();
        const commands = [_]struct { argv: []const []const u8, label: []const u8, no_action_ok: bool }{
            .{ .argv = &.{ "shelly", "sync" }, .label = "shelly sync", .no_action_ok = false },
            .{ .argv = &.{ "shelly", "list-updates", "all" }, .label = "shelly list-updates all", .no_action_ok = false },
            .{ .argv = &.{ "fwupdmgr", "refresh" }, .label = "fwupdmgr refresh", .no_action_ok = false },
            .{ .argv = &.{ "fwupdmgr", "get-updates" }, .label = "fwupdmgr get-updates", .no_action_ok = true },
        };
        var all_succeeded = true;
        for (commands) |command| {
            report.writer.print("$ {s}\n", .{command.label}) catch {
                self.setStatusError("Unable to build upgrade report");
                return;
            };
            const result = std.process.run(allocator, self.io, .{
                .argv = command.argv,
                .stdout_limit = std.Io.Limit.limited(512 * 1024),
                .stderr_limit = std.Io.Limit.limited(512 * 1024),
            }) catch |err| {
                all_succeeded = false;
                report.writer.print("unavailable: {s}\n\n", .{@errorName(err)}) catch {
                    self.setStatusError("Unable to build upgrade report");
                    return;
                };
                continue;
            };
            const output = if (result.stdout.len > 0) result.stdout else result.stderr;
            if (output.len > 0) report.writer.writeAll(output) catch {
                allocator.free(result.stdout);
                allocator.free(result.stderr);
                self.setStatusError("Unable to build upgrade report");
                return;
            };
            report.writer.writeByte('\n') catch {
                allocator.free(result.stdout);
                allocator.free(result.stderr);
                self.setStatusError("Unable to build upgrade report");
                return;
            };
            if (!upgradeCommandSucceeded(&result, command.no_action_ok)) all_succeeded = false;
            allocator.free(result.stdout);
            allocator.free(result.stderr);
        }
        const text = report.toOwnedSlice() catch {
            self.setStatusError("Unable to build upgrade report");
            return;
        };
        defer allocator.free(text);
        self.setTextView(text);
        if (all_succeeded) {
            self.setStatus("Upgrade check complete");
        } else {
            self.setStatus("Upgrade check complete; review output");
        }
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

    fn launchMangoOptions(self: *App) void {
        const path = std.fs.path.join(allocator, &.{ self.home, ".config", "mango", "config.conf" }) catch {
            self.setStatusError("Unable to resolve MangoWC configuration");
            return;
        };
        defer allocator.free(path);
        self.launch(&.{ "foot", "--app-id=dinx-mango-options", "-e", "nano", path });
    }

    fn detectGpu(self: *App) void {
        self.runDinitUi("--gpu-status");
    }

    fn installGpu(self: *App) void {
        self.runDinitUi("--install-gpu-drivers");
    }

    fn setBusy(self: *App, text: []const u8) void {
        self.setText(self.status_label, text);
        c.gtk_widget_remove_css_class(@ptrCast(@alignCast(self.status_label)), "error");
        c.gtk_spinner_start(self.spinner);
    }

    fn setStatus(self: *App, text: []const u8) void {
        self.setText(self.status_label, text);
        c.gtk_widget_remove_css_class(@ptrCast(@alignCast(self.status_label)), "error");
        c.gtk_spinner_stop(self.spinner);
    }

    fn setStatusError(self: *App, text: []const u8) void {
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

fn onMangoClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launchMangoOptions();
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

fn onShellyClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "foot", "--app-id=dinx-shelly", "-e", "shelly", "upgrade", "all" });
}

fn onDisplayClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{"wdisplays"});
}

fn onHardwareClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).launch(&.{ "foot", "--app-id=dinx-hardware", "-e", "inxi", "-GSC" });
}

fn onKernelInstallClicked(_: *c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    asApp(data).installKernel();
}
fn onSmokeTimeout(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app = asApp(data);
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
