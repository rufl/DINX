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
builder="$root/scripts/build-iso-container.sh"
smoke_script="$root/scripts/seafoam_settings_smoke.sh"
zls_smoke="$root/scripts/smoke_zls.sh"

fail() {
  printf 'seafoam_settings_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$build_file" "$source_file" "$desktop" "$icon" "$package_dir/README.md" \
  "$groups" "$workflow" "$builder" "$smoke_script" "$zls_smoke"; do
  [[ -r "$path" ]] || fail "required input is missing or unreadable: $path"
done

grep -Fqx 'pkgname=seafoam-settings' "$pkgbuild" || fail 'package name is not seafoam-settings'
grep -Fqx 'source=()' "$pkgbuild" || fail 'Seafoam Settings must be a local staged package'
grep -Fq 'depends=(gtk4 libadwaita glibc deetty dintor dinitui dinxpanel qt6ct wdisplays shikane dome)' "$pkgbuild" \
  || fail 'package dependencies do not use the sole Deetty terminal and Dintor editor'
grep -Fq 'zig build -Doptimize=ReleaseSafe' "$pkgbuild" || fail 'package does not use the release-safe Zig build'
grep -Fq 'install -Dm755 "$srcdir/stage/bin/seafoam-settings"' "$pkgbuild" || fail 'package does not install the binary'
grep -Fq 'Name=Desktop Settings' "$desktop" || fail 'desktop name is missing'
grep -Fqx 'Name[pt_BR]=Ajustes do Desktop' "$desktop" || fail 'localized desktop name is missing'
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
grep -Fq '"deetty", "-e", "dinx-save-shikane-profile"' "$source_file" \
  || fail 'Shikane export does not use Deetty as its terminal'
grep -Fq 'self.launch(&.{ "dintor", path })' "$source_file" \
  || fail 'configuration files do not open directly in Dintor'
if grep -Eiq '"(foot|ghostty|nano)"' "$source_file" "$pkgbuild"; then
  fail 'Seafoam Settings references a removed terminal/editor fallback'
fi
if grep -Eiq '(^|[^[:alnum:]_])(systemd|systemctl|uwsm)([^[:alnum:]_]|$)|g_spawn_command_line|/bin/sh' "$source_file"; then
  fail 'source contains a systemd, uwsm, shell or arbitrary command-launch path'
fi
if grep -Eiq '(^|[^[:alnum:]_])(systemd|systemctl|uwsm)([^[:alnum:]_]|$)' "$pkgbuild"; then
  fail 'package recipe contains a systemd or uwsm dependency or command'
fi

jq -e '.groups.desktop.packages | index("dome") != null and index("seafoam-settings") != null and index("zls") != null' "$groups" >/dev/null \
  || fail 'desktop feature group is missing a Seafoam base package'
if jq -e 'any(.groups.optional.packages[]; . == "dome" or . == "seafoam-settings" or . == "zls")' "$groups" >/dev/null; then
  fail 'a Seafoam base package remains in the optional feature group'
fi
grep -Fq 'build_package seafoam-settings' "$builder" || fail 'ISO builder does not build Seafoam Settings'
grep -Fq 'build_package zls' "$builder" || fail 'ISO builder does not build ZLS'
grep -Fq 'scripts/check_seafoam_settings.sh' "$workflow" || fail 'workflow does not run the Seafoam Settings contract'
grep -Fq 'SEAFOAM_SETTINGS_BIN=/usr/bin/seafoam-settings scripts/seafoam_settings_smoke.sh' "$builder" \
  || fail 'Artix builder does not run the Seafoam Settings smoke after package installation'
grep -Fq 'ZLS_BIN=/usr/bin/zls scripts/smoke_zls.sh' "$builder" \
  || fail 'Artix builder does not smoke-test the installed ZLS package'
grep -Fq '"$package_repo"/zls-*.pkg.tar.zst' "$builder" || fail 'ISO builder does not install ZLS before the Seafoam smoke'
grep -Fq '"$package_repo"/dome-*.pkg.tar.zst' "$builder" || fail 'ISO builder does not install Dome before the Seafoam Settings smoke'

printf 'seafoam_settings_contract package=true base=true dome_dependency=true zls_runtime=true argv_safe=true smoke=true\n'
