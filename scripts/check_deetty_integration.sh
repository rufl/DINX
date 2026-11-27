#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'check_deetty_integration: %s\n' "$*" >&2
  exit 1
}
repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json"
fish_profile="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/fish/config.fish"
shell_profile="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/profile.d/dinx.sh"
session_launcher="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-river-session"
terminal_wrapper="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-terminal"
terminal_fallback="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/dinx-terminal-fallback.desktop"
source_env="$repo_root/distro/packages/deetty/source.env"
pkgbuild="$repo_root/distro/packages/deetty/PKGBUILD"
archive="$repo_root/distro/packages/deetty/deetty-0.1.0.tar.gz"
launcher="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/deetty"
btop_launcher="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/btop"
nvtop_launcher="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/nvtop"

for path in "$profile" "$groups" "$fish_profile" "$shell_profile" "$session_launcher" \
  "$launcher" "$btop_launcher" "$nvtop_launcher" \
  "$source_env" "$pkgbuild" "$archive"; do
  [[ -r "$path" ]] || fail "missing file: $path"
done
[[ $(stat -c '%a' "$archive") == 644 ]] \
  || fail 'Deetty source archive must be readable by non-root build steps'

for path in "$launcher" "$btop_launcher" "$nvtop_launcher"; do
  [[ -x "$path" ]] || fail "terminal launcher is not executable: $path"
  sh -n "$path" || fail "terminal launcher has invalid shell syntax: $path"
done
grep -Fq 'export SHELL=/bin/fish' "$launcher" || fail 'Deetty wrapper does not force Fish'
grep -Fq 'export NOCTTY_DESKTOP_SHELL=/bin/fish' "$launcher" || fail 'Deetty wrapper does not identify Fish to Deetty'
grep -Fq -- '--dropdown' "$launcher" || fail 'Deetty wrapper lacks dropdown mode selection'
grep -Fq -- '--windowed' "$launcher" || fail 'Deetty wrapper lacks windowed mode selection'
grep -Fq -- '--zen-fullscreen' "$launcher" || fail 'Deetty wrapper lacks zen fullscreen selection'
[[ $(grep -Fc 'exec /usr/bin/deetty --new-window' "$launcher") -ge 3 ]] \
  || fail 'Deetty command launcher does not consistently request focused independent windows'
grep -Fqx 'exec /usr/local/bin/deetty -e btop "$@"' "$btop_launcher" \
  || fail 'btop does not launch through the Deetty command wrapper'
grep -Fqx 'exec /usr/local/bin/deetty -e nvtop "$@"' "$nvtop_launcher" \
  || fail 'nvtop does not launch through the Deetty command wrapper'
jq -e '.groups.desktop.packages | index("deetty") != null and index("ghostty-vt-runtime") != null' "$groups" >/dev/null \
  || fail 'desktop feature group does not include Deetty or its VT runtime'
if jq -e 'any(.groups[].packages[]; . == "foot" or . == "ghostty")' "$groups" >/dev/null; then
  fail 'feature groups include an alternative terminal application'
fi
if grep -Eq '^[[:space:]]+- (foot|ghostty|kitty|alacritty|konsole|xterm|xfce4-terminal|gnome-terminal|wezterm|tilix)([[:space:]]|$)' "$profile"; then
  fail 'profile installs an alternative terminal emulator'
fi
if [[ -e "$terminal_wrapper" || -e "$terminal_fallback" ]]; then
  fail 'retired terminal fallback wrapper or launcher remains'
fi
# glances is deliberately absent: it is a build/qualification-only input (deetty's
# makedepends and the P2 TUI qualification resolve it from the builder image, see
# scripts/iso-builder/packages.txt), not a shipped ISO package.
for package in dialog fzf less libnewt nano openssh procps-ng sqlite tmux; do
  grep -Fqx "    - $package" "$profile" || fail "profile does not install $package"
done
builder_packages="$repo_root/scripts/iso-builder/packages.txt"
[[ -r "$builder_packages" ]] || fail "builder package manifest is missing: $builder_packages"
grep -Fqx 'glances' "$builder_packages" \
  || fail 'builder image does not provide glances for the Deetty TUI qualification'
if grep -Fqx '    - glances' "$profile"; then
  fail 'glances is a builder-only qualification input and must not ship in the ISO'
fi
if grep -Eq '^[[:space:]]+- (man-db|man-pages|texinfo)([[:space:]]|$)' "$profile"; then
  fail 'profile installs removed documentation packages'
fi
if jq -e 'any(.groups[].packages[]; . == "man-db" or . == "man-pages" or . == "texinfo")' "$groups" >/dev/null; then
  fail 'feature groups include removed documentation packages'
fi
grep -Fq 'set -gx TERMINAL deetty' "$fish_profile" || fail 'Fish TERMINAL default is missing'
if jq -e 'any(.groups[].packages[]; . == "clang" or . == "vim")' "$groups" >/dev/null; then
  fail 'feature groups install build-only clang or Vim'
fi
grep -Fq 'set -gx TERMINAL deetty' "$fish_profile" || fail 'Fish TERMINAL default is missing'
grep -Fq 'export TERMINAL="${TERMINAL:-deetty}"' "$shell_profile" || fail 'POSIX TERMINAL default is missing'
grep -Fq 'export TERMINAL="${TERMINAL:-deetty}"' "$session_launcher" || fail 'session TERMINAL default is missing'
grep -Fq 'export EDITOR="${EDITOR:-dintor}"' "$shell_profile" || fail 'EDITOR default is missing'
grep -Fq 'export VISUAL="${VISUAL:-$EDITOR}"' "$shell_profile" || fail 'VISUAL default is missing'
grep -Fq "makedepends=('ghostty-vt-runtime'" "$pkgbuild" || fail 'Deetty build does not use the isolated VT runtime'
grep -Fq "'ghostty-vt-runtime'" "$pkgbuild" || fail 'Deetty does not depend on the isolated VT runtime'
if grep -Fq "'ghostty'" "$pkgbuild"; then
  fail 'Deetty still depends on the Ghostty terminal application'
fi
grep -Fq "'vte3'" "$pkgbuild" || fail 'vte3 package build dependency is missing'
runtime_dependencies=$(awk -F= '$1 == "depends" { print; exit }' "$pkgbuild")
[[ "$runtime_dependencies" != *"'clang'"* ]] || fail 'clang must not be a hard Deetty runtime dependency'
build_dependencies=$(awk -F= '$1 == "makedepends" { print; exit }' "$pkgbuild")
[[ "$build_dependencies" == *"'clang'"* ]] || fail 'clangd protocol qualification build dependency is missing'
[[ "$build_dependencies" == *"'vim'"* ]] || fail 'Vim real-TUI qualification build dependency is missing'
grep -Fq "'git'" "$pkgbuild" || fail 'Git runtime dependency is missing'

shell_output=$(env -i HOME=/tmp PATH="$PATH" bash -c '. "$1"; printf "TERMINAL=%s EDITOR=%s VISUAL=%s XDG_CURRENT_DESKTOP=%s\n" "$TERMINAL" "$EDITOR" "$VISUAL" "$XDG_CURRENT_DESKTOP"' bash "$shell_profile")
printf '%s\n' "$shell_output"
grep -Fqx 'TERMINAL=deetty EDITOR=dintor VISUAL=dintor XDG_CURRENT_DESKTOP=river' <<<"$shell_output" || fail 'shell defaults are not deterministic'


scratch=$(mktemp -d "${TMPDIR:-/tmp}/dinx-deetty-integration.XXXXXX")
cleanup() {
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

# Upstream renamed its product files in commit 2b9aeb0 (com.noctty.* -> com.deetty.*,
# nocttyhere.desktop -> deettyhere.desktop). The pinned source now exposes the
# Dintor editor executable through the retained NoctEd desktop filename.
tar -tzf "$archive" | grep -Fx 'deetty-0.1.0/resources/com.deetty.DEETTY.desktop' >/dev/null || fail 'pinned upstream terminal desktop entry is missing'
tar -tzf "$archive" | grep -Fx 'deetty-0.1.0/resources/deettyhere.desktop' >/dev/null || fail 'pinned upstream service menu is missing'
tar -tzf "$archive" | grep -Fx 'deetty-0.1.0/resources/nocted/styles/nocted-dark.xml' >/dev/null || fail 'pinned upstream Dintor source scheme is missing'
if tar -tzf "$archive" | grep -Eq 'resources/(com\.noctty\.|nocttyhere)'; then
  fail 'pinned upstream source still ships retired noctty identity files'
fi
upstream_dintor_desktop=$(tar -xOf "$archive" deetty-0.1.0/resources/com.deetty.NoctEd.desktop)
grep -Fqx 'Exec=dintor %F' <<<"$upstream_dintor_desktop" || fail 'pinned upstream Dintor editor entry is missing'
upstream_desktop=$(tar -xOf "$archive" deetty-0.1.0/resources/com.deetty.DEETTY.desktop)
grep -Fqx 'TryExec=deetty' <<<"$upstream_desktop" || fail 'pinned upstream terminal entry is missing'
grep -Fqx 'Exec=deetty --open-uri %u' <<<"$upstream_desktop" || fail 'upstream terminal URI entry is missing'
grep -Fqx 'Categories=System;TerminalEmulator;' <<<"$upstream_desktop" || fail 'terminal desktop category is missing'
service_menu=$(tar -xOf "$archive" deetty-0.1.0/resources/deettyhere.desktop)

source_tree="$scratch/source-tree"
mkdir -p "$source_tree"
tar -xzf "$archive" -C "$source_tree" --strip-components=1
grep -Fq 'LC_ALL=C.UTF-8' "$source_tree/src/terminal/RealTuiQualification.zig" \
  || fail 'Deetty real-TUI environment does not override ASCII locales'
grep -Fq 'LC_ALL=C LANG=C TERM=xterm-256color' "$repo_root/scripts/deetty_p2_qualification.sh" \
  || fail 'Deetty real-TUI qualification does not exercise an ASCII parent locale'
grep -Fq 'DEETTY_DEDICATED_DISPLAY' "$source_tree/scripts/nocted_native_smoke.sh" \
  || fail 'Deetty isolated-display environment name is missing'
grep -Fq 'DEETTY_ISOLATED_DISPLAY' "$source_tree/scripts/require_isolated_display.sh" \
  || fail 'Deetty display boundary environment name is missing'
if grep -Eq 'NOCTTY_(DEDICATED|ISOLATED)_DISPLAY' \
  "$source_tree/scripts/nocted_native_smoke.sh" "$source_tree/scripts/require_isolated_display.sh"; then
  fail 'Deetty display scripts still use legacy NOCTTY environment names'
fi
grep -Fq 'DEETTY_DEDICATED_DISPLAY=1' "$repo_root/scripts/dintor_p3_qualification.sh" \
  || fail 'Dintor qualification does not use the Deetty display contract'
grep -Fq 'DEETTY_ISOLATED_DISPLAY=x11' "$repo_root/scripts/dintor_p3_qualification.sh" \
  || fail 'Dintor qualification does not use the Deetty display isolation contract'
grep -Fq 'Git Status and Diff...' "$source_tree/src/nocted/main.zig" || fail 'Dintor Git action is missing'
grep -Fq 'DINTOR_THEME' "$source_tree/src/nocted/main.zig" || fail 'Dintor color scheme contract is missing'
grep -Fq 'std.mem.eql(u8, cmd, "--execute")' "$source_tree/src/main.zig" || fail 'Deetty -e/--execute option is missing'
grep -Fq 'quoteCommandArguments(args[2..]' "$source_tree/src/main.zig" || fail 'Deetty does not preserve command argv safely'
grep -Fq 'terminal execute argv are safely quoted and bounded' "$source_tree/src/terminal/LaunchProfile.zig" || fail 'Deetty execute argv boundary test is missing'
grep -Fq '.name = "deetty"' "$source_tree/build.zig" || fail 'Deetty executable identity is missing'
grep -Fq '.name = "dintor"' "$source_tree/build.zig" || fail 'Dintor executable identity is missing'
grep -Fq 'share/applications/org.dinx.Deetty.desktop' "$source_tree/build.zig" || fail 'Deetty desktop output path is missing'
grep -Fq 'share/applications/org.dinx.Dintor.desktop' "$source_tree/build.zig" || fail 'Dintor desktop output path is missing'
grep -Fq 'share/kio/servicemenus/deettyhere.desktop' "$source_tree/build.zig" || fail 'Deetty service-menu output path is missing'
task_smoke="$source_tree/scripts/nocted_task_smoke.sh"
grep -Fq './zig-out/bin/dintor' "$task_smoke" || fail 'Dintor task smoke uses the old executable'
if grep -Fq './zig-out/bin/nocted' "$task_smoke"; then
  fail 'Dintor task smoke still references the old executable'
fi
lsp_smoke="$source_tree/scripts/nocted_lsp_smoke.sh"
grep -Fq './zig-out/bin/dintor --lsp-probe' "$lsp_smoke" || fail 'Dintor LSP smoke uses the old executable path'
if grep -Fq './zig-out/bin/nocted' "$lsp_smoke"; then
  fail 'Dintor LSP smoke still references the old executable'
fi
source_desktop=$(<"$source_tree/resources/com.deetty.DEETTY.desktop")
grep -Fqx 'Name=Deetty' <<<"$source_desktop" || fail 'Deetty desktop name is incorrect'
grep -Fqx 'TryExec=deetty' <<<"$source_desktop" || fail 'Deetty desktop command is incorrect'
grep -Fqx 'Exec=deetty --open-uri %u' <<<"$source_desktop" || fail 'Deetty URI handler is incorrect'
grep -Fqx 'Icon=org.dinx.Deetty' <<<"$source_desktop" || fail 'Deetty desktop icon identity is incorrect'
grep -Fqx 'MimeType=x-scheme-handler/deetty;' <<<"$source_desktop" || fail 'Deetty URI scheme declaration is incorrect'
editor_desktop=$(<"$source_tree/resources/com.deetty.NoctEd.desktop")
grep -Fqx 'Name=Editor' <<<"$editor_desktop" || fail 'Dintor desktop name is incorrect'
grep -Fqx 'Name[pt_BR]=Editor' <<<"$editor_desktop" || fail 'Dintor Portuguese desktop name is incorrect'
grep -Fqx 'Exec=dintor %F' <<<"$editor_desktop" || fail 'Dintor file opening contract is missing'
grep -Fqx 'Icon=org.dinx.Dintor' <<<"$editor_desktop" || fail 'Dintor icon identity is incorrect'
service_menu=$(<"$source_tree/resources/deettyhere.desktop")
grep -Fqx 'Exec=deetty --new-window --working-directory %f' <<<"$service_menu" || fail 'Deetty service-menu command is incorrect'
grep -Fq '<id>org.dinx.Deetty</id>' "$source_tree/resources/com.deetty.DEETTY.metainfo.xml" || fail 'Deetty metainfo ID is incorrect'
grep -Fq '<id>org.dinx.Dintor</id>' "$source_tree/resources/com.deetty.NoctEd.metainfo.xml" || fail 'Dintor metainfo ID is incorrect'
grep -Fq '<binary>dintor</binary>' "$source_tree/resources/com.deetty.NoctEd.metainfo.xml" || fail 'Dintor metainfo binary is incorrect'
grep -Fq 'style-scheme id="dintor-dark"' "$source_tree/resources/nocted/styles/nocted-dark.xml" || fail 'Dintor dark scheme identity is incorrect'
grep -Fq 'style-scheme id="dintor-light"' "$source_tree/resources/nocted/styles/nocted-light.xml" || fail 'Dintor light scheme identity is incorrect'
grep -Fq '"DINTOR_THEME"' "$source_tree/src/nocted/main.zig" || fail 'Dintor theme environment is missing'
printf 'deetty_dintor_integration terminal=deetty sole_terminal=true ghostty_runtime_only=true lsp=zig clangd=optional vim=builder-only shell_defaults=true wm_spawn=true execute_argv=true file_open=true desktop_ids=true service_menu=true metainfo=true editor_styles=true upstream_contract=true upstream_pin_preserved=true\n'
