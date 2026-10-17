# DinitUI

DinitUI is the DINX-native desktop frontend for the Dinit service manager.

## Design contract

- GTK4 and libadwaita, chosen instead of a Qt/QML bridge to keep the Zig build and runtime dependency graph small.
- DINX/Noctalia colors: `#0b0d12`, `#11151d`, `#d7dde8`, `#7f8a9c`, `#8fb8ff`, `#9ece6a`, `#f7768e`.
- Keyboard-first native controls, visible focus, no color-only state signal, and compact service-dashboard density.

## Control model

DinitUI invokes `dinitctl` with argv-safe arguments. It never shells service names through `/bin/sh`. System-scope actions first use the current user's `dinitctl --system` access and retry through `pkexec` only for an explicit authorization failure. User-scope actions use `dinitctl --user`.

The action catalog covers Dinit's control surface: start, stop, restart, reload, enable/disable (including an optional `--from` service), wake, release, unpin, unload, trigger/untrigger, `is-started`, `is-failed`, dependency add/remove, environment set/unset, buffered logs, signal delivery/listing, and shutdown. Service lists combine loaded units from `dinitctl list` with description files in the standard system or user directories; permission or I/O failures while discovering those files remain visible in the status footer.

The selected service is the target for service actions and the `from-service` for dependency actions. The extra-arguments field accepts whitespace-separated safe tokens such as `need target-service` or `PATH=/usr/bin`; it does not parse shell syntax or execute arbitrary commands.
`Shutdown Dinit` requires the literal extra token `CONFIRM` to prevent an accidental daemon/system shutdown.

## Performance profiles

DinitUI provides `normal`, `lite`, and `gaming` system-service profiles plus custom profiles. `lite` disables only the optional Bluetooth daemon. `gaming` explicitly enables `bluetoothd` for controllers and leaves Bluetooth, UFW, and OpenSnitch policy services available; it never trades network security or controller support for a benchmark gain. NetworkManager, D-Bus, PipeWire, WirePlumber, elogind, greetd, seatd, metalog, and display services are intentionally outside the default policies.

The GTK interface selects and applies profiles, creates custom profiles, and edits whether the selected system service is enabled in the selected profile. User-scope services are not changed by profile operations. Policies are stored per user in `~/.config/dinx/dinitui/profiles.conf`; the packaged defaults are `/etc/dinx/dinitui/profiles.conf`.

The CLI is used by Noctalia and DINXPanel. DINXPanel owns the visible hardware and driver controls; DinitUI remains focused on Dinit services and performance profiles.

```text
dinitui --profile-status
dinitui --profile-list
dinitui --apply-profile gaming
dinitui --toggle-profile
dinitui --gaming-enter
dinitui --gaming-leave
dinitui --gpu-status
dinitui --install-gpu-drivers
```

The `--gpu-*` commands are a fixed backend contract for DINXPanel: detection reads `lspci -nnk`, and installation builds an Artix `pacman --needed -S` plan. It uses `pkexec` only after an explicit root/authorization failure, never accepts package names from user input, and reports that a reboot is required after kernel-driver changes. NVIDIA uses `nvidia-open-dkms`, `nvidia-utils-dinit`, and the 32-bit userspace path for modern GPUs; legacy cards may need the matching `nvidia-580xx` family.

Noctalia applies the Dinit profile first and reports a separate power-profile synchronization failure instead of presenting the combined operation as fully successful.

Noctalia installs the `dinx/performance` plugin in the user skeleton. Its Control Center Gaming shortcut applies the Dinit profile and synchronizes Noctalia's `performance`/`balanced` power profile. Custom service membership remains a DinitUI concern and is opened from the plugin panel.
