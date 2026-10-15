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
- Pale Moon is discoverable as the default HTML and HTTP/HTTPS handler.

## Level 2 — visual integration

The applications consume a documented Dinx Theme format or adapter:

- light/dark mode;
- accent, background, foreground and selection colors;
- terminal ANSI palette;
- application font and icon choices where the platform exposes them.

The theme format is an external contract. Applications must not parse private Noctalia configuration files as if they were stable APIs. Theme reload behavior must be explicit: either a documented watch path or a user-visible reload action.

Pale Moon uses the documented Noctalia v5 app-template interface rather than parsing private shell configuration:

- `palemoon-userChrome.css` maps Noctalia semantic surface, foreground, accent, hover and outline tokens to the browser chrome;
- `palemoon-userContent.css` applies the same tokens to Pale Moon's built-in blank/home/new-tab surfaces;
- Noctalia renders both files into the seeded DINX profile under the standard Pale Moon profile path;
- a dark fallback ships in the profile, so Pale Moon remains usable when Noctalia is absent;
- a palette or mode change is applied on the next Pale Moon restart. Noctalia does not forcibly restart the browser.

DINX's Noctalia/Mango desktop contract is explicit:

- Mango's tag rule opens new windows floating; `Super+Space` toggles the focused window back to tiled/floating state.
- the Noctalia bar named `main` is reserved at the top and the application dock is reserved at the bottom;
- NetworkManager, BlueZ, UPower and PipeWire back the Noctalia network, Bluetooth, battery and volume widgets;
- Noctalia owns the screenshot and clipboard surfaces; `wl-copy`/`wl-paste` remain a CLI complement, while `grim`/`slurp` are not duplicated.

The standalone `nm-connection-editor`, Blueman, pwvucontrol, VLC and Strawberry applications remain available from the Noctalia dock/launcher for full connection, Bluetooth, per-stream audio, video and music-library workflows.
Gufw, Qps and the OpenSnitch UI remain available from the dock/launcher; UFW and OpenSnitch dinit services are installed but not boot-enabled, so firewall rules require deliberate configuration. Do not enable both rule managers without reviewing the resulting netfilter ruleset.
The package-management tools `topgrade`, `paru`, and Shelly remain launcher/CLI complements: they use Artix's ALPM/pacman configuration, are built without `systemd` dependencies or units, add no Arch repositories, are not started by Noctalia or the boot session, and AUR recipes require explicit user review.
AMD Cyan Skillfish/BC-250 support is a payload contract: Artix AMDGPU firmware, Mesa RADV, Vulkan diagnostics and the pinned SMU governor are installed. The dinit service auto-starts only the governor path for PCI `1002:13fe`; it uses the 1000-1850 MHz safe range and exits on other hardware without a systemd unit.

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
| Pale Moon theme | Noctalia v5 renders the active semantic palette into `userChrome.css` and `userContent.css` |
| Pale Moon reload | the generated skin is visible after the next Pale Moon restart |
| Desktop layout | Mango opens new windows floating; Noctalia reserves the top bar and bottom dock |
| Shell utilities | Noctalia provides screenshot/clipboard UI; `wl-clipboard` provides CLI copy/paste |
| Media handlers | VLC owns common video MIME entries; Strawberry owns common audio MIME entries |
| Package management | `topgrade`, `paru`, and Shelly use Artix's ALPM/pacman configuration, have no `systemd` dependency/unit, add no Arch repositories, and remain available for explicit user-invoked updates |
| Cyan Skillfish hardware | AMDGPU firmware, Mesa RADV, Vulkan diagnostics and the dinit governor path for PCI `1002:13fe` are present; no systemd governor unit is installed |
| Firewall/process monitoring | Gufw, Qps, and OpenSnitch are discoverable; UFW/OpenSnitch services remain disabled until explicit configuration |
| Fallback | applications remain usable when Noctalia is absent |
| IPC failure | unavailable or malformed optional IPC does not block startup |
| Keyboard access | primary actions work without pointer input |

Each supported Noctalia interface must identify the tested version and adapter version. Version changes require rerunning the compatibility matrix.
