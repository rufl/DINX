# Octopi

Octopi is the pacman/AUR front-end shipped in the DINX desktop payload. Artix
packages neither Octopi nor its helper library, so this recipe builds both from
pinned upstream sources and retargets privilege escalation at polkit.

## Elevation: pkexec, not sudo

DINX ships no sudo, and upstream Octopi 0.19.0 can only escalate through
`qt-sudo`, whose backends are `su`, `sudo` and `doas`. `octopi-pkexec.patch`
therefore replaces every escalation site with the polkit authorization client
(`pkexec`); the DINX session already runs `lxqt-policykit-agent`, which answers
the authentication prompt, so no second dialog is shipped and the recipe has no
`qt-sudo` (or sudo) dependency at all.

Because `pkexec` clears the child environment on purpose, the session handles
that privileged children still need are carried across explicitly through
`pkexec env ...`, the same bridge used by `dinx-gparted` and `dinx-installer`:
`WAYLAND_DISPLAY`, `DBUS_SESSION_BUS_ADDRESS`, `XDG_RUNTIME_DIR`,
`XDG_SESSION_TYPE`, `GDK_BACKEND` (plus `DISPLAY`/`XAUTHORITY`,
`QT_QPA_PLATFORM`, `XDG_CURRENT_DESKTOP`), and the `C.UTF-8` locale plus
`COLUMNS=132`, because Octopi parses English pacman output at a fixed width.
Pure file-mutation sites (`pkexec /bin/sh -c ...`, the installer pattern) need
no GUI or shared-memory child and elevate with plain `pkexec`.

The patch also removes the four `qt-sudo` abort gates (main application,
notifier, cache cleaner, repository editor) and replaces them with a `pkexec`
availability check, and drops the obsolete `qt-sudo` message from the
translation sources; `prepare()` regenerates the compiled catalogues with
`lrelease6` because Octopi embeds them from the source tree.

No polkit policy file is installed: every privileged launch goes through
`/bin/sh`, `/usr/lib/octopi/octphelper` or a text editor, all of which are
generic `org.freedesktop.policykit.exec` users, and DINX deliberately does not
ship a rule that authorizes a shell as root without a prompt.

## External inputs

Two upstream tarballs are downloaded, both pinned by SHA-256 in `source.env`
and both refreshable:

* `OCTOPI_SOURCE_URL` — the tagged GitHub archive `v$OCTOPI_VERSION`, matching
  the `.github/package-updates.json` github provider template.
* `alpm_octopi_utils` — Octopi's Vala ALPM helper library. The upstream
  repository publishes no tags or releases, so it is pinned by commit
  (`OCTOPI_ALPM_UTILS_COMMIT`, the revision the upstream Arch recipe uses) and
  fetched as `archive/<commit>.tar.gz`. Bumps are manual by design; the pin is a
  full commit SHA-256-verified tarball, never a floating ref.

The helper library is not available in Artix, so it is built inside this recipe
and its `libalpm_octopi_utils.so` SONAME is shipped by `octopi` itself.

## Installed payload

`/usr/bin/octopi`, `/usr/lib/octopi/octphelper`, `libalpm_octopi_utils.so`,
`/usr/bin/octopi-cachecleaner`, `/usr/bin/octopi-repoeditor`, their desktop
entries, icons, embedded translations and the upstream GPL-2.0-or-later
license.

`octopi-notifier` is built but deliberately **not** installed: it is a
StatusNotifierItem tray daemon, and the DINX river session has no SNI host, so
it would run invisibly with no way to interact with it. DINXPanel owns upgrade
reporting on this desktop.

## Build requirements

`cmake`, `ninja`, `qt6-tools` (for `lrelease6` and the Qt Linguist CMake
components), `qt6-5compat`, `vala` (the helper library is written in Vala),
plus the Qt6 runtime libraries, `qtermwidget`, `pacman`, `pacman-contrib`
(`checkupdates`) and `polkit` (`pkexec`). AUR support is optional and provided
by `paru`.
