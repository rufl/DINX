<!-- SPDX-FileCopyrightText: 2026 DINX Contributors -->
<!-- SPDX-License-Identifier: Apache-2.0 -->
# DINX First Run

`dinx-first-run` is the DINX desktop first-run setup wizard: one GTK4/libadwaita
window that collects language, location, appearance, bar and dock choices on the
first login and turns them into the per-user files the DINX session reads. The
session glue `/usr/local/libexec/dinx-desktop-first-run` starts it once per
account; `dinx-sync-session-theme` and the Calamares wrapper consume its output.

## Behavior

- The wizard runs once. `${XDG_STATE_HOME:-$HOME/.local/state}/dinx/desktop-first-run-complete`
  marks completion; when it exists the binary exits 0 without touching anything.
- Selections come from `$DINX_FIRST_RUN_PRESET` (an absolute path to a JSON file
  in the appearance schema) when it is set and readable; corrupt, relative or
  unreadable presets fall back to the interactive five-page wizard.
- Closing the window before Apply is a skip, not a cancel: unchanged defaults
  are written, the marker is still created, and the exit code is 0. First run
  never re-nags and never blocks the session; every failure path exits 0.
- Without a display the wizard writes the same defaults-plus-marker result.

## Outputs

All files are written atomically (temporary file plus rename, `chmod 600`,
parents `chmod 700`):

- `$XDG_CONFIG_HOME/dinx/appearance.json` — the fixed selection record consumed
  by `dinx-sync-session-theme`;
- `$XDG_CONFIG_HOME/dinx/installer-preferences.json` — the installer subset,
  created only when missing because Calamares reads it;
- `$XDG_CONFIG_HOME/morghulis/main.css` — five dock-safe shell lines; the GTK
  theme family itself belongs to `gtk-theme-name` and is applied by
  `dinx-sync-session-theme`.

Best-effort shell settings follow the selection: the Morghulis `navbar-anchor`
gsetting (only when the `com.arkye.morghulis` schema and key exist, so a missing
schema cannot crash the wizard), a `pkill -HUP dinx-dock` reload, and the
`prefer-dark`/`prefer-light` dconf color scheme when the `dconf` binary exists.

## CLI

```text
dinx-first-run --dry-run   # print the resolved appearance JSON, write nothing, exit 0
dinx-first-run --version   # print 0.1.0
```

The supported language values and generated locales are:

| Language | Locale | Keyboard | Default location |
| --- | --- | --- | --- |
| `en-US` | `en_US.UTF-8` | `us` | `America/New_York` |
| `pt-BR` | `pt_BR.UTF-8` | `br` | `America/Sao_Paulo` |
| `fr` | `fr_FR.UTF-8` | `fr` | `Europe/Paris` |
| `de` | `de_DE.UTF-8` | `de` | `Europe/Berlin` |
| `nl` | `nl_NL.UTF-8` | `nl` | `Europe/Amsterdam` |
| `da` | `da_DK.UTF-8` | `dk` | `Europe/Copenhagen` |
| `pt-PT` | `pt_PT.UTF-8` | `pt` | `Europe/Lisbon` |
| `es` | `es_ES.UTF-8` | `es` | `Europe/Madrid` |
| `it` | `it_IT.UTF-8` | `it` | `Europe/Rome` |
| `en-GB` | `en_GB.UTF-8` | `gb` | `Europe/London` |
| `uk` | `uk_UA.UTF-8` | `ua` | `Europe/Kyiv` |
| `ja` | `ja_JP.UTF-8` | `jp` | `Asia/Tokyo` |
| `zh-CN` | `zh_CN.UTF-8` | `cn` | `Asia/Shanghai` |
| `zh-TW` | `zh_TW.UTF-8` | `tw` | `Asia/Taipei` |

The location is independently selectable, so users can combine a supported
language with another supported timezone.

## Building

```sh
zig build -Dcpu=baseline -Doptimize=ReleaseSafe --prefix ./stage
```

Requires Zig 0.17, GTK 4 and libadwaita development headers.
