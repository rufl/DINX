# DINX compatibility contract

[English](compatibility.md) · [Português (Brasil)](pt-BR/compatibility.md)

DINX applications integrate through standard XDG metadata, Wayland protocols, D-Bus, PipeWire and dinit boundaries. The base session does not require shell-private IPC, systemd, uwsm or a shell service to be usable.

## Level 1 — direct integration

Required for the base ISO:

- Deetty has desktop ID `org.dinx.Deetty`, is launched by the `deetty` command, is discoverable through `$TERMINAL`, accepts documented terminal-launch arguments and honors a working directory when supplied.
- Dintor has desktop ID `org.dinx.Dintor`, is launched by the `dintor` command, opens files and directories through standard XDG launchers and accepts supported file/line arguments.
- Dintor launches the documented LSP for the file type. Zig uses bundled ZLS 0.16.0; C/C++ uses `clangd`.
- Firefox is the default HTML, XHTML, HTTP and HTTPS handler.
- Phyto is the default directory handler; File Roller owns archive open/create/extract actions; GParted owns standalone partition editing.
- Pori discovers block devices through UDisks2 and persists user mounts through dinit services under `/etc/dinit.d`.
- Keyboard navigation and XDG configuration/data locations remain usable without a private shell integration.

## Level 2 — visual and session integration

The static DINX theme contract is the source of truth:

- palette: `/usr/share/dinx/theme/DINX.json`;
- user color choice: `DINTOR_THEME=prefer-light`;
- Qt6ct colors: `~/.config/qt6ct/colors/DINX.conf`;
- GTK theme: installed `DINX` theme with Noto Sans 10;
- fixed-width text: Noto Sans Mono 10 where the application requires it;
- GUI bridges: DINX surface, control, hover, primary and error states with Adwaita icons where available.

`DINTOR_THEME=prefer-light` selects the packaged light editor scheme; other values use the DINX dark scheme. Dintor does not parse private shell files and remains functional when the variable is unset.

Pearl Greeter, Calamares and GRUB consume static DINX bridges because they run before or outside the user session. Pearl Greeter reads `/etc/pearl/greeter.json`, runs under the dedicated `pearl-greeter` account and forces the single Aqueous/Pearl desktop entry with X11 and UWSM disabled. Deetty, Swayimg, btop, GTK and Qt use their checked-in DINX configuration paths. `ghostty-vt-runtime` supplies only Ghostty's VT library and headers for Deetty; it does not install the Ghostty terminal application. `scripts/check_dinx_theme.sh` validates the palette, typography, state colors and bridges; `scripts/check-iso-content.sh` repeats those checks inside SquashFS.

## DinitUI service-manager contract

DinitUI is the DINX frontend for dinit, not a systemd compatibility layer. It discovers loaded services and description files, displays status and buffered logs, and exposes lifecycle, dependencies, environment, signals and daemon actions through validated `dinitctl` argv. It never interpolates user text into a shell command.

User scope uses `dinitctl --user`. System scope uses `dinitctl --system` and retries through `pkexec` only after an explicit authorization failure. `normal`, `lite`, `gaming` and user-defined profiles persist at `~/.config/dinx/dinitui/profiles.conf`; `lite` disables only optional Bluetooth, while `gaming` enables Bluetooth for controllers and preserves firewall/process-policy services. The standalone gaming launcher enters and restores the profile explicitly.

## Aqueous/Pearl session contract

Every Aqueous top-level window displays a compositor-drawn DINX titlebar with the window title and minimize, maximize/restore and close buttons, including GTK and Pearl clients. Long titles are ellipsized before the controls. The session sets `GTK_CSD=0`, and Aqueous requests server-side decorations, so standard GTK windows use the compositor titlebar; Wayland clients that honor xdg-decoration receive the same request. Dragging any unobstructed part of the titlebar moves the window and uses Aqueous floating-window snapping: side/bottom edges snap to halves, corners to quarters, and the top edge maximizes. Fullscreen windows hide the titlebar. Apps that hard-code custom client-side titlebars and ignore server-decoration requests can still draw beneath the compositor bar; Wayland does not provide a generic way for the compositor to remove client-rendered content. Menus and popups are not top-level windows and keep their own behavior.

- Aqueous/Pearl is the only selectable and supported DINX user session.
- The live ISO opens `dinx` directly through the dinit autologin path; the installed rootfs keeps manual login.
- Pearl Greeter is the installed greetd login UI, not a second user session; its root-owned config forces `Aqueous + Pearl (DINX)` and has no silent session fallback.
- `dinx-aqueous-pearl` starts Aqueous directly. The init child waits for Wayland and session D-Bus readiness, then the supervisor starts Shikane, PolicyKit, the required idle helper and Pearl. It starts the optional BC-250 daemon only when its separately installed signed package is present; install that package only after PCI `1002:13fe` is detected. The generic ISO omits all BC-250-specific packages.
- Required-helper or Pearl failure records an explicit failed state and terminates the compositor instead of leaving a blank desktop.
- The session uses elogind/libseat and direct dinit execution; it does not require systemd, systemctl, uwsm or user units.

- `swayidle` locks after 600 seconds and on `before-sleep`; `Super+L`, the launcher action and DINXPanel use the same `swaylock` path. `brightnessctl` supplies fixed 5-percent brightness steps.

## Display and Seafoam integration

`dinx-wdisplays` launches the interactive Wayland display editor. On close it serializes the result with `flock`, atomically replaces the DINX-owned `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads Shikane. A reload failure is reported as failure. Shikane starts inside Aqueous/Pearl and reapplies matching profiles when outputs change.

Seafoam Settings exposes fixed entry points for wdisplays, the profile saver, Shikane, DinitUI, DINXPanel, Qt6ct and Dome. Dome provides dinit-safe resource/process monitoring. DINX native Zig packages use Zig 0.17.0. ZLS remains an editor backend; its compact runtime contains the matching Zig 0.16.0 standard library and metadata shim, not the full compiler. Installing the optional Artix `zig` package enables compiler commands through the same shim.

## Gaming boundary

DINX Gaming is a hidden manual launcher, not a selectable user session. The ISO includes the launcher/desktop entry, but the Gamescope/Steam binaries and 32-bit libraries belong to the optional Artix `gaming` group, not the base profile. Base 64-bit RADV/Vulkan stays installed. The launcher checks Gamescope and Steam before changing the Dinit profile; missing-package fixtures verify that the transition does not occur. Real DRM output and authenticated gaming remain outside the qualification claim.

## Compatibility test matrix

| Area | Acceptance check |
| --- | --- |
| Terminal discovery | `$TERMINAL` launches Deetty with a shell and requested directory |
| Desktop metadata | `.desktop` entries are valid and discoverable |
| Launch arguments | file, line and working-directory behavior is deterministic |
| Theme contract | static DINX palette, system-wide GTK 3/4 dark defaults, session GTK dark selection, Qt6ct DINX palette, and GTK 3/4 fallback titlebar controls are configured |
| Greeter/installer/boot | Pearl Greeter, Calamares and GRUB expose DINX surface, text, selection and focus states |
| Firefox default | Firefox handles HTML/XHTML/HTTP/HTTPS by default |
| Storage and files | Pori dinit persistence, Phyto directory handling, File Roller archives and GParted partition editing are present |
| Desktop layout | Aqueous/Pearl owns the only user session; fresh outputs start with two workspaces and floating stacking. Default tile, scrolling, monocle and grid layout shortcuts (`Super+T/F/M/G`) are disabled; dragging to left/right/bottom edges snaps to halves, corners to quarters, top-center maximizes (24 px threshold, no gap). Existing user config is preserved |
| VM graphics | Accessible DRM render nodes select GLES2 for QEMU `virtio_gpu`/virgl and VirtualBox VMSVGA (`vmwgfx`); missing/inaccessible nodes and 2D-only adapters use Pixman/Cairo. Alpha 11's wlroots library omitted GLES2, so VMSVGA exits to the greeter; the source recipe now requests and checks GLES2 + Vulkan and requires a rebuilt ISO. Host-side 3D acceleration is configured separately |
| Window chrome | Pinned Aqueous patches and source smoke verify Wayland/XWayland title-cache invalidation, titlebar control hit zones, and floating half/quarter snap geometry |
| Session safety | idle lock, suspend lock, explicit lock and brightness actions use fixed paths |
| Display persistence | wdisplays changes atomically update and reload the named Shikane profile |
| ZLS | Dintor finds the bundled matching Zig standard library without a full compiler |
| Package management | pacman, Shelly, paru and Topgrade use Artix configuration and remain user-invoked |
| Firewall/process monitoring | Gufw, Qps and OpenSnitch are discoverable; services remain disabled until configured |
| DinitUI | service discovery and control use validated dinitctl argv with scoped pkexec fallback |
| Gaming | hidden launcher retained, optional package group excluded from base, missing Gamescope/Steam fail before profile changes; real gaming remains unqualified |
| Failure isolation | unavailable optional helpers or D-Bus endpoints produce visible failure without shell-dependent startup |
| Keyboard access | primary actions work without pointer input |

## Release gates

`scripts/check_deetty_integration.sh`, `scripts/dintor_p3_qualification.sh`, `scripts/check_dinitui.sh`, `scripts/check_dinx_session.sh`, `scripts/check_dinx_display_persistence.sh`, `scripts/check_dinx_theme.sh`, `scripts/check_pori_phyto.sh`, `scripts/check_aqueous_pearl.sh` and `scripts/check-iso-content.sh` verify the package, session and ISO contracts. The P0 workflow remains the release gate for package creation, ISO assembly, QEMU boot, Calamares installation, recovery TTY, attestation and publication.
