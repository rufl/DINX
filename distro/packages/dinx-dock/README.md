# DINX Dock

DINX Dock is the same first-party Wayland dock across MAIN and NEXT. It runs
as an independent GTK4 layer-shell surface in River sessions managed by KWM
and KWIM, with either Morghulis or Redbean as the selected DINX shell.

## Placement

The dock reads `$XDG_CONFIG_HOME/dinx/appearance.json`, the file the DINX
first-run wizard writes at first login:

```json
{"version": 1, "dock": "left"}
```

`dock` accepts `left`, `right`, `bottom` or `none`. `none` keeps the dock
unmapped and the process exits with status 0, which is what the session
supervisor expects from an optional component that is deliberately off.
`dinx-dockctl set-edge left|right|bottom` starts it again if it was disabled.

The dock is a core shell component, so a missing, unreadable or malformed
appearance file falls back to `left` rather than removing the launchers. Only
an explicit `"none"` disables it.

`dinx-first-run` rewrites appearance.json and then signals the running dock
with `pkill -HUP dinx-dock`; SIGHUP re-reads the file and rebuilds the strip,
so placement changes apply without restarting the session.

## Shortcuts and settings

The default button list is compiled in, but the list can be managed without
editing JSON:

```sh
dinx-dockctl list
dinx-dockctl add org.dinx.Dintor.desktop
dinx-dockctl remove octopi.desktop
```

The helper validates desktop-entry ids, preserves the other appearance
settings, writes `appearance.json` atomically, and signals the running dock.
The optional `favorites` array has the same effect when managed directly:

```json
{"version": 1, "dock": "left", "favorites": ["firefox.desktop", "pcmanfm.desktop"]}
```

Each button resolves its desktop entry with `g_desktop_app_info_new` and
launches the resulting `GAppInfo` directly, with no shell. Missing or hidden
entries are skipped. The icon comes from `Icon=` and the tooltip from the
localized `Name=`.

## Running windows and activity feedback

KWM publishes its live window list through a private, per-user `SOCK_SEQPACKET`
socket in `$XDG_RUNTIME_DIR`. The socket is mode `0600`; the Dock requests a
bounded snapshot once per second and never scans processes. Window buttons use
desktop-entry icons where `app_id` matches and group windows by app id, with a
running underline and a stronger focused-window indicator. Hover tooltips show
the active window title. Clicking a running favorite focuses it; clicking a
non-running favorite launches its desktop entry.

Right-clicking a running icon offers **Close window**. KWM revalidates the
session and window id, then sends Wayland's graceful close request; it does not
send signals or force-kill processes. This task-list API currently requires
KWM. Without its socket, favorite launchers remain available.

A successfully launched favorite can also get an accent underline when
`show_activity` is enabled. This launch feedback is separate from live-window
state.
Optional settings in `appearance.json`:

```json
{
  "icon_size": 32,
  "edge_margin": 8,
  "box_spacing": 8,
  "show_activity": true
}
```

Values are bounded to safe ranges (icon 20–48px, margin 0–32px, spacing 0–16px).
The dock uses theme colors, 44px minimum button targets, visible keyboard
focus, and a 14% hover magnification without changing the strip's layout.


## Appearance and identity

The dock styles its compact surface and interaction states but inherits colours
and fonts from the session theme; it never forces `GTK_THEME`.

The Wayland app id and window class are `com.dinx.Dock`, taken from the program
name. A single instance is enforced with an advisory `flock` on
`$XDG_RUNTIME_DIR/dinx-dock.lock`; a second process exits 0 immediately. The
descriptor stays open for the process lifetime, so the kernel releases the lock
even if the dock is killed, and a stale file can never keep the dock away.

## Build

```sh
zig build -Dcpu=baseline -Doptimize=ReleaseSafe
```

Requires Zig 0.17 and the `gtk4` and `gtk4-layer-shell` development files, both
present in the builder image. The package builds in place from the checked-in
source tree, like `dinxpanel` and `dinx-first-run`.