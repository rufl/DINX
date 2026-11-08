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
session_launcher="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-pearl"
terminal_wrapper="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-terminal"
terminal_fallback="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/dinx-terminal-fallback.desktop"
source_env="$repo_root/distro/packages/deetty/source.env"
pkgbuild="$repo_root/distro/packages/deetty/PKGBUILD"
archive="$repo_root/distro/packages/deetty/deetty-0.1.0.tar.gz"
exec_patch="$repo_root/distro/packages/deetty/deetty-terminal-exec.patch"
identity_patch="$repo_root/distro/packages/deetty/product-identity.patch"
qualification_patch="$repo_root/distro/packages/deetty/qualification-compat.patch"

for path in "$profile" "$groups" "$fish_profile" "$shell_profile" "$session_launcher" \
  "$source_env" "$pkgbuild" "$archive" "$exec_patch" "$identity_patch" "$qualification_patch"; do
  [[ -r "$path" ]] || fail "missing file: $path"
done
[[ $(stat -c '%a' "$archive") == 644 ]] \
  || fail 'Deetty source archive must be readable by non-root build steps'

grep -Fqx '    - deetty' "$profile" || fail 'profile does not install Deetty'
grep -Fqx '    - ghostty-vt-runtime' "$profile" || fail 'profile does not install the VT-only runtime'
jq -e '.groups.desktop.packages | index("deetty") != null and index("ghostty-vt-runtime") != null and index("zls") != null' "$groups" >/dev/null \
  || fail 'desktop feature group does not include Deetty, its VT-only runtime, and ZLS'
if jq -e 'any(.groups[].packages[]; . == "foot" or . == "ghostty")' "$groups" >/dev/null; then
  fail 'feature groups include an alternative terminal application'
fi
if grep -Eq '^[[:space:]]+- (foot|ghostty|kitty|alacritty|konsole|xterm|xfce4-terminal|gnome-terminal|wezterm|tilix)([[:space:]]|$)' "$profile"; then
  fail 'profile installs an alternative terminal emulator'
fi
if [[ -e "$terminal_wrapper" || -e "$terminal_fallback" ]]; then
  fail 'retired terminal fallback wrapper or launcher remains'
fi
for package in dialog fzf glances less libnewt man-db nano openssh procps-ng sqlite texinfo tmux; do
  grep -Fqx "    - $package" "$profile" || fail "profile does not install $package"
done
grep -Fqx '    - zls' "$profile" || fail 'profile does not install the Zig language server'
if grep -Eq '^[[:space:]]+- (clang|vim)([[:space:]]|$)' "$profile"; then
  fail 'profile installs build-only clang or Vim'
fi
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
grep -Fq "optdepends=('zls: Zig language server for Dintor' 'clang: optional C/C++ language server via clangd')" "$pkgbuild" \
  || fail 'optional Zig and C/C++ language server dependencies are not documented'
grep -Fq "'git'" "$pkgbuild" || fail 'Git runtime dependency is missing'
grep -Fq 'Git Status and Diff...' "$repo_root/distro/packages/deetty/qualification-compat.patch" || fail 'Dintor Git action is missing'
grep -Fq 'DINTOR_THEME' "$repo_root/distro/packages/deetty/qualification-compat.patch" || fail 'Dintor color scheme contract is missing'
grep -Fq 'deetty-terminal-exec.patch' "$pkgbuild" || fail 'Deetty execute-argv patch is not part of the package'
grep -Fq 'patch --fuzz=0 --forward --strip=1 < "$srcdir/deetty-terminal-exec.patch"' "$pkgbuild" \
  || fail 'Deetty execute-argv patch is not applied without fuzz'
exec_patch_sha=$(sha256sum "$exec_patch" | cut -d ' ' -f 1)
grep -Fq "'$exec_patch_sha'" "$pkgbuild" || fail 'Deetty execute-argv patch checksum is not pinned'
identity_patch_sha=$(sha256sum "$identity_patch" | cut -d ' ' -f 1)
grep -Fq "'$identity_patch_sha'" "$pkgbuild" || fail 'Deetty product identity patch checksum is not pinned'
grep -Fq 'patch --fuzz=0 --forward --strip=1 < "$srcdir/qualification-compat.patch"' "$pkgbuild" \
  || fail 'Deetty qualification patch is not applied without fuzz'
qualification_patch_sha=$(sha256sum "$qualification_patch" | cut -d ' ' -f 1)
grep -Fq "'$qualification_patch_sha'" "$pkgbuild" \
  || fail 'Deetty qualification patch checksum is not pinned'

shell_output=$(env -i HOME=/tmp PATH="$PATH" bash -c '. "$1"; printf "TERMINAL=%s EDITOR=%s VISUAL=%s XDG_CURRENT_DESKTOP=%s\n" "$TERMINAL" "$EDITOR" "$VISUAL" "$XDG_CURRENT_DESKTOP"' bash "$shell_profile")
printf '%s\n' "$shell_output"
grep -Fqx 'TERMINAL=deetty EDITOR=dintor VISUAL=dintor XDG_CURRENT_DESKTOP=Aqueous' <<<"$shell_output" || fail 'shell defaults are not deterministic'


scratch=$(mktemp -d "${TMPDIR:-/tmp}/dinx-deetty-integration.XXXXXX")
cleanup() {
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

tar -tzf "$archive" | grep -Fx 'deetty-0.1.0/resources/com.noctty.NOCTTY.desktop' >/dev/null || fail 'pinned upstream terminal desktop entry is missing'
tar -tzf "$archive" | grep -Fx 'deetty-0.1.0/resources/nocttyhere.desktop' >/dev/null || fail 'pinned upstream service menu is missing'
tar -tzf "$archive" | grep -Fx 'deetty-0.1.0/resources/nocted/styles/nocted-dark.xml' >/dev/null || fail 'pinned upstream Dintor source scheme is missing'
upstream_dintor_desktop=$(tar -xOf "$archive" deetty-0.1.0/resources/com.noctty.NoctEd.desktop)
grep -Fqx 'Exec=nocted %F' <<<"$upstream_dintor_desktop" || fail 'pinned upstream editor entry is missing'
upstream_desktop=$(tar -xOf "$archive" deetty-0.1.0/resources/com.noctty.NOCTTY.desktop)
grep -Fqx 'TryExec=noctty' <<<"$upstream_desktop" || fail 'pinned upstream terminal entry is missing'
grep -Fqx 'Exec=noctty --open-uri %u' <<<"$upstream_desktop" || fail 'upstream terminal URI entry is missing'
grep -Fqx 'Categories=System;TerminalEmulator;' <<<"$upstream_desktop" || fail 'terminal desktop category is missing'
service_menu=$(tar -xOf "$archive" deetty-0.1.0/resources/nocttyhere.desktop)

patched_source="$scratch/patched-source"
mkdir -p "$patched_source"
tar -xzf "$archive" -C "$patched_source" --strip-components=1
patch --fuzz=0 --forward --strip=1 --directory="$patched_source" < "$identity_patch"
patch --fuzz=0 --forward --strip=1 --directory="$patched_source" < "$repo_root/distro/packages/deetty/qualification-compat.patch"
patch --fuzz=0 --forward --strip=1 --directory="$patched_source" < "$exec_patch"
grep -Fq 'DEETTY_DEDICATED_DISPLAY' "$patched_source/scripts/nocted_native_smoke.sh" \
  || fail 'Deetty isolated-display environment name was not patched'
grep -Fq 'DEETTY_ISOLATED_DISPLAY' "$patched_source/scripts/require_isolated_display.sh" \
  || fail 'Deetty display boundary environment name was not patched'
if grep -Eq 'NOCTTY_(DEDICATED|ISOLATED)_DISPLAY' \
  "$patched_source/scripts/nocted_native_smoke.sh" "$patched_source/scripts/require_isolated_display.sh"; then
  fail 'Deetty display scripts still use legacy NOCTTY environment names'
fi
grep -Fq 'DEETTY_DEDICATED_DISPLAY=1' "$repo_root/scripts/dintor_p3_qualification.sh" \
  || fail 'Dintor qualification does not use the Deetty display contract'
grep -Fq 'DEETTY_ISOLATED_DISPLAY=x11' "$repo_root/scripts/dintor_p3_qualification.sh" \
  || fail 'Dintor qualification does not use the Deetty display isolation contract'
grep -Fq 'std.mem.eql(u8, cmd, "--execute")' "$patched_source/src/main.zig" || fail 'Deetty -e/--execute option is missing'
grep -Fq 'quoteCommandArguments(args[2..]' "$patched_source/src/main.zig" || fail 'Deetty does not preserve command argv safely'
grep -Fq 'terminal execute argv are safely quoted and bounded' "$patched_source/src/terminal/LaunchProfile.zig" || fail 'Deetty execute argv boundary test is missing'
grep -Fq '.name = "deetty"' "$patched_source/build.zig" || fail 'Deetty executable identity was not patched'
grep -Fq '.name = "dintor"' "$patched_source/build.zig" || fail 'Dintor executable identity was not patched'
grep -Fq 'share/applications/org.dinx.Deetty.desktop' "$patched_source/build.zig" || fail 'Deetty desktop output path is missing'
grep -Fq 'share/applications/org.dinx.Dintor.desktop' "$patched_source/build.zig" || fail 'Dintor desktop output path is missing'
grep -Fq 'share/kio/servicemenus/deettyhere.desktop' "$patched_source/build.zig" || fail 'Deetty service-menu output path is missing'
task_smoke="$patched_source/scripts/nocted_task_smoke.sh"
grep -Fq './zig-out/bin/dintor' "$task_smoke" || fail 'Dintor task smoke uses the old executable path'
if grep -Fq './zig-out/bin/nocted' "$task_smoke"; then
  fail 'Dintor task smoke still references the old executable'
fi
lsp_smoke="$patched_source/scripts/nocted_lsp_smoke.sh"
grep -Fq './zig-out/bin/dintor --lsp-probe' "$lsp_smoke" || fail 'Dintor LSP smoke uses the old executable path'
if grep -Fq './zig-out/bin/nocted' "$lsp_smoke"; then
  fail 'Dintor LSP smoke still references the old executable'
fi
patched_desktop=$(<"$patched_source/resources/com.noctty.NOCTTY.desktop")
grep -Fqx 'Name=Deetty' <<<"$patched_desktop" || fail 'Deetty desktop name is incorrect'
grep -Fqx 'TryExec=deetty' <<<"$patched_desktop" || fail 'Deetty desktop command is incorrect'
grep -Fqx 'Exec=deetty --open-uri %u' <<<"$patched_desktop" || fail 'Deetty URI handler is incorrect'
grep -Fqx 'Icon=org.dinx.Deetty' <<<"$patched_desktop" || fail 'Deetty desktop icon identity is incorrect'
grep -Fqx 'MimeType=x-scheme-handler/deetty;' <<<"$patched_desktop" || fail 'Deetty URI scheme declaration is incorrect'
patched_editor_desktop=$(<"$patched_source/resources/com.noctty.NoctEd.desktop")
grep -Fqx 'Name=Editor' <<<"$patched_editor_desktop" || fail 'Dintor desktop name is incorrect'
grep -Fqx 'Name[pt_BR]=Editor' <<<"$patched_editor_desktop" || fail 'Dintor Portuguese desktop name is incorrect'
grep -Fqx 'Exec=dintor %F' <<<"$patched_editor_desktop" || fail 'Dintor file opening contract is missing'
grep -Fqx 'Icon=org.dinx.Dintor' <<<"$patched_editor_desktop" || fail 'Dintor icon identity is incorrect'
patched_service_menu=$(<"$patched_source/resources/nocttyhere.desktop")
grep -Fqx 'Exec=deetty --new-window --working-directory %f' <<<"$patched_service_menu" || fail 'Deetty service-menu command is incorrect'
grep -Fq '<id>org.dinx.Deetty</id>' "$patched_source/resources/com.noctty.NOCTTY.metainfo.xml" || fail 'Deetty metainfo ID is incorrect'
grep -Fq '<id>org.dinx.Dintor</id>' "$patched_source/resources/com.noctty.NoctEd.metainfo.xml" || fail 'Dintor metainfo ID is incorrect'
grep -Fq '<binary>dintor</binary>' "$patched_source/resources/com.noctty.NoctEd.metainfo.xml" || fail 'Dintor metainfo binary is incorrect'
grep -Fq 'style-scheme id="dintor-dark"' "$patched_source/resources/nocted/styles/nocted-dark.xml" || fail 'Dintor dark scheme identity is incorrect'
grep -Fq 'style-scheme id="dintor-light"' "$patched_source/resources/nocted/styles/nocted-light.xml" || fail 'Dintor light scheme identity is incorrect'
grep -Fq '"DINTOR_THEME"' "$patched_source/src/nocted/main.zig" || fail 'Dintor theme environment is missing'
grep -Fq '"deetty://"' "$patched_source/src/workspace/Activation.zig" || fail 'Deetty workspace URI scheme is missing'
printf 'deetty_dintor_integration terminal=deetty sole_terminal=true ghostty_runtime_only=true lsp=zig:zls clangd=optional vim=builder-only shell_defaults=true wm_spawn=true execute_argv=true file_open=true desktop_ids=true service_menu=true metainfo=true editor_styles=true uri_scheme=true patches_apply=true upstream_pin_preserved=true\n'
