# DINX compatibility contract

[English](compatibility.md) · [Português (Brasil)](pt-BR/compatibility.md)

DINX applications integrate through standard XDG metadata, Wayland protocols, D-Bus, PipeWire and dinit boundaries. The base session does not require shell-private IPC, systemd, uwsm or a shell service to be usable.

## Level 1 — direct integration

Required for the base ISO:

- Deetty has desktop ID `org.dinx.Deetty`, is launched by the `deetty` command, is discoverable through `$TERMINAL`, accepts documented terminal-launch arguments and honors a working directory when supplied.
- Dintor has desktop ID `org.dinx.Dintor`, is launched by the `dintor` command, opens files and directories through standard XDG launchers and accepts supported file/line arguments.
<<<<<<< HEAD
- ZLS 0.16.0 is available as an optional DINX package for Dintor's Zig LSP integration and is not part of the base image. C/C++ LSP support uses `clangd` from the optional `clang` package.
- Floorp is the default HTML, XHTML, HTTP and HTTPS handler.
- OpenSnitch is installed with its UI autostart and Dinit-managed daemon in both live and installed systems. Its nftables defaults allow traffic and do not intercept unknown apps; Firewalld remains a separate service.
- Phyto is the default directory handler; File Roller owns archive open/create/extract actions; GParted owns standalone partition editing.
=======
- The ISO includes ZLS 0.16.0 for Dintor's Zig LSP integration. C/C++ LSP support uses `clangd` from the optional `clang` package and is not part of the default image.
- Firefox is the default HTML, XHTML, HTTP and HTTPS handler.
- Firewalld is installed with `firewall-config` and its Dinit-managed service enabled at boot in both live and installed systems.
- PCManFM is the default directory handler and renders the `~/Desktop` icons through `pcmanfm --desktop`; File Roller owns archive open/create/extract actions; GParted owns standalone partition editing.
>>>>>>> main
- Pori discovers block devices through UDisks2 and persists user mounts through dinit services under `/etc/dinit.d`.
- Keyboard navigation and XDG configuration/data locations remain usable without a private shell integration.

## Level 2 — visual and session integration

The static DINX theme contract is the source of truth:

- palette: `/usr/share/dinx/theme/DINX.json`;
- user color choice: `DINTOR_THEME=prefer-light`;
- Qt6ct colors: `~/.config/qt6ct/colors/DINX.conf`;
<<<<<<< HEAD
- GTK theme: Adwaita defaults; Morghulis saves the light/dark choice in `~/.config/morghulis/preferences.json` and the session synchronizer applies it to dconf, GTK 3/4 and Qt6ct while preserving unrelated toolkit settings.
=======
- GTK theme: the system and skeleton defaults are Adwaita with `gtk-application-prefer-dark-theme=1`, and the session applies the theme family chosen in the first-run wizard, with Noto Sans 10 from DINX's Latin/Latin Extended font subset. `dinx-river-session` exports `DINX_COLOR_SCHEME=dark` and `DINTOR_THEME=prefer-dark` as recovery defaults and no longer exports `GTK_APPLICATION_PREFER_DARK_THEME` or `ADW_DEBUG_COLOR_SCHEME`; once session D-Bus is ready, `dinx-sync-session-theme` reads `~/.config/dinx/appearance.json` and writes the matching dconf `prefer-dark`/`prefer-light` color scheme, the selected `gtk-theme-name` (DINX by default) and the DINX Qt6ct palette. A missing or invalid `appearance.json` falls back to the DINX dark default. Unrelated toolkit settings are preserved.
>>>>>>> main
- fixed-width text: Noto Sans Mono 10 from the same subset where the application requires it;
- GUI bridges: DINX surface, control, hover, primary and error states with Adwaita icons where available; Papirus is the default desktop icon theme.

`DINTOR_THEME=prefer-light` selects the packaged light editor scheme; other values use the DINX dark scheme. Dintor does not parse private shell files and remains functional when the variable is unset.

<<<<<<< HEAD
Morghulis, Calamares and GRUB consume static DINX bridges because they run before or outside toolkit-specific application state. Deetty, PCManFM, Swayimg, btop, GTK and Qt use their checked-in DINX configuration paths. `ghostty-vt-runtime` supplies only Ghostty's VT library and headers for Deetty; it does not install the Ghostty terminal application. `scripts/check_morghulis_theme.sh` and `scripts/check-iso-content.sh` validate the theme and ISO payload.
=======
agreety, Calamares and GRUB consume static DINX bridges because they run before or outside the user session. agreety runs under greetd as the `greeter` account with `XDG_CACHE_HOME=/var/cache/agreety`; no separate greeter theme file exists. Deetty, Swayimg, btop, GTK and Qt use their checked-in DINX configuration paths. `ghostty-vt-runtime` supplies only Ghostty's VT library and headers for Deetty; it does not install the Ghostty terminal application. `scripts/check_dinx_theme.sh` validates the palette, typography, state colors and bridges; `scripts/check-iso-content.sh` repeats those checks inside SquashFS.
>>>>>>> main

## DinitUI service-manager contract

DinitUI is the DINX frontend for dinit, not a systemd compatibility layer. It discovers loaded services and description files, displays status and buffered logs, and exposes lifecycle, dependencies, environment, signals and daemon actions through validated `dinitctl` argv. It never interpolates user text into a shell command.

User scope uses `dinitctl --user`. System scope uses `dinitctl --system` and retries through `pkexec` only after an explicit authorization failure. `normal`, `lite`, `gaming` and user-defined profiles persist at `~/.config/dinx/dinitui/profiles.conf`; `lite` disables only optional Bluetooth, while `gaming` enables Bluetooth for controllers and preserves firewall/process-policy services. The standalone gaming launcher enters and restores the profile explicitly.

<<<<<<< HEAD
## Display and Seafoam integration

`dinx-wdisplays` launches the interactive Wayland display editor. On close it serializes the result with `flock`, atomically replaces the DINX-owned `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads Shikane. A reload failure is reported as failure. Shikane starts inside River/KWM/Morghulis and reapplies matching profiles when outputs change.

Seafoam Settings exposes fixed entry points for wdisplays, the profile saver, Shikane, DinitUI, DINXPanel, Qt6ct and Mission Center. Mission Center provides GTK4 resource/process monitoring. DINX native Zig packages use Zig 0.17.0. ZLS is an optional editor backend; when installed, its compact runtime contains the matching Zig 0.16.0 standard library and metadata shim. Installing the optional Artix `zig` package enables compiler commands through the same shim.

## River/KWM/Morghulis session contract

River is the compositor, KWM provides the window-management policy, Morghulis provides the desktop surface, and PCManFM provides the file manager/desktop. `dinx-river-session` prepares the Wayland runtime and executes the River session; `dinx-river-init` supervises KWM, Morghulis, PCManFM, Shikane, PolicyKit and idle helpers under dinit. The optional BC-250 control-center daemon starts only when its separately installed signed package is present.

- River/KWM/Morghulis is the base user session.
- The live ISO uses the direct `dinx-live-autologin` path; installed systems use manual greetd login through `agreety`.
- The Morghulis first-run helper saves the theme choice and the synchronizer reapplies it at login.
- Required-helper failure terminates the session instead of leaving a blank desktop.
- The session uses seatd/libseat and requires no systemd, systemctl, uwsm or user units.

- `swayidle` locks after 600 seconds and on `before-sleep`; `Super+L`, the launcher action and DINXPanel use the same `swaylock` path. `brightnessctl` supplies fixed 5-percent brightness steps.
=======
## River/KWM session contract

River and KWM negotiate `xdg-decoration` with each XDG client: windows that accept server-side decorations receive the compositor's own DINX-styled frame, while clients that keep client-side decorations are never decorated twice. `GTK_CSD=0` disables GTK's default CSD, not application-owned custom headerbars. `dinx-river-session` exports `MOZ_GTK_TITLEBAR_DECORATION=system` because Gecko clients such as Firefox select client decorations before checking `GTK_CSD`, and the shipped GTK defaults carry `gtk-decoration-layout=:minimize,maximize,close`.

There is no compositor corner radius and no border-color synchronisation, so appearance comes from the GTK theme the first-run wizard selected, DINX dark by default. kwim owns input-device configuration separately from the window manager, so keyboard layouts and touchpad settings live in kwim's configuration rather than in a shell settings application.

- River/KWM is the only selectable and supported DINX user session.
- The live ISO opens `dinx` from the restartable `dinx-live-session` Dinit service with seatd and a private runtime directory; greetd remains installed-only and the installed rootfs keeps manual login.
- agreety under greetd is the installed login surface, not a second user session; the DINX image ships a single wayland-sessions entry, `River + KWM + Morghulis (DINX)`, and there is no silent session fallback.
- `agreety --cmd /usr/local/libexec/dinx-river-session` starts the session. River 0.5 ships no `riverctl` and does not start a window manager, so `dinx-river-init` execs `dinx-session-supervisor river`; the supervisor waits for Wayland and session D-Bus readiness, starts KWM as the required window manager, runs the first-run appearance glue `/usr/local/libexec/dinx-desktop-first-run`, then starts Shikane, the LXQt PolicyKit agent, the required idle helper and the required Morghulis shell. KWM starts KWIM for input management. The supervisor starts `dinx-dock` as an optional helper and the optional BC-250 daemon only when its separately installed signed package is present; install that package only after PCI `1002:13fe` is detected. The generic ISO omits all BC-250-specific packages.
- Required-helper or supervisor failure records an explicit failed state and terminates river instead of leaving a blank desktop.
- The live session uses seatd/libseat; installed sessions retain runtime backend selection with elogind available. Both paths execute directly under dinit and require no systemd, systemctl, uwsm or user units.

- `swayidle` locks after 600 seconds and on `before-sleep`; the `dinx-lock` launcher action and DINXPanel use the same `swaylock` path, and `dinx-lock` refuses to lock the disposable live session. `brightnessctl` supplies fixed 5-percent brightness steps.

## Display configuration

`dinx-wdisplays` launches the interactive Wayland display editor. On close it serializes the result with `flock`, atomically replaces the DINX-owned `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads Shikane. A reload failure is reported as failure. Shikane starts inside the River/KWM session and reapplies matching profiles when outputs change.

Display configuration is reached through the `dinx-wdisplays` wrapper, the `dinx-save-shikane-profile` exporter, the Shikane user daemon and DINXPanel's `Display` action; there is no separate settings launcher. DINX native Zig packages use Zig 0.17.0. ZLS remains an editor backend; its compact runtime contains the matching Zig 0.16.0 standard library and metadata shim, not the full compiler. Installing the optional Artix `zig` package enables compiler commands through the same shim.
>>>>>>> main

## Gaming boundary

DINX Gaming is a hidden manual launcher, not a selectable user session. The ISO includes the launcher/desktop entry, but the Gamescope/Steam binaries and 32-bit libraries belong to the optional Artix `gaming` group, not the base profile. Base 64-bit RADV/Vulkan stays installed. The launcher checks Gamescope and Steam before changing the Dinit profile; missing-package fixtures verify that the transition does not occur. Real DRM output and authenticated gaming remain outside the qualification claim.

## Compatibility test matrix

| Area | Acceptance check |
| --- | --- |
| Terminal discovery | `$TERMINAL` launches Deetty with a shell and requested directory |
| Desktop metadata | `.desktop` entries are valid and discoverable |
| Optional desktop app launch | Gapless inherits the active Wayland session; firewall-config opens the Firewalld manager; Bluetooth Manager explains missing daemon/controller instead of failing silently (VirtualBox needs USB Bluetooth passthrough) |
| Launch arguments | file, line and working-directory behavior is deterministic |
<<<<<<< HEAD
| Theme contract | static DINX palette, system-wide GTK 3/4 dark defaults, session GTK dark selection, Qt6ct DINX palette, and GTK 3/4 fallback titlebar controls are configured |
| Greeter/installer/boot | agreety, Calamares and GRUB expose DINX surface, text, selection and focus states |
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
=======
| Theme contract | static DINX palette, system-wide GTK 3/4 dark defaults, saved session GTK theme selection, Qt6ct DINX palette, and GTK 3/4 fallback titlebar controls are configured |
| Greeter/installer/boot | agreety, Calamares and GRUB expose DINX surface, text, selection and focus states |
| Firefox default | Firefox handles HTML/XHTML/HTTP/HTTPS by default |
| Storage and files | Pori dinit persistence, PCManFM directory handling, File Roller archives and GParted partition editing are present |
| Desktop layout | River/KWM owns the only user session; the supervisor starts KWM as the required `river-window-management-v1` implementation, so new windows are tiled by KWM and floating/stacking behavior and the workspace count come from the user's `~/.config/kwm/config.zon`. That file is seeded from `/etc/xdg/kwm/config.zon` only when absent, so existing user config is preserved |
| VM graphics | A prior manual report reached the DINX desktop in VirtualBox 7.2.22 on Windows 11 (VMSVGA, 3D enabled, EFI, 4 vCPUs, 8 GiB); its log did not prove ISO boot selection or checksum, so it is not release-wide qualification. The current source routes accessible `vmwgfx`/`vboxvideo` render nodes through Pixman (`WLR_RENDERER=pixman`) because the attached VMSVGA log showed VirtualBox's llvmpipe Vulkan device failing DRM-device matching; QEMU `virtio_gpu` uses reduced-effects GLES2. Client-surface rendering on the rebuilt ISO is still awaiting direct VirtualBox verification. |
| VM graphics | The full P0 gate tests the live desktop on default VGA and QEMU Virtio-VGA. QEMU 11.1.2/KVM's `vmware-svga` path stalls in early udev with `vmwgfx` loaded and is not a reliable VirtualBox proxy; direct VirtualBox VMSVGA boot remains unqualified. |
| Window chrome | Session smoke verifies the negotiated xdg-decoration policy, Firefox/Gecko system decorations, the fixed `:minimize,maximize,close` GTK decoration layout and the saved DINX appearance |
| Session safety | idle lock, suspend lock, explicit lock and brightness actions use fixed paths |
| Display persistence | wdisplays changes atomically update and reload the named Shikane profile |
| ZLS | Dintor finds the bundled matching Zig standard library without a full compiler |
| Package management | pacman, `paru` and Octopi use Artix configuration and remain user-invoked |
| Firewall monitoring | Firewalld and `firewall-config` are discoverable; firewalld-dinit is enabled at boot in live and installed root filesystems |
>>>>>>> main
| DinitUI | service discovery and control use validated dinitctl argv with scoped pkexec fallback |
| Gaming | hidden launcher retained, optional package group excluded from base, missing Gamescope/Steam fail before profile changes; real gaming remains unqualified |
| Failure isolation | unavailable optional helpers or D-Bus endpoints produce visible failure without shell-dependent startup |
| Keyboard access | primary actions work without pointer input |

## Release gates

<<<<<<< HEAD
`scripts/check_deetty_integration.sh`, `scripts/dintor_p3_qualification.sh`, `scripts/check_dinitui.sh`, `scripts/check_river_session.sh`, `scripts/check_morghulis_theme.sh`, `scripts/check_mission_center.sh`, `scripts/check_dinx_display_persistence.sh` and `scripts/check-iso-content.sh` verify the package, session and ISO contracts. The P0 workflow remains the release gate for package creation, ISO assembly, QEMU boot, Calamares installation, recovery TTY, attestation and publication.
=======
`scripts/check_deetty_integration.sh`, `scripts/dintor_p3_qualification.sh`, `scripts/check_dinitui.sh`, `scripts/check_dinx_session.sh`, `scripts/check_dinx_display_persistence.sh`, `scripts/check_dinx_theme.sh`, `scripts/check_pori_storage.sh` and `scripts/check-iso-content.sh` verify the package, session and ISO contracts. The P0 workflow remains the release gate for package creation, ISO assembly, QEMU boot, Calamares installation, recovery TTY, attestation and publication.
>>>>>>> main
