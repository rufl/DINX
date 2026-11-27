# DINX compatibility contract

[English](compatibility.md) · [Português (Brasil)](pt-BR/compatibility.md)

DINX applications integrate through standard XDG metadata, Wayland protocols, D-Bus, PipeWire and dinit boundaries. The base session does not require shell-private IPC, systemd, uwsm or a shell service to be usable.

## Level 1 — direct integration

Required for the base ISO:

- Deetty has desktop ID `org.dinx.Deetty`, is launched by the `deetty` command, is discoverable through `$TERMINAL`, accepts documented terminal-launch arguments and honors a working directory when supplied.
- Dintor has desktop ID `org.dinx.Dintor`, is launched by the `dintor` command, opens files and directories through standard XDG launchers and accepts supported file/line arguments.
- ZLS 0.16.0 is available as an optional DINX package for Dintor's Zig LSP integration and is not part of the base image. C/C++ LSP support uses `clangd` from the optional `clang` package.
- Floorp is the default HTML, XHTML, HTTP and HTTPS handler.
- OpenSnitch is installed with its UI autostart and Dinit-managed daemon in both live and installed systems. Its nftables defaults allow traffic and do not intercept unknown apps; Firewalld remains a separate service.
- Phyto is the default directory handler; File Roller owns archive open/create/extract actions; GParted owns standalone partition editing.
- Pori discovers block devices through UDisks2 and persists user mounts through dinit services under `/etc/dinit.d`.
- Keyboard navigation and XDG configuration/data locations remain usable without a private shell integration.

## Level 2 — visual and session integration

The static DINX theme contract is the source of truth:

- palette: `/usr/share/dinx/theme/DINX.json`;
- user color choice: `DINTOR_THEME=prefer-light`;
- Qt6ct colors: `~/.config/qt6ct/colors/DINX.conf`;
- GTK theme: Adwaita defaults; Morghulis saves the light/dark choice in `~/.config/morghulis/preferences.json` and the session synchronizer applies it to dconf, GTK 3/4 and Qt6ct while preserving unrelated toolkit settings.
- fixed-width text: Noto Sans Mono 10 from the same subset where the application requires it;
- GUI bridges: DINX surface, control, hover, primary and error states with Adwaita icons where available; Papirus is the default desktop icon theme.

`DINTOR_THEME=prefer-light` selects the packaged light editor scheme; other values use the DINX dark scheme. Dintor does not parse private shell files and remains functional when the variable is unset.

Morghulis, Calamares and GRUB consume static DINX bridges because they run before or outside toolkit-specific application state. Deetty, PCManFM, Swayimg, btop, GTK and Qt use their checked-in DINX configuration paths. `ghostty-vt-runtime` supplies only Ghostty's VT library and headers for Deetty; it does not install the Ghostty terminal application. `scripts/check_morghulis_theme.sh` and `scripts/check-iso-content.sh` validate the theme and ISO payload.

## DinitUI service-manager contract

DinitUI is the DINX frontend for dinit, not a systemd compatibility layer. It discovers loaded services and description files, displays status and buffered logs, and exposes lifecycle, dependencies, environment, signals and daemon actions through validated `dinitctl` argv. It never interpolates user text into a shell command.

User scope uses `dinitctl --user`. System scope uses `dinitctl --system` and retries through `pkexec` only after an explicit authorization failure. `normal`, `lite`, `gaming` and user-defined profiles persist at `~/.config/dinx/dinitui/profiles.conf`; `lite` disables only optional Bluetooth, while `gaming` enables Bluetooth for controllers and preserves firewall/process-policy services. The standalone gaming launcher enters and restores the profile explicitly.

## Display and Seafoam integration

`dinx-wdisplays` launches the interactive Wayland display editor. On close it serializes the result with `flock`, atomically replaces the DINX-owned `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads Shikane. A reload failure is reported as failure. Shikane starts inside River/KWM/Morghulis and reapplies matching profiles when outputs change.

Seafoam Settings exposes fixed entry points for wdisplays, the profile saver, Shikane, DinitUI, DINXPanel, Qt6ct and Mission Center. Mission Center provides GTK4 resource/process monitoring. DINX native Zig packages use Zig 0.17.0. ZLS is an optional editor backend; when installed, its compact runtime contains the matching Zig 0.16.0 standard library and metadata shim. Installing the optional Artix `zig` package enables compiler commands through the same shim.

## River/KWM/Morghulis session contract

River is the compositor, KWM provides the window-management policy, Morghulis provides the desktop surface, and PCManFM provides the file manager/desktop. `dinx-river-session` prepares the Wayland runtime and executes the River session; `dinx-river-init` supervises KWM, Morghulis, PCManFM, Shikane, PolicyKit and idle helpers under dinit. The optional BC-250 control-center daemon starts only when its separately installed signed package is present.

- River/KWM/Morghulis is the base user session.
- The live ISO uses the direct `dinx-live-autologin` path; installed systems use manual greetd login through `tuigreet`, with Morghulis as the default River/KWM shell and Redbean as a secondary selectable shell.
- The Morghulis first-run helper saves the theme choice and the synchronizer reapplies it at login.
- Required-helper failure terminates the session instead of leaving a blank desktop.
- The session uses seatd/libseat and requires no systemd, systemctl, uwsm or user units.

- `swayidle` locks after 600 seconds and on `before-sleep`; `Super+L`, the launcher action and DINXPanel use the same `swaylock` path. `brightnessctl` supplies fixed 5-percent brightness steps.

## Gaming boundary

DINX Gaming is a hidden manual launcher, not a selectable user session. The ISO includes the launcher/desktop entry, but the Gamescope/Steam binaries and 32-bit libraries belong to the optional Artix `gaming` group, not the base profile. Base 64-bit RADV/Vulkan stays installed. The launcher checks Gamescope and Steam before changing the Dinit profile; missing-package fixtures verify that the transition does not occur. Real DRM output and authenticated gaming remain outside the qualification claim.

## Compatibility test matrix

| Area | Acceptance check |
| --- | --- |
| Terminal discovery | `$TERMINAL` launches Deetty with a shell and requested directory |
| Desktop metadata | `.desktop` entries are valid and discoverable |
| Optional desktop app launch | Gapless inherits the active Wayland session; firewall-config opens the Firewalld manager; Bluetooth Manager explains missing daemon/controller instead of failing silently (VirtualBox needs USB Bluetooth passthrough) |
| Launch arguments | file, line and working-directory behavior is deterministic |
| Theme contract | static DINX palette, system-wide GTK 3/4 dark defaults, session GTK dark selection, Qt6ct DINX palette, and GTK 3/4 fallback titlebar controls are configured |
| Greeter/installer/boot | tuigreet, Calamares and GRUB expose DINX surface, text, selection and focus states |
| Floorp default | Floorp handles HTML/XHTML/HTTP/HTTPS by default |
| Storage and files | Pori dinit persistence, PCManFM directory handling, File Roller archives and GParted partition editing are present |
| Desktop layout | River/KWM/Morghulis owns the base user session and PCManFM owns the desktop; fresh outputs preserve the declared session configuration |
| VM graphics | The full P0 gate tests the live desktop on default VGA and QEMU Virtio-VGA. Direct VirtualBox VMSVGA boot remains unqualified. |
| Window chrome | River/KWM and the session theme contracts verify Wayland client behavior and toolkit titlebar controls |
| Session safety | idle lock, suspend lock, explicit lock and brightness actions use fixed paths |
| Display persistence | wdisplays changes atomically update and reload the named Shikane profile |
| ZLS | Optional package; when installed, Dintor finds the matching Zig standard library without a full compiler |
| Package management | pacman, Shelly, paru and Topgrade use Artix configuration and remain user-invoked |
| Firewall/process monitoring | Firewalld, firewall-config, OpenSnitch and Mission Center are discoverable; firewalld-dinit is enabled at boot in live and installed root filesystems |
| DinitUI | service discovery and control use validated dinitctl argv with scoped pkexec fallback |
| Gaming | hidden launcher retained, optional package group excluded from base, missing Gamescope/Steam fail before profile changes; real gaming remains unqualified |
| Failure isolation | unavailable optional helpers or D-Bus endpoints produce visible failure without shell-dependent startup |
| Keyboard access | primary actions work without pointer input |

## Release gates

`scripts/check_deetty_integration.sh`, `scripts/dintor_p3_qualification.sh`, `scripts/check_dinitui.sh`, `scripts/check_river_session.sh`, `scripts/check_morghulis_theme.sh`, `scripts/check_mission_center.sh`, `scripts/check_dinx_display_persistence.sh` and `scripts/check-iso-content.sh` verify the package, session and ISO contracts. The P0 workflow remains the release gate for package creation, ISO assembly, QEMU boot, Calamares installation, recovery TTY, attestation and publication.
