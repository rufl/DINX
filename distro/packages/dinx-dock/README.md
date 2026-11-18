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

The button list is fixed and compiled in. Each button resolves a desktop entry
id with `g_desktop_app_info_new` and launches the resolved `GAppInfo` directly,
with no arguments and no shell:

| Button   | Desktop entry             |
| -------- | ------------------------- |
| Terminal | `org.dinx.Deetty.desktop` |
| Files    | `pcmanfm.desktop`         |
| Browser  | `firefox.desktop`         |
| Editor   | `org.dinx.Dintor.desktop` |
| Packages | `octopi.desktop`          |
| Dashboard | `dinxpanel.desktop`      |

An entry that is absent or hidden resolves to nothing and its button is
skipped: the dock never fails because an application is not installed. The
icon comes from the entry's `Icon=` key and the tooltip from its localized
`Name=`, so both follow the installed desktop entry and the session locale.

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
