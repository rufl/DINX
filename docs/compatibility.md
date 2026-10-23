# Noctalia compatibility contract

[English](compatibility.md) · [Português (Brasil)](pt-BR/compatibility.md)

DINX applications complement Noctalia and must not depend on undocumented Noctalia internals. Compatibility is layered so the applications remain useful without the shell.

## Level 1 — drop-in integration

Required for the first usable application releases:

- Noctty is discoverable as a terminal and works through `$TERMINAL`.
- Noctty accepts the expected terminal-launch arguments, including a working directory where supported.
- Nocted has a valid `.desktop` entry and appears in the Noctalia launcher.
- Nocted supports normal desktop file opening and file/line arguments where implemented.
- Both applications follow standard keyboard navigation and XDG locations.
- Firefox is discoverable as the default HTML, XHTML and HTTP/HTTPS handler.

## Level 2 — visual integration

The applications consume a documented Dinx Theme format or adapter:

- light/dark mode;
- accent, background, foreground and selection colors;
- terminal ANSI palette;
- application font and icon choices where the platform exposes them.

Nocted's adapter contract is intentionally small: `NOCTALIA_COLOR_SCHEME=light` or `NOCTED_THEME=prefer-light` selects the packaged `nocted-light` scheme; all other values use `nocted-dark`. The editor does not parse private Noctalia files, and it remains usable when neither variable nor Noctalia is present.

The P3 compatibility gate exercises both schemes through the native GTK smoke path, checks the NoctEd `.desktop` file-opening contract, and runs the real `clangd` LSP probe. A Git repository is optional; when present, the Tools action reports bounded status and unified diff output with per-file markers.
Firefox is shipped with `/etc/firefox/policies/policies.json`. The policy removes sponsored New Tab/Suggest surfaces, Pocket/Stories, Firefox Studies and telemetry, browser recommendations, AI assistant/link-preview/tab-group surfaces and built-in IP Protection. Firefox Accounts remains opt-in and user-controlled; normal browser updates stay enabled.
The shipped session contract is the `DINX` Noctalia palette at `~/.config/noctalia/palettes/DINX.json`. It defines dark/light semantic roles and the complete terminal ANSI palette; Noctalia is configured with `source = "custom"`, `sync_color_scheme = true`, and the built-in `btop`, `foot`, `ghostty`, GTK 3/4, KDE and Qt templates.

GTK applications use the installed `DINX` fallback theme until Noctalia applies its generated CSS. Qt applications use `qt6ct` with Noctalia's generated `~/.config/qt6ct/colors/noctalia.conf`; labwc reads `/etc/xdg/labwc` and merges user overrides from `~/.config/labwc/rc.xml`. Swayimg receives a DINX overlay/gallery fallback in `~/.config/swayimg/init.lua`. The session exports the documented `NOCTALIA_COLOR_SCHEME`, `NOCTED_THEME`, `QT_QPA_PLATFORMTHEME`, `XCURSOR_THEME` and `XCURSOR_SIZE` defaults.

GUI-facing bridges use Cantarell 11, square control geometry, the DINX semantic surface/control/hover/primary states and Adwaita icons where the platform exposes them. ReGreet and Calamares consume static DINX bridges because they run before or outside the shell. GRUB uses the same surface/text/primary tokens with its opaque menu textures disabled. The main Noctalia bar includes a StatusNotifier tray drawer, and the profile ships `libayatana-appindicator` so legacy indicator applications have a compatible bridge. `scripts/check_dinx_theme.sh` validates the palette, template set, package inputs, typography, states and every bridge before the ISO build; `check-iso-content.sh` repeats the payload checks inside SquashFS.

The remaining differences are intentional platform boundaries: Qt keeps Fusion as its style backend and Monospace 10 for fixed-width fields; DinitUI and DINXPanel keep monospace log views; GRUB keeps `u_vga16 16` for early-boot asset compatibility. These exceptions do not replace the DINX colors or the Cantarell 11 GUI contract.

## DinitUI service-manager contract

DinitUI is the DINX frontend for dinit, not a systemd compatibility layer. It discovers loaded services through `dinitctl list` and description files in the system/user Dinit directories, including Dinit's native nested list framing. Its control catalog covers lifecycle, boot dependencies, runtime dependencies, environment, buffered logs, signals and daemon shutdown. `scripts/check_dinitui.sh` covers the package boundary; the real-daemon qualification proves a temporary user daemon through the GTK smoke path.
The UI passes validated argv tokens directly to `dinitctl`; it never invokes a shell. User scope uses `dinitctl --user`. System scope first tries `dinitctl --system` and uses `pkexec` only after an explicit authorization failure. The ISO payload contract checks the executable, desktop entry, icon, standalone gaming launcher, Wayland session, Gamescope and Steam.

The profile contract adds `normal`, `lite`, `gaming` and user-defined system-service policies. DinitUI persists them at `~/.config/dinx/dinitui/profiles.conf`; `lite` disables only optional `bluetoothd`, while `gaming` enables `bluetoothd` for controllers and leaves Bluetooth, UFW, and OpenSnitch policy services available. It never disables network security or essential network/audio/login/display services. The local Noctalia `dinx/performance` plugin exposes a Control Center Gaming shortcut and profile panel, invokes `dinitui` through direct argv, and maps Gaming to Noctalia's `performance` power profile. The standalone Gamescope session remains independent because it does not start Noctalia.

The DINXPanel control-center workflow owns the visible GPU actions: it delegates the fixed `--gpu-status` and `--install-gpu-drivers` backend contract to DinitUI, and offers fixed shortcuts for NetworkManager, Bluetooth, display, audio, firewall, labwc options, Dinit services, package upgrades and firmware. `Check upgrades` uses `shelly sync`, `shelly list-updates all`, `fwupdmgr refresh` and `fwupdmgr get-updates` without installing; Topgrade preview uses `--dry-run --show-skipped`, while the explicit Topgrade and Shelly actions remain user-confirmed terminal workflows. Its kernel installer exposes only `linux`, `linux-lts`, `linux-zen` and `linux-hardened` with matching headers, installs through direct argv, never removes packages, protects the running kernel and requires a reboot.



DINX's labwc/Noctalia desktop contract is explicit:

- labwc provides a stacking Wayland session; its checked-in configuration keeps two workspaces and `Super+Return` launches `dinx-terminal`;
- the Noctalia bar named `main` is reserved at the top and the application dock is reserved at the bottom;
- NetworkManager, BlueZ, UPower and PipeWire back the Noctalia network, Bluetooth, battery and volume widgets;
- Noctalia owns the screenshot and clipboard surfaces; `wl-copy`/`wl-paste` remain a CLI complement, while `grim`/`slurp` are not duplicated.
- the main bar includes a StatusNotifier tray drawer; `libayatana-appindicator` keeps legacy indicator applications visible through the same surface;

The Noctalia dock is intentionally limited to primary DINX surfaces: Firefox, DINXPanel, DinitUI, BC250 Control Center, Phyto, Pori, Foot, Noctty and NoctEd. Specialist tools remain discoverable through the launcher and retain their desktop entries: `nm-connection-editor`, Blueman, pwvucontrol, Gufw, Qps, OpenSnitch, Shelly, Swayimg, KolourPaint, VLC, Strawberry, `wdisplays` and `shikane`; optional Dome and Seafoam Settings are exposed the same way when their Seafoam packages are installed. ZLS remains an editor backend rather than a launcher surface.

`wdisplays` is the interactive display editor through DINX's `dinx-wdisplays` wrapper. Closing the editor atomically replaces the DINX-owned `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads Shikane; the daemon starts with labwc and reapplies matching profiles on output changes. Seafoam Settings groups fixed entry points for the wrapper, profile saver, Shikane, labwc, DinitUI, DINXPanel, Qt6ct and Dome without adding a second settings backend. Dome's resource/process monitoring is dinit-safe, while its optional systemd service provider is intentionally unavailable. Nocted uses optional ZLS 0.16.0 for Zig LSP operations when installed.

Aqueous/Pearl não são uma sessão DINX suportada nesta etapa. O upstream exige `uwsm`/systemd para o ciclo de vida do usuário, enquanto a DINX mantém dinit como limite de init; uma futura integração precisa substituir essa superfície por um launcher e serviços dinit nativos antes de ganhar uma entrada no greeter. O `dinx-doctor` registra esse limite e diferencia pacote ausente de sessão suportada, sem executar nenhuma ação de mutação.


Noctalia's session widget remains the power surface. DINX also provides `Super+L`, a `Lock screen` launcher action, and DINXPanel buttons for locking and 5-percent brightness steps. `swayidle` locks after 10 minutes and invokes the same lock action through `before-sleep`, so suspend is preceded by a lock attempt. `brightnessctl` is bound to the standard hardware brightness keys when the compositor exposes them.
The package-management roles are deliberately separate: `pacman` owns the official Artix system transaction; Shelly owns explicit package/AUR metadata and upgrade workflows; `paru` is the advanced AUR helper; Topgrade orchestrates previews and user-confirmed updates; DINXPanel is the visible discovery/report surface and never installs during a check. No tool starts automatically, and AUR recipes require explicit review.
AMD Cyan Skillfish/BC-250 support is a payload contract: Artix AMDGPU firmware, Mesa RADV, Vulkan diagnostics and the pinned SMU governor are installed. The dinit service auto-starts only the governor path for PCI `1002:13fe`; it uses the 1000-1850 MHz safe range and exits on other hardware without a systemd unit.
BC250 Control Center v1.21.1 is the BC-250 launcher/monitor contract: its pinned MIT package provides a desktop entry, CLI, polkit policy and headless daemon. The daemon starts once from the labwc user session through `/etc/xdg/labwc/autostart`, not through systemd or a root dinit service; DINX removes the upstream systemd unit and Cyan drop-in. dinit remains a live/read-only service-persistence boundary in the upstream app, so failure to inspect a persistent service must not block application startup or live telemetry.

## Level 3 — deeper integration

Optional features may use documented Noctalia interfaces:

- launcher actions opening Nocted at a file and line;
- launcher actions opening Noctty in a chosen working directory;
- notifications and application actions;
- optional plugins exposing editor projects, recent files or terminal profiles.

Failure of an optional integration must not prevent the application from launching or editing files.

## Compatibility test matrix

The test suite should cover observable contracts rather than implementation details:

| Area | Acceptance check |
| --- | --- |
| Terminal discovery | `$TERMINAL` launches Noctty with a shell and requested directory |
| Desktop metadata | `.desktop` entries are valid and discoverable |
| Launch arguments | file, line and working-directory behavior is deterministic |
| Theme import | a documented theme fixture produces the expected semantic colors |
| Theme change | a supported update path changes the application without data loss |
| DINX palette | both Noctalia palette variants contain all semantic roles and ANSI terminal colors |
| Application templates | btop, Foot, Ghostty, GTK 3/4, KDE and Qt consume the generated Noctalia outputs; labwc consumes the checked-in compositor configuration; Swayimg uses the DINX overlay fallback |
| Greeter/installer/boot | ReGreet, Calamares and GRUB expose DINX surface, text, selection and focus states |
| Firefox default | Firefox is the default HTML/XHTML/HTTP/HTTPS handler |
| Firefox pro-user policy | `policies.json` parses and disables sponsored surfaces, Pocket/Stories, telemetry, recommendations, AI assistant surfaces and built-in IP Protection while keeping updates enabled |
| Desktop layout | labwc provides stacking windows; Noctalia reserves the top bar and bottom dock |
| Session safety | `swayidle` locks after 600 seconds, `before-sleep` invokes the lock wrapper, `Super+L` and the launcher entry invoke `swaylock`, and hardware brightness keys use `brightnessctl` |
| Payload budget | `scripts/check_dinx_budget.sh` enforces the committed rootfs package and dinit startup ceilings, the 120-second QEMU boot window, native binary size, and a 4 GiB ISO ceiling when an ISO path is supplied; `scripts/measure_dinx_session.sh` reports process RSS/CPU snapshots without treating an absent host session as proof |
| Shell utilities | Noctalia provides screenshot/clipboard UI; `wl-clipboard` provides CLI copy/paste |
| Media and image path | `ffmpeg`, VLC, VA-API (`libva`/`vainfo`), SANE `scanimage`, KolourPaint, and common video/audio/image MIME handlers are shipped; actual hardware decode and scanner hardware remain physical qualification claims |
| Package management | `topgrade`, `paru`, and Shelly use Artix's ALPM/pacman configuration, have no `systemd` dependency/unit, add no Arch repositories, and remain available for explicit user-invoked updates |
| BC250 Control Center | v1.21.1 GUI/CLI/daemon, Noctalia dock entry, labwc user-session autostart, pinned source, and no systemd payload; live telemetry remains available when dinit persistence inspection is unsupported |
| Firewall/process monitoring | Gufw, Qps, and OpenSnitch are discoverable; UFW/OpenSnitch services remain disabled until explicit configuration |
| Fallback | applications remain usable when Noctalia is absent |
| IPC failure | unavailable or malformed optional IPC does not block startup |
| Keyboard access | primary actions work without pointer input |
| DinitUI service control | loaded/file-discovered dinit services, status, lifecycle, dependencies, environment, logs, signals and shutdown use validated `dinitctl` argv with scoped `pkexec` fallback |
| DINXPanel maintenance control | fixed hardware/control-panel shortcuts, delegated GPU status/install actions, Shelly/Topgrade package-update workflows, optional fwupd firmware discovery, fixed Artix kernel catalog, direct argv execution, and install-only kernel safety |
| Gaming session | standalone `dbus-run-session` Gamescope/Steam entry, 32-bit Mesa/RADV/Vulkan payload, fixture launch/exit and headless Gamescope child launch/exit |

## P2 Noctty release gate

The P2 gate combines `zig build test`, allocator-accounted PTY/session qualification, deterministic protocol/Unicode qualification, GLib fairness and large-paste qualification, the ReleaseSafe installed-TUI matrix, and `scripts/check_noctty_integration.sh`. The installed matrix exercises real Vim, nano, less, dialog, top, watch, whiptail, fzf, SQLite, Glances, Bash, man/less and local SFTP through the production PTY/VT path. It launches the installed `info` command first; minimal or non-TTY environments use a deterministic styled fixture fallback for the `info` surface. tmux/Zellij launch arguments use deterministic tool shims so the package gate remains headless.

The three-application Codex/Vim/btop runner uses a local Codex surface fixture in the DINX package gate. It proves the real Vim and btop cases without authentication, network access or a Codex product dependency; it is not authenticated Codex evidence.

Each supported Noctalia interface must identify the tested version and adapter version. Version changes require rerunning the compatibility matrix.

## P3 Nocted release gate

The P3 gate is `scripts/nocted_p3_qualification.sh`. It runs the deterministic Nocted core/index/worker/state/task qualifications, a real `clangd` LSP probe, native GTK/X11 smoke in dark and light modes, and a real Git fixture through the production `--git-probe` binary. The package gate invokes this script after `zig build -Doptimize=ReleaseSafe test`; `check_noctty_integration.sh` and `check-iso-content.sh` verify the package and ISO contracts.

The P0 workflow is the release gate for the resulting package and ISO. Tagged run [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024) on commit `eea66ac` passed package build, QEMU boot, graphical payload validation, the Calamares partition contract and BIOS/UEFI/Btrfs transaction smoke, disposable BIOS and UEFI installation/first boot/recovery, build-metadata verification, persistent package signing, release attestation and publication of the Alpha 8 assets. Future changes must pass the same gate before release evidence is refreshed.
