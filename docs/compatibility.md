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

The theme format is an external contract. Applications must not parse private Noctalia configuration files as if they were stable APIs. Theme reload behavior must be explicit: either a documented watch path or a user-visible reload action.
Firefox is shipped with `/etc/firefox/policies/policies.json`. The policy removes sponsored New Tab/Suggest surfaces, Pocket/Stories, Firefox Studies and telemetry, browser recommendations, AI assistant/link-preview/tab-group surfaces and built-in IP Protection. Firefox Accounts remains opt-in and user-controlled; normal browser updates stay enabled.


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

## P2 Noctty release gate

The P2 gate combines `zig build test`, allocator-accounted PTY/session qualification, deterministic protocol/Unicode qualification, GLib fairness and large-paste qualification, the ReleaseSafe installed-TUI matrix, and `scripts/check_noctty_integration.sh`. The installed matrix exercises real Vim, nano, less, dialog, top, watch, whiptail, fzf, SQLite, Glances, Bash, man/less and local SFTP through the production PTY/VT path. It launches the installed `info` command first; minimal or non-TTY environments use a deterministic styled fixture fallback for the `info` surface. tmux/Zellij launch arguments use deterministic tool shims so the package gate remains headless.

The three-application Codex/Vim/btop runner uses a local Codex surface fixture in the DINX package gate. It proves the real Vim and btop cases without authentication, network access or a Codex product dependency; it is not authenticated Codex evidence.

Each supported Noctalia interface must identify the tested version and adapter version. Version changes require rerunning the compatibility matrix.
