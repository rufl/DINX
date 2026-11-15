# Upstream plan: cohesive Pearl/Aqueous application theming

Status: **planned, not submitted.** DINX currently ships downstream stopgaps
(patches, overlay scripts and profile templates) for the gaps below. This
document records the intended upstream changes to Pearl
(`Seafoam-Labs/pearl`) and Aqueous (`Seafoam-Labs/Aqueous`) so the stopgaps can
be retired once the upstream work lands. No upstream PR has been opened yet.

Related DINX pieces:

- `distro/packages/dinx-pearl-themes` — the four ported community themes
  (schema 2, matugen application profiles).
- `distro/packages/dinx-gtk-themes` — full GTK3/GTK4 themes with unified
  accents and rounded/square geometry.
- `distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-pearl-shell`
  — writes the theme selection, enables application profiles, sets
  `theme.sync_borders` and `window_corner_radius`.
- `distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-sync-session-theme`
  — applies `gtk-theme-name`, the generated qt6ct palette and the Deetty
  theme bridge at login.
- `distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/haruna` — selects
  the port's generated KDE color scheme.

## 1. Profile output names are hardcoded to `pearl-material`

Current: `src/theme/application_adapters.zig` `name()` returns fixed filenames
(`gtk-3.0/pearl-material.css`, `qt6ct/colors/pearl-material.conf`,
`color-schemes/pearl-material*.colors`, `ghostty/themes/pearl-material`, …)
regardless of the selected profile id. Two installed ports cannot export
side by side, and consumers must reference a name that says "material" even
when the colors come from Skeuos or Orchis.

DINX stopgap: consumers reference the fixed names; the KDE scheme *display
name* inside the `.colors` templates is per-port (`Skeuos Rounded (DINX)`),
which is what Haruna selects.

Upstream change: derive output names from the profile id (e.g.
`dinx.skeuos-rounded.conf`), keep `pearl-material` as an alias for the bundled
Material profiles, and teach `allowed()`/managed-path cleanup about the
derived names. Include a migration that removes stale fixed-name exports when
the selection changes.

## 2. kcolorscheme variant files are rendered with the active variant

Current: the three kcolorscheme templates use `{{colors.*.default.hex}}`, so
`pearl-material-dark.colors` contains light colors when the active variant is
light. The file suffix and its content disagree.

DINX stopgap: Haruna always selects the unsuffixed scheme (current variant),
and the fork templates give the suffixed files distinct display names.

Upstream change: render `-dark`/`-light` outputs with `{{colors.*.dark.hex}}`
and `{{colors.*.light.hex}}` respectively (matugen supports per-variant
placeholders), and make the unsuffixed file follow the active variant.

## 3. Window corner radius is startup-only; titlebar surfaces are not synced

Current: `preferences.window_corner_radius` (0–32, added by the DINX
`server-decorations.patch`) is read by Aqueous at session start only
(settings label says so). Border *colors* sync live when
`theme.sync_borders` is set and mode != gtk
(`src/ui/surfaces/manager.zig`), but the SSD titlebar surface color is not
part of that sync, and Aqueous exposes only `border_focused/normal/urgent`
plus layout geometry in `aqueous/wm/config/layout.zig`.

DINX stopgap: the wizard/wrapper writes `window_corner_radius` per selection
(Skeuos 8, Orchis 12, Material 15, square 0) and `sync_borders: true`; users
re-login for radius changes.

Upstream change:
- Pearl: push `window_corner_radius` through the existing Aqueous config
  transaction so it hot-reloads like border colors.
- Aqueous: accept titlebar surface/foreground colors in the same appearance
  update (extend the layout/wm config keys and the border-sync protocol),
  and apply the corner radius to SSD frames live.
- Upstream the `window_corner_radius` preference and the settings row from
  `distro/packages/pearl/server-decorations.patch` as-is.

## 4. Terminal adapter assumes the `ghostty` config namespace

Current: the ghostty adapter writes `~/.config/ghostty/themes/pearl-material`
and instructs `theme = pearl-material`. Deetty (a Ghostty fork renamed by
`distro/packages/deetty/product-identity.patch`, `.name = "deetty"`) reads
`~/.config/deetty`, so the generated theme never reaches it.

DINX stopgap: `dinx-sync-session-theme` symlinks
`~/.config/deetty/themes/pearl-material` at the ghostty export and sets
`theme = pearl-material` in `~/.config/deetty/config`.

Upstream change: let adapters declare a config-namespace override (profile
descriptor field, e.g. `config_namespace: "deetty"`), or detect installed
Ghostty-family binaries and export to each namespace. Keep the symlink bridge
working during migration.

## 5. Two Qt appearance paths (qt6ct vs QtEngine/Darkly)

Current: the qt5ct/qt6ct adapters export color schemes and their instructions
say Pearl's managed Qt applications use QtEngine + Darkly instead
(`application_adapters.zig` instructions; `qt_integration.reconcile` in
`src/config/service.zig`). DINX does not ship qtengine; it drives qt6ct
`custom_palette` from the sync script, and Haruna needs its own KColorScheme
because it re-applies a scheme after Qt starts.

DINX stopgap: package mode points qt6ct `color_scheme_path` at the generated
`pearl-material.conf` with `custom_palette=true` for both variants; the
Haruna wrapper selects the port scheme by display name.

Upstream change: document one supported Qt path per distribution profile, or
make QtEngine consume the same generated palette so qt6ct, KColorScheme and
QtEngine cannot disagree. Expose a "Haruna-style" hook: a stable scheme name
that applications can follow without hardcoding Material.

## 6. GTK named-color overrides coexist with full GTK themes

Current: the gtk adapter appends Pearl-owned `@define-color` imports to the
user `gtk.css` (GTK 3/4). When a distribution also sets `gtk-theme-name` to a
full theme (DINX does for the ports), libadwaita apps see the overrides while
plain GTK apps see the full theme; radii and derived shades can disagree.

DINX stopgap: the fork gtk templates add explicit rounded/square shape rules
(`window.csd`, `headerbar`, `button`, `entry`, `.card`) matching the selected
GTK theme, and `dinx-gtk-themes` substitutes the port palette primary over the
raw upstream accent hex so accents match exactly.

Upstream change: add a profile/adapter mode for "full theme selected" that
skips the named-color import (or emits shape-only overrides), and a contract
for palette-to-GTK-theme generation so a community theme can ship a complete
GTK theme derived from its palette instead of hex substitution.

## 7. Suggested PR sequence

1. Pearl: variant-pinned kcolorscheme rendering (small, testable via
   `tests/integration/test_theme_packages.py`).
2. Pearl: id-derived adapter output names + migration.
3. Pearl: adapter config-namespace override (Deetty).
4. Pearl + Aqueous: live `window_corner_radius` and titlebar color sync;
   upstream the `server-decorations.patch` preference.
5. Pearl: full-theme GTK mode / palette-driven GTK generation.
6. Docs: one Qt path contract.

Each PR should keep the fixed `pearl-material` names and the symlink bridge
working until DINX retires its stopgaps in a coordinated release.