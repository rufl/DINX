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
The shipped session contract is the `DINX` Noctalia palette at `~/.config/noctalia/palettes/DINX.json`. It defines dark/light semantic roles and the complete terminal ANSI palette; Noctalia is configured with `source = "custom"`, `sync_color_scheme = true`, and the built-in `btop`, `foot`, `ghostty`, GTK 3/4, KDE, Mango and Qt templates.

GTK applications use the installed `DINX` fallback theme until Noctalia applies its generated CSS. Qt applications use `qt6ct` with Noctalia's generated `~/.config/qt6ct/colors/noctalia.conf`; Mango consumes the generated `~/.config/mango/noctalia.conf`. Swayimg receives a DINX overlay/gallery fallback in `~/.config/swayimg/init.lua`. The session exports the documented `NOCTALIA_COLOR_SCHEME`, `NOCTED_THEME`, `QT_QPA_PLATFORMTHEME`, `XCURSOR_THEME` and `XCURSOR_SIZE` defaults.

ReGreet and Calamares consume static DINX bridges because they run before or outside the shell. GRUB uses the same surface/text/primary tokens with its opaque menu textures disabled. `scripts/check_dinx_theme.sh` validates the palette, template set, package inputs and every bridge before the ISO build; `check-iso-content.sh` repeats the payload checks inside SquashFS.

## DinitUI service-manager contract

DinitUI is the DINX frontend for dinit, not a systemd compatibility layer. It discovers loaded services through `dinitctl list` and description files in the system/user Dinit directories, including Dinit's native nested list framing. Its control catalog covers lifecycle, boot dependencies, runtime dependencies, environment, buffered logs, signals and daemon shutdown. `scripts/check_dinitui.sh` covers the package boundary; the real-daemon qualification proves a temporary user daemon through the GTK smoke path.
The UI passes validated argv tokens directly to `dinitctl`; it never invokes a shell. User scope uses `dinitctl --user`. System scope first tries `dinitctl --system` and uses `pkexec` only after an explicit authorization failure. The ISO payload contract checks the executable, desktop entry, icon, standalone gaming launcher, Wayland session, Gamescope and Steam.



DINX's Noctalia/Mango desktop contract is explicit:

- Mango's tag rule opens new windows floating; `Super+Space` toggles the focused window back to tiled/floating state.
- the Noctalia bar named `main` is reserved at the top and the application dock is reserved at the bottom;
- NetworkManager, BlueZ, UPower and PipeWire back the Noctalia network, Bluetooth, battery and volume widgets;
- Noctalia owns the screenshot and clipboard surfaces; `wl-copy`/`wl-paste` remain a CLI complement, while `grim`/`slurp` are not duplicated.

The standalone `nm-connection-editor`, Blueman, pwvucontrol, VLC and Strawberry applications remain available from the Noctalia dock/launcher for full connection, Bluetooth, per-stream audio, video and music-library workflows.
Gufw, Qps and the OpenSnitch UI remain available from the dock/launcher; UFW and OpenSnitch dinit services are installed but not boot-enabled, so firewall rules require deliberate configuration. Do not enable both rule managers without reviewing the resulting netfilter ruleset.
The package-management tools `topgrade`, `paru`, and Shelly remain launcher/CLI complements: topgrade uses DINX's pinned release binary and Artix `pacman` configuration, paru is built from pinned source against Artix ALPM, and Shelly delegates to Artix's `pacman` configuration. Their packages contain no `systemd` dependencies or units, add no Arch repositories, are not started by Noctalia or the boot session, and AUR recipes require explicit user review.
AMD Cyan Skillfish/BC-250 support is a payload contract: Artix AMDGPU firmware, Mesa RADV, Vulkan diagnostics and the pinned SMU governor are installed. The dinit service auto-starts only the governor path for PCI `1002:13fe`; it uses the 1000-1850 MHz safe range and exits on other hardware without a systemd unit.
BC250 Control Center v1.21.1 is the BC-250 launcher/monitor contract: its pinned MIT package provides a desktop entry, CLI, polkit policy and headless daemon. The daemon starts once from the Mango user session, not through systemd or a root dinit service; DINX removes the upstream systemd unit and Cyan drop-in. dinit remains a live/read-only service-persistence boundary in the upstream app, so failure to inspect a persistent service must not block application startup or live telemetry.

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
| Application templates | btop, Foot, Ghostty, GTK 3/4, KDE, Mango and Qt consume the generated Noctalia outputs; Swayimg uses the DINX overlay fallback |
| Greeter/installer/boot | ReGreet, Calamares and GRUB expose DINX surface, text, selection and focus states |
| Firefox default | Firefox is the default HTML/XHTML/HTTP/HTTPS handler |
| Firefox pro-user policy | `policies.json` parses and disables sponsored surfaces, Pocket/Stories, telemetry, recommendations, AI assistant surfaces and built-in IP Protection while keeping updates enabled |
| Desktop layout | Mango opens new windows floating; Noctalia reserves the top bar and bottom dock |
| Shell utilities | Noctalia provides screenshot/clipboard UI; `wl-clipboard` provides CLI copy/paste |
| Media handlers | VLC owns common video MIME entries; Strawberry owns common audio MIME entries |
| Package management | `topgrade`, `paru`, and Shelly use Artix's ALPM/pacman configuration, have no `systemd` dependency/unit, add no Arch repositories, and remain available for explicit user-invoked updates |
| BC250 Control Center | v1.21.1 GUI/CLI/daemon, Noctalia dock entry, Mango user-session autostart, pinned source, and no systemd payload; live telemetry remains available when dinit persistence inspection is unsupported |
| Firewall/process monitoring | Gufw, Qps, and OpenSnitch are discoverable; UFW/OpenSnitch services remain disabled until explicit configuration |
| Fallback | applications remain usable when Noctalia is absent |
| IPC failure | unavailable or malformed optional IPC does not block startup |
| Keyboard access | primary actions work without pointer input |
| DinitUI service control | loaded/file-discovered dinit services, status, lifecycle, dependencies, environment, logs, signals and shutdown use validated `dinitctl` argv with scoped `pkexec` fallback |
| Gaming session | standalone `dbus-run-session` Gamescope/Steam entry, 32-bit Mesa/RADV/Vulkan payload, fixture launch/exit and headless Gamescope child launch/exit |

## P2 Noctty release gate

The P2 gate combines `zig build test`, allocator-accounted PTY/session qualification, deterministic protocol/Unicode qualification, GLib fairness and large-paste qualification, the ReleaseSafe installed-TUI matrix, and `scripts/check_noctty_integration.sh`. The installed matrix exercises real Vim, nano, less, dialog, top, watch, whiptail, fzf, SQLite, Glances, Bash, man/less and local SFTP through the production PTY/VT path. It launches the installed `info` command first; minimal or non-TTY environments use a deterministic styled fixture fallback for the `info` surface. tmux/Zellij launch arguments use deterministic tool shims so the package gate remains headless.

The three-application Codex/Vim/btop runner uses a local Codex surface fixture in the DINX package gate. It proves the real Vim and btop cases without authentication, network access or a Codex product dependency; it is not authenticated Codex evidence.

Each supported Noctalia interface must identify the tested version and adapter version. Version changes require rerunning the compatibility matrix.

## P3 Nocted release gate

The P3 gate is `scripts/nocted_p3_qualification.sh`. It runs the deterministic Nocted core/index/worker/state/task qualifications, a real `clangd` LSP probe, native GTK/X11 smoke in dark and light modes, and a real Git fixture through the production `--git-probe` binary. The package gate invokes this script after `zig build -Doptimize=ReleaseSafe test`; `check_noctty_integration.sh` and `check-iso-content.sh` verify the package and ISO contracts.

The P0 workflow is the release gate for the resulting package and ISO. Run [38989297207](https://github.com/rufl/DINX/actions/runs/38989297207) passed package build, QEMU boot, persistent installation, recovery and attestation, closing the P3/P4 alpha release evidence. Future changes must pass the same gate before release evidence is refreshed.
