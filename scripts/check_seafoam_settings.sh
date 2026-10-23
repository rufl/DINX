#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$root/distro/packages/seafoam-settings"
pkgbuild="$package_dir/PKGBUILD"
source_file="$package_dir/src/main.zig"
build_file="$package_dir/build.zig"
desktop="$package_dir/resources/seafoam-settings.desktop"
icon="$package_dir/resources/seafoam-settings.svg"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
workflow="$root/.github/workflows/p0-iso.yml"
smoke_script="$root/scripts/seafoam_settings_smoke.sh"

fail() {
  printf 'seafoam_settings_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$build_file" "$source_file" "$desktop" "$icon" "$package_dir/README.md" \
  "$groups" "$workflow" "$smoke_script"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done

grep -Fqx 'pkgname=seafoam-settings' "$pkgbuild" || fail 'package name is not seafoam-settings'
grep -Fqx 'source=()' "$pkgbuild" || fail 'Seafoam Settings must be a local staged package'
grep -Fq 'zig build -Doptimize=ReleaseSafe' "$pkgbuild" || fail 'package does not use the release-safe Zig build'
grep -Fq 'install -Dm755 "$srcdir/stage/bin/seafoam-settings"' "$pkgbuild" || fail 'package does not install the binary'
grep -Fq 'Name=Seafoam Settings' "$desktop" || fail 'desktop name is missing'
grep -Fq 'Exec=seafoam-settings' "$desktop" || fail 'desktop executable is missing'
grep -Fq 'Icon=org.seafoam.Settings' "$desktop" || fail 'desktop icon is missing'
grep -Fq 'seafoam-settings' "$build_file" || fail 'build file does not name the app'

for required in \
  'dinx-wdisplays' \
  'dinx-save-shikane-profile' \
  'dinitui' \
  'dinxpanel' \
  'qt6ct' \
  'dome' \
  'g_spawn_async' \
  'std.fs.path.join' \
  '--smoke' \
  'seafoam_settings_smoke'; do
  grep -Fq -- "$required" "$source_file" || fail "source is missing fixed action or smoke marker: $required"
done
if grep -Eiq '(^|[^[:alnum:]_])systemd([^[:alnum:]_]|$)|systemctl|g_spawn_command_line|/bin/sh' "$source_file"; then
  fail 'source contains a systemd, shell or arbitrary command-launch path'
fi

jq -e '.groups.optional.packages | index("seafoam-settings") != null' "$groups" >/dev/null \
  || fail 'optional feature group is missing Seafoam Settings'
grep -Fq 'build_package seafoam-settings' "$workflow" || fail 'workflow does not build Seafoam Settings'
grep -Fq 'scripts/check_seafoam_settings.sh' "$workflow" || fail 'workflow does not run the Seafoam Settings contract'
grep -Fq 'scripts/seafoam_settings_smoke.sh' "$workflow" || fail 'workflow does not run the Seafoam Settings smoke'

printf 'seafoam_settings_contract package=true optional=true argv_safe=true smoke=true\n'
