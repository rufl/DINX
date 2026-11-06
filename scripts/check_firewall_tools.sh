#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'firewall_tools_contract: %s\n' "$*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo_root"
profile=distro/iso/iso-profiles/dinx/profile.yaml
groups=distro/iso/iso-profiles/dinx/feature-groups.json
common=distro/iso/iso-profiles/common/common.yaml
builder=scripts/build-iso-container.sh
panel_pkg=distro/packages/dinxpanel/PKGBUILD
panel_src=distro/packages/dinxpanel/src/main.zig
iso_check=scripts/check-iso-content.sh

for package in firewalld firewall-config; do
  grep -Fqx "    - $package" "$profile" || fail "$package is missing from the rootfs profile"
  grep -Fq "\"$package\"" "$groups" || fail "$package is missing from the ISO feature groups"
done
[[ $(grep -Fxc '      - firewalld-dinit' "$profile") -eq 2 ]] \
  || fail 'Firewalld Dinit package is not installed/enabled for both rootfs and livefs'
[[ $(grep -Ecx '[[:space:]]*"firewalld-dinit",[[:space:]]*' "$groups") -eq 2 ]] \
  || fail 'Firewalld Dinit package is missing from profile_init/livefs input inventories'

if grep -Fq 'iptables' "$common" "$groups"; then
  fail 'Portmaster-only iptables package remains in the common ISO inputs'
fi
if grep -Eq 'portmaster|libayatana-appindicator|webkit2gtk-4\.1' "$profile" "$groups" "$common" "$builder" "$panel_pkg" "$panel_src"; then
  fail 'Portmaster or an exclusive runtime dependency remains in the active ISO inputs'
fi
grep -Fq 'build_package dinxpanel' "$builder" || fail 'ISO builder does not build DINXPanel'
grep -Fq 'firewalld firewall-config firewalld-dinit' "$panel_pkg" || fail 'DINXPanel does not require Firewalld, its GUI and Dinit service'
grep -Fq 'Manage network access with Firewalld' "$panel_src" || fail 'DINXPanel firewall action is not labeled for Firewalld'
grep -Fq 'launch(&.{"firewall-config"})' "$panel_src" || fail 'DINXPanel does not launch firewall-config'

for required_path in \
  'usr/bin/firewalld' \
  'usr/bin/firewall-cmd' \
  'usr/bin/firewall-config' \
  'etc/dinit.d/firewalld' \
  'usr/share/applications/firewall-config.desktop' \
  'etc/dinit.d/boot.d/firewalld -> /etc/dinit.d/firewalld'; do
  grep -Fq "$required_path" "$iso_check" || fail "ISO content checker does not require $required_path"
done
for retired_path in \
  'usr/bin/portmaster' \
  'usr/lib/portmaster/portmaster-core' \
  'etc/dinit.d/portmaster' \
  'usr/share/applications/portmaster.desktop'; do
  grep -Fq "$retired_path" "$iso_check" || fail "ISO content checker does not reject $retired_path"
done
printf 'firewall_tools_contract firewalld=true firewall_config=true opensnitch=true service=dinit boot_enabled=rootfs+livefs replaced=portmaster,iptables,libayatana-appindicator,webkit2gtk\n'
