#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
pkgbuild="$root/distro/packages/ghostty-vt-runtime/PKGBUILD"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
workflow="$root/.github/workflows/p0-iso.yml"

fail() {
  printf 'ghostty_vt_runtime_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$profile" "$groups" "$workflow"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done

grep -Fqx 'pkgname=ghostty-vt-runtime' "$pkgbuild" || fail 'package name is not ghostty-vt-runtime'
grep -Fqx 'source=()' "$pkgbuild" || fail 'runtime package must be staged from the installed build dependency'
grep -Fq "makedepends=('ghostty')" "$pkgbuild" || fail 'full Ghostty is not declared as a build-only extraction dependency'
grep -Fq "conflicts=('ghostty')" "$pkgbuild" || fail 'runtime package does not prevent coexistence with the full terminal'
grep -Fq 'cp -a "$library" "$pkgdir/usr/lib/"' "$pkgbuild" || fail 'VT shared library is not staged into the runtime package'
grep -Fq 'cp -a /usr/include/ghostty "$pkgdir/usr/include/"' "$pkgbuild" || fail 'VT headers are not staged into the runtime package'
grep -Fq 'usr/share/licenses/ghostty/LICENSE' "$pkgbuild" || fail 'upstream license is not staged'
if grep -Eq 'install[^#]*(/usr/bin/ghostty|/usr/share/applications/.*[Gg]hostty)|cp[^#]*(/usr/bin/ghostty|/usr/share/applications/.*[Gg]hostty)' "$pkgbuild"; then
  fail 'runtime package recipe stages a Ghostty application or desktop launcher'
fi

grep -Fqx '    - deetty' "$profile" || fail 'ISO profile does not install Deetty'
grep -Fqx '    - ghostty-vt-runtime' "$profile" || fail 'ISO profile does not install the VT-only runtime'
jq -e '.groups.desktop.packages | index("deetty") != null and index("ghostty-vt-runtime") != null' "$groups" >/dev/null \
  || fail 'desktop feature group does not include Deetty and the VT-only runtime'
if jq -e 'any(.groups[].packages[]; . == "foot" or . == "ghostty")' "$groups" >/dev/null; then
  fail 'feature groups install an alternative terminal application'
fi
if grep -Eq '^[[:space:]]+- (foot|ghostty|kitty|alacritty|konsole|xterm|xfce4-terminal|gnome-terminal|wezterm|tilix)([[:space:]]|$)' "$profile"; then
  fail 'ISO profile installs an alternative terminal emulator'
fi

for required in \
  'scripts/check_ghostty_vt_runtime.sh' \
  'build_package ghostty-vt-runtime' \
  'pacman -Rdd --noconfirm ghostty' \
  'pacman -U --noconfirm "$ghostty_vt_package"' \
  'scripts/check_ghostty_vt_runtime.sh "$ghostty_vt_package"'; do
  grep -Fq -- "$required" "$workflow" || fail "workflow is missing runtime-package wiring: $required"
done
runtime_build_line=$(grep -nF 'build_package ghostty-vt-runtime' "$workflow" | cut -d: -f1)
remove_ghostty_line=$(grep -nF 'pacman -Rdd --noconfirm ghostty' "$workflow" | cut -d: -f1)
install_runtime_line=$(grep -nF 'pacman -U --noconfirm "$ghostty_vt_package"' "$workflow" | cut -d: -f1)
deetty_build_line=$(grep -nF 'build_package deetty' "$workflow" | cut -d: -f1)
dinxpanel_build_line=$(grep -nF 'build_package dinxpanel' "$workflow" | cut -d: -f1)
[[ -n "$runtime_build_line" && -n "$remove_ghostty_line" && -n "$install_runtime_line" && -n "$deetty_build_line" && -n "$dinxpanel_build_line" ]] \
  || fail 'workflow package ordering markers are incomplete'
(( runtime_build_line < remove_ghostty_line && remove_ghostty_line < install_runtime_line \
  && install_runtime_line < deetty_build_line && deetty_build_line < dinxpanel_build_line )) \
  || fail 'Ghostty runtime must replace the full app before Deetty and dependent desktop packages are built'
grep -Fq '                ghostty \' "$workflow" || fail 'builder does not install the full Ghostty build-only extraction source'

if [[ $# -gt 1 ]]; then
  fail 'usage: check_ghostty_vt_runtime.sh [PACKAGE]'
fi
if [[ $# -eq 1 ]]; then
  package=$1
  [[ -f "$package" ]] || fail "package archive not found: $package"
  command -v bsdtar >/dev/null 2>&1 || fail 'bsdtar is required to inspect a built package archive'
  package_contents=$(bsdtar -tf "$package") || fail 'cannot list the runtime package archive'
  for required in \
    usr/lib/libghostty-vt.so.0 \
    usr/include/ghostty/vt.h \
    usr/share/licenses/ghostty-vt-runtime/LICENSE; do
    grep -Fqx "$required" <<<"$package_contents" || fail "package archive is missing $required"
  done
  if grep -Eq '(^|/)usr/bin/ghostty$|(^|/)usr/share/applications/.*[Gg]hostty.*\.desktop$' <<<"$package_contents"; then
    fail 'package archive contains the Ghostty terminal executable or desktop launcher'
  fi
  package_info=$(bsdtar -xOf "$package" .PKGINFO) || fail 'cannot read package metadata'
  grep -Fqx 'pkgname = ghostty-vt-runtime' <<<"$package_info" || fail 'built package metadata name is incorrect'
  if grep -Fqx 'depend = ghostty' <<<"$package_info"; then
    fail 'built runtime package depends on the full Ghostty terminal'
  fi
fi

printf 'ghostty_vt_runtime_contract staged=true library=true headers=true license=true full_app_builder_only=true app_removed_before_iso=true deetty_before_dependents=true archive_checked=%s\n' \
  "$([[ $# -eq 1 ]] && printf true || printf false)"
