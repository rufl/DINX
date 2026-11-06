#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json"
common="$repo_root/distro/iso/iso-profiles/common/common.yaml"
builder="$repo_root/scripts/build-iso-container.sh"
iso_check="$repo_root/scripts/check-iso-content.sh"
package_dir="$repo_root/distro/packages/opensnitch-dinit"
pkgbuild="$package_dir/PKGBUILD"
service="$package_dir/opensnitchd"
autostart="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/autostart/opensnitch-ui.desktop"

fail() {
  printf 'check_opensnitch: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$groups" "$common" "$builder" "$iso_check" "$pkgbuild" "$service" "$autostart"; do
  [[ -r "$path" ]] || fail "missing $path"
done

[[ $(grep -Fxc '    - opensnitch' "$profile") -eq 1 ]] \
  || fail 'OpenSnitch is not selected exactly once in the installed rootfs profile'
python3 - "$groups" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    groups = json.load(stream)
assert groups["groups"]["desktop"]["packages"].count("opensnitch") == 1
PY
[[ $(grep -Fxc '      - opensnitch-dinit' "$profile") -eq 2 ]] \
  || fail 'OpenSnitch Dinit service package is not selected for rootfs and livefs'
grep -Fq 'build_package opensnitch-dinit' "$builder" \
  || fail 'ISO builder does not build the OpenSnitch Dinit service package'
grep -Fq "depends=('dinit' 'opensnitch')" "$pkgbuild" \
  || fail 'Dinit service package does not depend on OpenSnitch and Dinit'
grep -Fq '"$pkgdir/etc/dinit.d/opensnitchd"' "$pkgbuild" \
  || fail 'Dinit service package does not install its service file'
grep -Fq 'ln -s /etc/dinit.d/opensnitchd' "$pkgbuild" \
  || fail 'OpenSnitch Dinit service is not enabled at boot'
for setting in \
  'type = process' \
  'command = /usr/bin/opensnitchd' \
  'restart = true' \
  'restart-delay = 15' \
  'stop-timeout = 10' \
  'restart-limit-count = 0'; do
  grep -Fqx "$setting" "$service" || fail "OpenSnitch service is missing $setting"
done

[[ $(grep -Fxc '      - firewalld-dinit' "$profile") -eq 2 ]] \
  || fail 'Firewalld service must remain enabled alongside OpenSnitch'
if grep -Fq 'iptables' "$common"; then
  fail 'iptables was reintroduced even though OpenSnitch uses the configured nftables backend'
fi

for required_path in \
  'usr/bin/opensnitchd' \
  'usr/bin/opensnitch-ui' \
  'usr/share/applications/opensnitch_ui.desktop' \
  'usr/share/icons/hicolor/scalable/apps/opensnitch-ui.svg' \
  'etc/opensnitchd/default-config.json' \
  'etc/xdg/autostart/opensnitch-ui.desktop' \
  'etc/dinit.d/opensnitchd' \
  'etc/dinit.d/boot.d/opensnitchd'; do
  grep -Fq "$required_path" "$iso_check" || fail "ISO content gate does not require $required_path"
done
grep -Fqx '[Desktop Entry]' "$autostart" || fail 'OpenSnitch autostart desktop entry is malformed'
grep -Fqx 'Exec=opensnitch-ui --background' "$autostart" \
  || fail 'OpenSnitch UI does not start in the tray/background'
grep -Fqx 'TryExec=opensnitch-ui' "$autostart" \
  || fail 'OpenSnitch autostart is not guarded by its executable'
grep -Fq 'squashfs-root/etc/dinit.d/boot.d/opensnitchd -> /etc/dinit.d/opensnitchd' "$iso_check" \
  || fail 'ISO content gate does not verify the OpenSnitch Dinit boot link in both images'
grep -Fq 'for required_package in floorp opensnitch opensnitch-dinit' "$iso_check" \
  || fail 'ISO content gate does not require the browser and OpenSnitch package metadata'

printf 'opensnitch_contract package=true ui_autostart=true backend=nftables default_action=allow dinit=true boot_enabled=rootfs+livefs firewall=firewalld+nftables\n'
