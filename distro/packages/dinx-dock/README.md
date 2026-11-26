# DINX Dock

DINX Dock is the first-party Wayland dock for the River + kwm + Morghulis
desktop. Morghulis ships the bar, runner, quick menu, OSD and power menu, but
no dock; this component anchors a launch strip to one screen edge through
`gtk4-layer-shell` so kwm and river reserve its space instead of covering it.

## Placement

The dock reads `$XDG_CONFIG_HOME/dinx/appearance.json`, the file the DINX
first-run wizard writes at first login:

```json
{"version": 1, "dock": "left"}
```

`dock` accepts `left`, `right`, `bottom` or `none`. `none` keeps the dock
unmapped and the process exits with status 0, which is what the session
supervisor expects from an optional component that is deliberately off.

The dock is a core shell component, so a missing, unreadable or malformed
appearance file falls back to `left` rather than removing the launchers. Only
an explicit `"none"` disables it.

`dinx-first-run` rewrites appearance.json and then signals the running dock
with `pkill -HUP dinx-dock`; SIGHUP re-reads the file and rebuilds the strip,
so placement changes apply without restarting the session.

## Favorites

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

## Settings and running state

Use `dinx-dockctl set-edge left|right|bottom|none` to change placement. The
dock reloads this setting on SIGHUP and keeps the rest of `appearance.json`
unchanged. A running application gets an accent strip and a `Running: ...`
tooltip; the state refreshes every five seconds.

The installer has no dock button on purpose: `pcmanfm --desktop` renders
`~/Desktop`, where the session seeds an approved `Install DINX.desktop` for the
live user and removes it on installed systems, so a pinned button would
duplicate that affordance.

## Appearance and identity

Colours and fonts come from the toolkit theme the session already configured;
the dock never forces a theme or sets `GTK_THEME`. The only style it adds is
button padding and corner radius.

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
