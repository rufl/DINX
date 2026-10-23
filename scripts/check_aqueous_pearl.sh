#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
workflow="$root/.github/workflows/p0-iso.yml"
aqueous_dir="$root/distro/packages/aqueous"
pearl_dir="$root/distro/packages/pearl"
iso_check="$root/scripts/check-iso-content.sh"
session_check="$root/scripts/check_dinx_session.sh"

fail() {
  printf 'aqueous_pearl_contract: %s\n' "$*" >&2
  exit 1
}

for path in \
  "$profile" "$groups" "$workflow" "$iso_check" "$session_check" \
  "$aqueous_dir/PKGBUILD" "$aqueous_dir/source.env" \
  "$pearl_dir/PKGBUILD" "$pearl_dir/source.env"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done

source "$aqueous_dir/source.env"
[[ "$AQUEOUS_VERSION" == 1.0.5 ]] || fail "unexpected Aqueous version: $AQUEOUS_VERSION"
[[ "$AQUEOUS_SOURCE_SHA256" == 7f71b328c191657a441b6c4ee3a18343f1751a5f2dacec229bf3d50c9de561d8 ]] \
  || fail 'Aqueous source checksum changed'
[[ "$AQUEOUS_WLROOTS_SHA256" == 972c7ac44b17828f4702bfae7cd8347346a3fb5b2c1076cfa2c3fcedac5ec343 ]] \
  || fail 'Aqueous wlroots checksum changed'
source "$pearl_dir/source.env"
[[ "$PEARL_VERSION" == 0.3.0 ]] || fail "unexpected Pearl version: $PEARL_VERSION"
[[ "$PEARL_SOURCE_SHA256" == afb15f5650cdd0aa00a9d6ee697dec1cde2cb9eaa77b1631e4876c125caba24a ]] \
  || fail 'Pearl source checksum changed'

for package in aqueous pearl; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
done
jq -e '.groups.desktop.packages | index("aqueous") != null and index("pearl") != null' "$groups" >/dev/null \
  || fail 'desktop feature group is missing Aqueous or Pearl'
if jq -e 'any(.groups[].packages[]; . == "aqueous-core" or . == "aqueous-session" or . == "uwsm")' "$groups" >/dev/null; then
  fail 'obsolete Aqueous split or uwsm package is in a feature group'
fi

for required in \
  '  usr/bin/aqueous' \
  '  usr/bin/aqueousctl' \
  '  usr/bin/aqueous-config' \
  '  usr/bin/pearl' \
  '  usr/share/wayland-sessions/dinx-aqueous-pearl.desktop' \
  '  usr/local/libexec/dinx-aqueous-pearl' \
  '  usr/local/libexec/dinx-aqueous-init'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done

grep -Fq 'pkgver="$AQUEOUS_VERSION"' "$aqueous_dir/PKGBUILD" || fail 'Aqueous package version is not pinned'
grep -Fq '$AQUEOUS_SOURCE_SHA256' "$aqueous_dir/PKGBUILD" || fail 'Aqueous source checksum is not wired to source.env'
grep -Fq '$AQUEOUS_WLROOTS_SHA256' "$aqueous_dir/PKGBUILD" || fail 'Aqueous wlroots checksum is not wired to source.env'
grep -Fq 'settingsApplication/build.zig' "$aqueous_dir/PKGBUILD" || fail 'Aqueous config helper is not built'
grep -Fq 'aqueous-config' "$aqueous_dir/PKGBUILD" || fail 'Aqueous config helper is not packaged'
grep -Fq "'systemd-libs'" "$aqueous_dir/PKGBUILD" || fail 'Aqueous compatibility library dependency is not explicit'
if grep -Eq "['\"](systemd|systemctl|uwsm)['\"]" "$aqueous_dir/PKGBUILD" \
  || grep -Eiq '(^|[[:space:]])(systemctl|uwsm)([[:space:]]|$)' "$aqueous_dir/PKGBUILD"; then
  fail 'Aqueous recipe contains a systemd init, systemctl or uwsm dependency/command'
fi

grep -Fq 'pkgver="$PEARL_VERSION"' "$pearl_dir/PKGBUILD" || fail 'Pearl package version is not pinned'
grep -Fq '$PEARL_SOURCE_SHA256' "$pearl_dir/PKGBUILD" || fail 'Pearl source checksum is not wired to source.env'
grep -Fq -- '-Dwasm-plugins=false' "$pearl_dir/PKGBUILD" || fail 'Pearl package does not select the compact native build'
grep -Fq 'rm -rf "$pkgdir/usr/lib/systemd" "$pkgdir/usr/share/uwsm"' "$pearl_dir/PKGBUILD" \
  || fail 'Pearl upstream lifecycle payload is not removed'
if grep -Eq "['\"](systemd|systemctl|uwsm)['\"]" "$pearl_dir/PKGBUILD" \
  || grep -Eiq '(^|[[:space:]])(systemctl|uwsm)([[:space:]]|$)' "$pearl_dir/PKGBUILD"; then
  fail 'Pearl recipe contains a systemd init, systemctl or uwsm dependency/command'
fi

grep -Fq 'build_package aqueous' "$workflow" || fail 'workflow does not build Aqueous'
grep -Fq 'build_package pearl' "$workflow" || fail 'workflow does not build Pearl'
grep -Fq 'scripts/check_aqueous_pearl.sh' "$workflow" || fail 'workflow does not run the Aqueous/Pearl contract'
grep -Fq 'scripts/check_dinx_session.sh' "$workflow" || fail 'workflow does not run the session contract'

grep -Fq 'exec /usr/bin/aqueous -c /usr/local/libexec/dinx-aqueous-init' \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-pearl" \
  || fail 'direct Aqueous wrapper command is missing'
grep -Fq 'exec /usr/bin/pearl' \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-init" \
  || fail 'direct Pearl command is missing'

printf 'aqueous_pearl_contract aqueous=%s pearl=%s direct_dinit=true systemd_units=false uwsm=false sources_pinned=true\n' \
  "$AQUEOUS_VERSION" "$PEARL_VERSION"
