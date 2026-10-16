# DinitUI

DinitUI is the DINX-native desktop frontend for the Dinit service manager.

## Design contract

- GTK4 and libadwaita, chosen instead of a Qt/QML bridge to keep the Zig build and runtime dependency graph small.
- DINX/Noctalia colors: `#0b0d12`, `#11151d`, `#d7dde8`, `#7f8a9c`, `#8fb8ff`, `#9ece6a`, `#f7768e`.
- Keyboard-first native controls, visible focus, no color-only state signal, and compact service-dashboard density.

## Control model

DinitUI invokes `dinitctl` with argv-safe arguments. It never shells service names through `/bin/sh`. System-scope actions first use the current user's `dinitctl --system` access and retry through `pkexec` only for an explicit authorization failure. User-scope actions use `dinitctl --user`.

The action catalog covers Dinit's control surface: start, stop, restart, reload, enable/disable (including an optional `--from` service), wake, release, unpin, unload, trigger/untrigger, `is-started`, `is-failed`, dependency add/remove, environment set/unset, buffered logs, signal delivery/listing, and shutdown. Service lists combine loaded units from `dinitctl list` with description files in the standard system or user directories.

The selected service is the target for service actions and the `from-service` for dependency actions. The extra-arguments field accepts whitespace-separated safe tokens such as `need target-service` or `PATH=/usr/bin`; it does not parse shell syntax or execute arbitrary commands.
`Shutdown Dinit` requires the literal extra token `CONFIRM` to prevent an accidental daemon/system shutdown.
