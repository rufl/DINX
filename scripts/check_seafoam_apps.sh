#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
iso_check="$root/scripts/check-iso-content.sh"
workflow="$root/.github/workflows/p0-iso.yml"
builder="$root/scripts/build-iso-container.sh"
dome_dir="$root/distro/packages/dome"
pearl_source="$root/distro/packages/pearl/source.env"

dome_source="$dome_dir/source.env"
zls_dir="$root/distro/packages/zls"
zls_smoke="$root/scripts/smoke_zls.sh"
settings_contract="$root/scripts/check_seafoam_settings.sh"
fail() {
  printf 'seafoam_apps_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$groups" "$iso_check" "$workflow" "$builder" \
  "$dome_dir/PKGBUILD" "$dome_source" "$pearl_source" "$zls_dir/PKGBUILD" "$zls_dir/source.env" \
  "$zls_smoke" "$settings_contract"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done

source "$dome_dir/source.env"
[[ "$DOME_VERSION" == 0.1.1 ]] || fail "unexpected Dome version: $DOME_VERSION"
[[ "$DOME_SOURCE_VERSION" == 0.3.0 ]] || fail "unexpected Pearl source version: $DOME_SOURCE_VERSION"
[[ "$DOME_SOURCE_SHA256" == afb15f5650cdd0aa00a9d6ee697dec1cde2cb9eaa77b1631e4876c125caba24a ]] \
  || fail 'Dome source checksum changed'
source "$pearl_source"
[[ "$PEARL_ZIG_VERSION" == 0.16.0 ]] || fail "unexpected Pearl/Dome/Phyto Zig version: $PEARL_ZIG_VERSION"

source "$zls_dir/source.env"
[[ "$ZLS_VERSION" == 0.16.0 ]] || fail "unexpected ZLS version: $ZLS_VERSION"
[[ "$ZLS_SOURCE_URL" == https://builds.zigtools.org/zls-x86_64-linux-0.16.0.tar.xz ]] \
  || fail 'ZLS source URL changed'
[[ "$ZLS_SOURCE_SHA256" == ded6d562a0b86ee878b1ddf70ffab2797ce3cdca3b02d6077548f9d56dff96b6 ]] \
  || fail 'ZLS source checksum changed'
[[ "$ZIG_VERSION" == 0.16.0 ]] || fail "unexpected bundled Zig runtime version: $ZIG_VERSION"
[[ "$ZIG_SOURCE_URL" == https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz ]] \
  || fail 'bundled Zig runtime source URL changed'
[[ "$ZIG_SOURCE_SHA256" == 70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00 ]] \
  || fail 'bundled Zig runtime checksum changed'
grep -Fqx '    - shikane' "$profile" || fail 'profile is missing shikane'
grep -Fqx '    - wdisplays' "$profile" || fail 'profile is missing wdisplays'
for base_package in dome seafoam-settings zls; do
  grep -Fqx "    - $base_package" "$profile" || fail "profile is missing base package: $base_package"
done

jq -e '.groups.desktop.packages | index("shikane") != null and index("wdisplays") != null and index("dome") != null and index("seafoam-settings") != null and index("zls") != null' "$groups" >/dev/null \
  || fail 'desktop feature group is missing a required Seafoam package or display tool'
if jq -e 'any(.groups.optional.packages[]; . == "dome" or . == "seafoam-settings" or . == "zls")' "$groups" >/dev/null; then
  fail 'a Seafoam base package remains in the optional feature group'
fi
if jq -e 'any(.groups[].packages[]; . == "coral")' "$groups" >/dev/null; then
  fail 'Coral is present even though the selected Seafoam set excludes it'
fi

for required in \
  '  usr/bin/shikane' \
  '  usr/bin/shikanectl' \
  '  usr/bin/wdisplays' \
  '  usr/bin/dome' \
  '  usr/bin/seafoam-settings' \
  '  usr/bin/zls' \
  '  usr/share/applications/network.cycles.wdisplays.desktop' \
  '  usr/share/applications/org.aqueous.Dome.desktop' \
  '  usr/share/applications/seafoam-settings.desktop' \
  '  usr/share/icons/hicolor/scalable/apps/org.aqueous.Dome.svg' \
  '  usr/share/icons/hicolor/scalable/apps/org.seafoam.Settings.svg' \
  '  usr/share/metainfo/org.aqueous.Dome.metainfo.xml' \
  '  usr/share/licenses/seafoam-settings/LICENSE' \
  '  usr/share/licenses/zls/LICENSE' \
  '  usr/share/licenses/zls/zig-LICENSE' \
  '  usr/share/doc/seafoam-settings/README.md' \
  '  usr/share/doc/zls/README.md' \
  '  etc/zls.json' \
  '  etc/xdg/zls.json' \
  '  usr/lib/zls/zig-env' \
  '  usr/lib/zls/zig-env.zon' \
  '  usr/lib/zls/zig/std/std.zig'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done

grep -Fq 'pkgver="$DOME_VERSION"' "$dome_dir/PKGBUILD" || fail 'Dome package version is not pinned'
grep -Fq '$DOME_SOURCE_SHA256' "$dome_dir/PKGBUILD" || fail 'Dome source checksum is not wired to source.env'
grep -Fq '"${ZIG:-zig}" build' "$dome_dir/PKGBUILD" || fail 'Dome package does not honor the selected Zig toolchain'
if grep -Eiq '(^|[^[:alnum:]_])(systemd|systemctl|uwsm)([^[:alnum:]_]|$)' "$dome_dir/PKGBUILD"; then
  fail 'Dome package recipe introduces a systemd or uwsm dependency or command'
fi
grep -Fq 'pkgver="$ZLS_VERSION"' "$zls_dir/PKGBUILD" || fail 'ZLS package version is not pinned'
grep -Fq '$ZLS_SOURCE_SHA256' "$zls_dir/PKGBUILD" || fail 'ZLS source checksum is not wired to source.env'
grep -Fq '$ZIG_SOURCE_SHA256' "$zls_dir/PKGBUILD" || fail 'bundled Zig runtime checksum is not wired to source.env'
grep -Fq 'source.env' "$zls_dir/PKGBUILD" || fail 'ZLS package does not load source.env'
grep -Fq 'zig_root/lib/std' "$zls_dir/PKGBUILD" || fail 'ZLS package does not bundle the Zig standard library'
grep -Fq 'sed -i "s/@ZIG_VERSION@/$ZIG_VERSION/"' "$zls_dir/PKGBUILD" || fail 'ZLS shim version is not generated from source.env'
grep -Fq 'zig-x86_64-linux-$ZIG_VERSION/lib/std' "$zls_dir/PKGBUILD" || fail 'ZLS package does not normalize the Zig standard-library path'
if grep -Eiq '(^|[^[:alnum:]_])(systemd|systemctl|uwsm)([^[:alnum:]_]|$)' "$zls_dir/PKGBUILD"; then
  fail 'ZLS package recipe introduces a systemd or uwsm dependency or command'
fi
grep -Fq 'build_package dome' "$builder" || fail 'ISO builder does not build Dome for the base package repository'
grep -Fq 'build_package zls' "$builder" || fail 'ISO builder does not build ZLS for the base package repository'
grep -Fq 'build_package seafoam-settings' "$builder" || fail 'ISO builder does not build Seafoam Settings for the base package repository'
grep -Fq 'zig_version=0.17.0' "$builder" || fail 'ISO builder does not pin Zig 0.17 for native DINX packages'
grep -Fq 'extra_env+=("ZIG=/tmp/zig-x86_64-linux-${zig_version}/zig")' "$builder" || fail 'ISO builder does not pass the pinned Zig toolchain to native packages'
grep -Fq 'if [[ "$package_name" == pearl || "$package_name" == phyto || "$package_name" == dome ]]; then' "$builder" \
  || fail 'ISO builder does not select the Pearl Zig toolchain for Dome'
grep -Fq 'ZIG=/tmp/zig-x86_64-linux-${PEARL_ZIG_VERSION}/zig' "$builder" \
  || fail 'ISO builder does not pass Pearl Zig toolchain to Dome'
grep -Fq 'ZLS_BIN=/usr/bin/zls scripts/smoke_zls.sh' "$builder" || fail 'Artix builder does not smoke-test ZLS'
grep -Fq 'scripts/check_seafoam_apps.sh' "$workflow" || fail 'workflow does not run the Seafoam app contract'
grep -Fq 'scripts/check_seafoam_settings.sh' "$workflow" || fail 'workflow does not run the Seafoam Settings contract'
"$settings_contract"

printf 'seafoam_apps_contract dome=true seafoam_settings=true zls=true coral=false display_tools=wdisplays+shikane dinit_safe=true sources_pinned=true base=true dome_zig=0.16.0\n'
