#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pkg_dir="$root/distro/packages/dinitui"
pkgbuild="$pkg_dir/PKGBUILD"
backend="$pkg_dir/src/dinit.zig"
frontend="$pkg_dir/src/main.zig"
desktop="$pkg_dir/resources/dinitui.desktop"
readme="$pkg_dir/README.md"
qualification="$root/scripts/dinitui_dinit_qualification.sh"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
workflow="$root/.github/workflows/p0-iso.yml"

fail() {
  printf 'check_dinitui: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$backend" "$frontend" "$desktop" "$readme" "$profile" "$workflow" "$qualification"; do
  [[ -r "$path" ]] || fail "missing $path"
done

grep -Fqx 'pkgname=dinitui' "$pkgbuild" || fail 'PKGBUILD package name is not dinitui'
grep -Fq 'depends=(dinit gtk4 libadwaita polkit)' "$pkgbuild" || fail 'runtime dependency contract is incomplete'
grep -Fq 'makedepends=(zig)' "$pkgbuild" || fail 'Zig build dependency is missing'
grep -Fq 'Exec=dinitui' "$desktop" || fail 'desktop launcher does not execute dinitui'
grep -Fq 'Icon=org.dinx.DinitUI' "$desktop" || fail 'desktop launcher icon is missing'
grep -Fq '    - dinitui' "$profile" || fail 'DINX profile does not install dinitui'
grep -Fq 'build_package dinitui' "$workflow" || fail 'ISO workflow does not build dinitui'
grep -Fq 'std.process.run' "$backend" || fail 'DinitUI does not use argv-safe process execution'
grep -Fq 'usr/share/licenses/dinitui/LICENSE' "$pkgbuild" || fail 'package license installation is missing'
grep -Fq 'gtk4' "$pkg_dir/build.zig" || fail 'GTK4 link contract is missing'
grep -Fq 'adwaita-1' "$pkg_dir/build.zig" || fail 'libadwaita link contract is missing'
for action in start stop restart reload enable disable wake release unpin unload trigger untrigger is-started is-failed add-dep rm-dep setenv unsetenv catlog signal shutdown; do
  grep -Fq "\"$action\"" "$backend" || fail "Dinit action is missing: $action"
done
grep -Fq 'CONFIRM' "$backend" || fail 'shutdown confirmation guard is missing'
if grep -Eq '/bin/sh|systemctl' "$backend" "$frontend"; then
  fail 'DinitUI source contains a forbidden shell/systemd execution path'
fi
grep -Fq 'GTK4 and libadwaita' "$readme" || fail 'toolkit decision is not documented'
grep -Fq 'argv-safe' "$readme" || fail 'privilege/input boundary is not documented'
grep -Fq 'dinitui_dinit_runtime' "$qualification" || fail 'real Dinit qualification script is missing its result marker'

printf 'dinitui_contract package=true profile_entry=true workflow_build=true argv_safe=true pkexec_fallback=true dinit_actions=true\n'
