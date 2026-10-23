const std = @import("std");
const Pori = @import("Pori");
const gio = Pori.gio;
const glib = Pori.glib;
const dbus = @import("../helpers/dbus.zig");

const debounce_ms: c_uint = 400;

var on_change: ?*const fn () void = null;
var pending = false;

pub fn start(cb: *const fn () void) void {
    if (on_change != null) return;
    on_change = cb;

    const conn = dbus.systemBus() catch return;
    _ = gio.DBusConnection.signalSubscribe(conn, "org.freedesktop.UDisks2", null, null, null, null, .{}, &onSignal, null, null);
}

fn onSignal(
    conn: *gio.DBusConnection,
    sender: ?[*:0]const u8,
    object_path: [*:0]const u8,
    interface_name: [*:0]const u8,
    signal_name: [*:0]const u8,
    parameters: *glib.Variant,
    ud: ?*anyopaque,
) callconv(.c) void {
    _ = conn;
    _ = sender;
    _ = object_path;
    _ = parameters;
    _ = ud;

    const iface = std.mem.sliceTo(interface_name, 0);
    const member = std.mem.sliceTo(signal_name, 0);
    if (!relevant(iface, member)) return;

    schedule();
}

fn relevant(iface: []const u8, member: []const u8) bool {
    _ = member;
    return std.mem.eql(u8, iface, "org.freedesktop.DBus.ObjectManager") or
        std.mem.startsWith(u8, iface, "org.freedesktop.UDisks2");
}

test "relevant keeps drive signals and drops unrelated bus noise" {
    try std.testing.expect(relevant("org.freedesktop.DBus.ObjectManager", "InterfacesAdded"));
    try std.testing.expect(relevant("org.freedesktop.UDisks2.Block", "PropertiesChanged"));
    try std.testing.expect(!relevant("org.freedesktop.DBus.Properties", "PropertiesChanged"));
}

fn schedule() void {
    if (pending) return;
    pending = true;
    _ = glib.timeoutAdd(debounce_ms, &fire, null);
}

fn fire(_: ?*anyopaque) callconv(.c) c_int {
    pending = false;
    if (on_change) |cb| cb();
    return 0;
}
