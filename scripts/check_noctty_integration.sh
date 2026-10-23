#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
terminal_wrapper="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-terminal"
shell_profile="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/profile.d/dinx.sh"
source_env="$repo_root/distro/packages/noctty/source.env"
pkgbuild="$repo_root/distro/packages/noctty/PKGBUILD"
archive="$repo_root/distro/packages/noctty/noctty-0.1.0.tar.gz"

fail() {
  printf 'check_noctty_integration: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$terminal_wrapper" "$shell_profile" "$source_env" "$pkgbuild" "$archive"; do
  [[ -r "$path" ]] || fail "missing file: $path"
done

grep -Fqx '    - noctty' "$profile" || fail 'profile does not install noctty'
grep -Fqx '    - foot' "$profile" || fail 'profile does not install foot fallback'
for package in dialog fzf glances less libnewt man-db nano openssh procps-ng sqlite texinfo tmux vim; do
  grep -Fqx "    - $package" "$profile" || fail "profile does not install $package"
done

grep -Fq 'if [ "${DINX_TERMINAL_FALLBACK:-0}" = 1 ]; then' "$terminal_wrapper" || fail 'fallback switch is missing'
grep -Fq 'exec foot "$@"' "$terminal_wrapper" || fail 'foot fallback does not preserve argv'
grep -Fq 'exec noctty "$@"' "$terminal_wrapper" || fail 'Noctty launch does not preserve argv'
grep -Fq 'export TERMINAL="${TERMINAL:-dinx-terminal}"' "$shell_profile" || fail 'TERMINAL default is missing'
grep -Fq 'export EDITOR="${EDITOR:-nocted}"' "$shell_profile" || fail 'EDITOR default is missing'
grep -Fq 'export VISUAL="${VISUAL:-$EDITOR}"' "$shell_profile" || fail 'VISUAL default is missing'
grep -Fq "makedepends=('vte3'" "$pkgbuild" || fail 'vte3 package build dependency is missing'
grep -Fq "depends=('clang'" "$pkgbuild" || fail 'clangd runtime dependency is missing'
grep -Fq "'git'" "$pkgbuild" || fail 'Git runtime dependency is missing'
grep -Fqx '    - clang' "$profile" || fail 'profile does not install clangd'
grep -Fq 'Git Status and Diff...' "$repo_root/distro/packages/noctty/qualification-compat.patch" || fail 'NoctEd Git action is missing'
grep -Fq 'NOCTALIA_COLOR_SCHEME' "$repo_root/distro/packages/noctty/qualification-compat.patch" || fail 'Noctalia color scheme contract is missing'
grep -Fq "'ghostty'" "$pkgbuild" || fail 'ghostty runtime dependency is missing'

scratch=$(mktemp -d "${TMPDIR:-/tmp}/dinx-noctty-integration.XXXXXX")
cleanup() {
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$scratch/bin"
cat >"$scratch/bin/noctty" <<'SHIM'
#!/bin/sh
printf 'selected=noctty argc=%s argv=%s\n' "$#" "$*"
SHIM
cat >"$scratch/bin/foot" <<'SHIM'
#!/bin/sh
printf 'selected=foot argc=%s argv=%s\n' "$#" "$*"
SHIM
chmod +x "$scratch/bin/noctty" "$scratch/bin/foot"

normal_output=$(PATH="$scratch/bin:$PATH" "$terminal_wrapper" --working-directory /tmp)
printf '%s\n' "$normal_output"
grep -Fq 'selected=noctty argc=2 argv=--working-directory /tmp' <<<"$normal_output" || fail 'default terminal did not select Noctty or preserve argv'
fallback_output=$(PATH="$scratch/bin:$PATH" DINX_TERMINAL_FALLBACK=1 "$terminal_wrapper" --working-directory /tmp)
printf '%s\n' "$fallback_output"
grep -Fq 'selected=foot argc=2 argv=--working-directory /tmp' <<<"$fallback_output" || fail 'explicit fallback did not select Foot or preserve argv'

shell_output=$(env -i HOME=/tmp PATH="$PATH" bash -c '. "$1"; printf "TERMINAL=%s EDITOR=%s VISUAL=%s XDG_CURRENT_DESKTOP=%s\n" "$TERMINAL" "$EDITOR" "$VISUAL" "$XDG_CURRENT_DESKTOP"' bash "$shell_profile")
printf '%s\n' "$shell_output"
grep -Fqx 'TERMINAL=dinx-terminal EDITOR=nocted VISUAL=nocted XDG_CURRENT_DESKTOP=Labwc' <<<"$shell_output" || fail 'shell defaults are not deterministic'

tar -tzf "$archive" | grep -Fx 'noctty-0.1.0/resources/com.noctty.NOCTTY.desktop' >/dev/null || fail 'Noctty desktop entry is not packaged'
tar -tzf "$archive" | grep -Fx 'noctty-0.1.0/resources/nocttyhere.desktop' >/dev/null || fail 'Open Here service menu is not packaged'
tar -tzf "$archive" | grep -Fx 'noctty-0.1.0/resources/noctalia/noctalia-v5-widget.toml' >/dev/null || fail 'Noctalia widget resource is not packaged'
tar -tzf "$archive" | grep -Fx 'noctty-0.1.0/resources/nocted/styles/nocted-dark.xml' >/dev/null || fail 'NoctEd dark scheme is not packaged in source'
nocted_desktop=$(tar -xOf "$archive" noctty-0.1.0/resources/com.noctty.NoctEd.desktop)
grep -Fqx 'Exec=nocted %F' <<<"$nocted_desktop" || fail 'NoctEd file opening contract is missing'
grep -Fqx 'Icon=com.noctty.NoctEd' <<<"$nocted_desktop" || fail 'NoctEd icon contract is missing'
desktop=$(tar -xOf "$archive" noctty-0.1.0/resources/com.noctty.NOCTTY.desktop)
grep -Fqx 'TryExec=noctty' <<<"$desktop" || fail 'Noctty desktop TryExec is missing'
grep -Fqx 'Exec=noctty --open-uri %u' <<<"$desktop" || fail 'Noctty desktop URI launch is missing'
grep -Fqx 'Categories=System;TerminalEmulator;' <<<"$desktop" || fail 'Noctty desktop category is missing'
service_menu=$(tar -xOf "$archive" noctty-0.1.0/resources/nocttyhere.desktop)
grep -Fqx 'Exec=noctty --new-window --working-directory %f' <<<"$service_menu" || fail 'Open Here working-directory launch is missing'
noctalia=$(tar -xOf "$archive" noctty-0.1.0/resources/noctalia/noctalia-v5-widget.toml)
grep -Fqx 'left = "exec noctty --toggle"' <<<"$noctalia" || fail 'Noctalia toggle action is missing'
grep -Fqx 'right = "exec noctty --show"' <<<"$noctalia" || fail 'Noctalia show action is missing'

printf 'noctty_integration_contract terminal_discovery=true fallback=true shell_defaults=true nocted_file_open=true nocted_icon=true desktop=true working_directory=true noctalia=true package_runtime=true\n'
