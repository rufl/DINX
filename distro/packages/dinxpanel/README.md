# DINXPanel

DINXPanel is the DINX-native, YaST-inspired system control center. It groups fixed entry points for hardware, network, Bluetooth, audio, display, brightness, session lock, Dinit services, MangoWC options, firewall, updates and kernel installation.

## Safety boundary

- panel actions use direct argv through GLib process spawning;
- no button accepts a command line or package name from user input;
- GPU detection/installation delegates only to the fixed `dinitui --gpu-*` CLI contract;
- kernel installation accepts only `linux`, `linux-lts`, `linux-zen` and `linux-hardened`;
- kernel operations install packages and headers but never remove a kernel, especially not the running kernel;
- reboot is required after a kernel or kernel-driver change; rollback means selecting an already-installed alternative from the bootloader, not removing a package in DINXPanel.

## Upgrade integration

`Check upgrades` refreshes Shelly package metadata, lists available standard/AUR/Flatpak/AppImage updates, refreshes optional fwupd metadata and lists available firmware releases. It does not install anything. Missing optional tools are reported in the operation output instead of being silently ignored.

`Topgrade preview` opens `topgrade --dry-run --show-skipped --no-self-update --no-tmux`, so the user can review package, firmware and other configured upgrade steps without a self-update or nested tmux session. `Topgrade` runs the complete workflow. `Shelly upgrade` runs `shelly upgrade all` in a terminal with Shelly's own confirmation and policy boundaries.

Firmware discovery uses `fwupdmgr refresh` and `fwupdmgr get-updates`; a `fwupdmgr` exit code 2 means “no action” and is treated as a normal no-update result. `fwupd` is optional because firmware support depends on the platform and repository payload.
## Session controls

The panel's `Brightness down`, `Brightness up` and `Lock screen` buttons use direct argv for `brightnessctl set 5%-`, `brightnessctl set 5%+` and `swaylock -f`. The session also exposes the same lock path through `Super+L`; idle and suspend ordering are owned by `/usr/local/libexec/dinx-idle`.

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

The display shortcut targets `wdisplays` when that optional Wayland utility is installed. MangoWC options open the user's fixed `~/.config/mango/config.conf` in `nano` through `foot`; they do not evaluate configuration as shell input.
