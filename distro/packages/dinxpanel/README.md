# DINXPanel

DINXPanel is the DINX-native, lean GTK4/libadwaita control panel. A left navigation rail keeps the session categories stable while the selected page occupies the right side.

## Layout and persistence

- **Overview** keeps the most common Redbean, display, network and audio actions visible.
- **Redbean shell** opens Redbean and edits `$XDG_CONFIG_HOME/dinx/redbean.json`; Redbean persists its mode and pinned launchers there.
- **Appearance** opens Qt6ct, Morghulis and the session-theme synchronizer. The panel forces dark mode but uses Adwaita semantic roles, so all four DINX theme families retain their accents and contrast.
- **Compositor & windows** edits `~/.config/kwm/config.zon` and opens DinitUI profiles. River remains the compositor, KWM remains the tiling manager and KWIM remains the input manager.
- **Displays** uses the DINX `dinx-wdisplays` persistence wrapper; **Services & updates** contains DinitUI, upgrades, Shelly, Topgrade and optional CUPS.
- **System tools** exposes Mission Center, PCManFM, Pori, GParted and File Roller; **Session** exposes the read-only `dinx-doctor` report and installed-session locking.
- **Power** reports UPower state and exposes suspend, restart and power-off only in installed sessions; every destructive action uses an Adwaita confirmation dialog before calling `loginctl`.
- The sidebar search filters settings pages in place and exposes an explicit empty state; **Hardware** also opens the read-only DINX qualification report.
- Network, audio and USB pages include Deetty-backed diagnostics using fixed `nmcli`, `wpctl` and `lsusb` argv.

## Safety boundary

- panel actions use direct argv through GLib process spawning;
- no button accepts a command line or package name from user input;
- CUPS installation uses only the fixed `cups-dinit` package and retries through `pkexec` only after a direct pacman permission failure;
- GPU detection/installation delegates only to the fixed `dinitui --gpu-*` CLI contract;
- kernel installation accepts only `linux`, `linux-lts`, `linux-zen` and `linux-hardened`;
- kernel operations install packages and headers but never remove a kernel, especially not the running kernel;
- reboot is required after a kernel or kernel-driver change; rollback means selecting an already-installed alternative from the bootloader, not removing a package in DINXPanel.

## Upgrade integration

`Check upgrades` refreshes Shelly package metadata, lists available standard/AUR/Flatpak/AppImage updates, refreshes optional fwupd metadata and lists available firmware releases. It does not install anything. Missing optional tools are reported in the operation output instead of being silently ignored.

`Topgrade preview` opens `topgrade --dry-run --show-skipped --no-self-update --no-tmux`, so the user can review package, firmware and other configured upgrade steps without a self-update or nested tmux session. `Topgrade` runs the complete workflow. `Shelly upgrade` runs `shelly upgrade all` in a terminal with Shelly's own confirmation and policy boundaries.

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
shelly sync
shelly list-updates all
topgrade --dry-run --show-skipped --no-self-update --no-tmux
fwupdmgr refresh
fwupdmgr get-updates
dinxpanel
```

The display shortcut targets DINX's `dinx-wdisplays` wrapper. It opens `wdisplays`; closing it replaces the DINX-owned `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads the session's Shikane daemon. Use `dinx-save-shikane-profile` to save without reopening the editor.

The Firewall button opens `firewall-config`; Artix's `firewalld-dinit` service is enabled at boot in both live and installed root filesystems.
