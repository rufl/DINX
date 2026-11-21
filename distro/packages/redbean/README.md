# Redbean

Redbean is the experimental DINX shell for the `SHELL` branch and the future
NEXT image. It is a small Zig/GTK4 layer-shell process with Astal Apps for
freedesktop application discovery and fuzzy search.

The package is intentionally not in the current DINX profile or session
supervisor. This keeps the existing Morghulis session unchanged while Redbean
is qualified on the NEXT branch.

## Interaction modes

- **Windows mode**: a start-menu layout with search, categories, editable
  pinned DINX launchers, and fixed lock/logout actions.
- **Flow mode**: a keyboard-first launcher surface with one direct result
  stream and the same fixed actions.

Both modes use GTK semantic theme colors instead of hard-coded palette values,
so the four DINX GTK theme families control the final light/dark appearance.

## Integrated shell features

- `Mod4-p` opens Redbean when KWM seeds a new user config on NEXT.
- App search uses Astal Apps; `settings:` searches the settings catalog.
- `file:` searches the home directory up to a bounded depth and opens the
  selected path with the desktop default.
- Pin and unpin changes persist in `redbean.json` and reload `dinx-dock`.
- Focus previous/next, workspace previous/next, volume, mute, network,
  Bluetooth, audio, package, control-center, alert, and tray actions are
  available without nested menus.
- Notifications are listed and dismissible through Astal Notifd.
- The app-row **Manage** action maps a desktop entry to its owning pacman
  package and asks for an authenticated removal.

Absent optional control applications fail closed; the shell does not execute
user-provided shell text.

## Configuration

The selected mode and pinned desktop ids are persisted at:

```text
$XDG_CONFIG_HOME/dinx/redbean.json
```

or `$HOME/.config/dinx/redbean.json` when `XDG_CONFIG_HOME` is absent:

```json
{"version":1,"mode":"windows","pinned":["org.dinx.Deetty.desktop","pcmanfm.desktop","firefox.desktop"]}
```

The panel mode button switches modes without restarting the shell. Pinned ids
are validated against the desktop-entry filename grammar before persistence.

## Build and run

```sh
zig build -Dcpu=baseline -Doptimize=ReleaseSafe
./zig-out/bin/redbean
```
The DINX container builder compiles the package only when explicitly enabled:

```sh
DINX_BUILD_REDBEAN=true DINX_PACKAGE_REPOSITORY_ONLY=true \
  scripts/build-iso-docker.sh
```

Inside a running NEXT Wayland session, the runtime smoke keeps Redbean alive
long enough to validate GTK/layer-shell startup:

```sh
scripts/smoke_redbean.sh redbean
```

Redbean needs a Wayland compositor with `gtk4-layer-shell`. It exits cleanly
when no display is available and enforces one instance per session through
`$XDG_RUNTIME_DIR/redbean.lock`.
