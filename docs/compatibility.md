# Noctalia compatibility contract

DINX applications complement Noctalia and must not depend on undocumented Noctalia internals. Compatibility is layered so the applications remain useful without the shell.

## Level 1 — drop-in integration

Required for the first usable application releases:

- Noctty is discoverable as a terminal and works through `$TERMINAL`.
- Noctty accepts the expected terminal-launch arguments, including a working directory where supported.
- Nocted has a valid `.desktop` entry and appears in the Noctalia launcher.
- Nocted supports normal desktop file opening and file/line arguments where implemented.
- Both applications follow standard keyboard navigation and XDG locations.

## Level 2 — visual integration

The applications consume a documented Dinx Theme format or adapter:

- light/dark mode;
- accent, background, foreground and selection colors;
- terminal ANSI palette;
- application font and icon choices where the platform exposes them.

The theme format is an external contract. Applications must not parse private Noctalia configuration files as if they were stable APIs. Theme reload behavior must be explicit: either a documented watch path or a user-visible reload action.

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
| Fallback | applications remain usable when Noctalia is absent |
| IPC failure | unavailable or malformed optional IPC does not block startup |
| Keyboard access | primary actions work without pointer input |

Each supported Noctalia interface must identify the tested version and adapter version. Version changes require rerunning the compatibility matrix.
