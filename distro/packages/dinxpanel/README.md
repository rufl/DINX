# DINXPanel

DINXPanel is the DINX-native, lean GTK4/libadwaita control panel. A left navigation rail keeps the session categories stable while the selected page occupies the right side.

## Layout and persistence

- **Overview** keeps the most common Redbean, display, network and audio actions visible.
- **Redbean shell** opens Redbean and edits `$XDG_CONFIG_HOME/dinx/redbean.json`; Redbean persists its mode and pinned launchers there, and **DINX tools** can refresh `dinx-dock` after pin changes.
- **Appearance** applies the persisted light/dark Morghulis theme, opens Qt6ct and Morghulis, chooses a PCManFM wallpaper and persists desktop-icon visibility. The panel itself forces dark mode but uses Adwaita semantic roles, so all four DINX theme families retain their accents and contrast.
- **Compositor & windows** edits `~/.config/kwm/config.zon` and opens DinitUI profiles. River remains the compositor, KWM remains the tiling manager and KWIM remains the input manager.
- **Displays** uses the DINX `dinx-wdisplays` persistence wrapper; **Services & updates** contains DinitUI, upgrades, Shelly, Topgrade and optional CUPS.
- **System tools** exposes Mission Center, PCManFM, PCManFM desktop preferences, Pori, GParted and File Roller; **DINX tools** exposes Deetty, Dintor, Redbean/KWM editors and the dock refresh action.
- **Session** exposes the read-only `dinx-doctor` report and installed-session locking.
- **Power** reports UPower state and exposes suspend, restart and power-off only in installed sessions; every destructive action uses an Adwaita confirmation dialog before calling `loginctl`.
- The sidebar search filters settings pages in place and exposes an explicit empty state; **Hardware** also opens the read-only DINX qualification report.
- Network, audio and USB pages include Deetty-backed diagnostics using fixed `nmcli`, `wpctl` and `lsusb` argv.

## Appearance integration

`Apply dark session theme` and `Apply light session theme` update Morghulis' persisted
`preferences.json` atomically, then synchronize GTK, dconf and Qt6ct through
`dinx-sync-session-theme`. `Choose wallpaper` uses GTK's local-file dialog and passes
the selected path directly to `pcmanfm -w`; no shell command line is assembled.
`Show desktop icons` and `Hide desktop icons` persist a DINX visibility flag and call
PCManFM's documented `--desktop`/`--desktop-off` controls. River restores that choice
on the next login.

## Shell and tool integration

Deetty is the terminal surface for diagnostics and update previews; Dintor edits
Redbean and KWM configuration files. Redbean remains the secondary shell and its
pin changes can signal `dinx-dock` with the fixed `pkill -HUP dinx-dock` argv.

## Safety boundary

- panel actions use direct argv through GLib process spawning;
- no button accepts a command line or package name from user input;
- CUPS installation uses only the fixed `cups-dinit` package and retries through `pkexec` only after a direct pacman permission failure;
- GPU detection/installation delegates only to the fixed `dinitui --gpu-*` CLI contract;
- kernel installation accepts only `linux`, `linux-lts`, `linux-zen` and `linux-hardened`;
- kernel operations install packages and headers but never remove a kernel, especially not the running kernel;
- reboot is required after a kernel or kernel-driver change; rollback means selecting an already-installed alternative from the bootloader, not removing a package in DINXPanel.

## Upgrade integration

`Check upgrades` refreshes the pacman database snapshot with `checkupdates` (from `pacman-contrib`), lists pending AUR updates with `paru -Qu`, refreshes optional fwupd metadata and lists available firmware releases. It does not install anything. Missing optional tools are reported in the operation output instead of being silently ignored.

`PaintFE` launches the pinned raster image editor directly and `Package manager` opens Octopi, the graphical pacman/AUR frontend, for interactive package changes. Octopi has no command-line interface, so it is launched as an application rather than queried for the upgrade report; elevation inside Octopi goes through `pkexec` and the session's `lxqt-policykit-agent`, matching the installer and GParted launchers.

Firmware discovery uses `fwupdmgr refresh` and `fwupdmgr get-updates`; a `fwupdmgr` exit code 2 means “no action” and is treated as a normal no-update result. `fwupd` is optional because firmware support depends on the platform and repository payload.

## Optional printing support

The DINX ISO does not bundle CUPS. After installation, open DINXPanel and choose
**Services & updates → Install CUPS**. DINX downloads the signed `cups-dinit`
package from the configured Artix repository; its dependency installs CUPS and
the package supplies the `cupsd` dinit service. Enable or start `cupsd` from
DinitUI after installation when printing is needed. The fixed package action
does not accept arbitrary package names.

## Session controls

In installed sessions, `Brightness down`, `Brightness up` and `Lock screen` use fixed argv for `brightnessctl set 5%-`, `brightnessctl set 5%+` and `/usr/local/libexec/dinx-lock`. The live session hides the `Lock screen`, suspend, restart and power-off buttons; it retains display blanking through `/usr/local/libexec/dinx-idle`. Installed-session idle and suspend ordering are owned by the same wrapper.

## CLI-backed operations

```text
dinitui --gpu-status
dinitui --install-gpu-drivers
checkupdates
paru -Qu
paintfe
octopi
fwupdmgr refresh
fwupdmgr get-updates
dinxpanel
```

The display shortcut targets DINX's `dinx-wdisplays` wrapper. It opens `wdisplays`; closing it replaces the DINX-owned `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads the session's Shikane daemon. Use `dinx-save-shikane-profile` to save without reopening the editor.

The Firewall button opens `firewall-config`; Artix's `firewalld-dinit` service is enabled at boot in both live and installed root filesystems.
