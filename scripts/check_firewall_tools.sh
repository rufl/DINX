#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'firewall_tools_contract: %s\n' "$*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

for path in \
  distro/packages/opensnitch-dinit/PKGBUILD \
  distro/packages/opensnitch-dinit/opensnitchd; do
  [[ -f "$path" ]] || fail "missing OpenSnitch dinit contract file: $path"
done

grep -Fq "    - ufw" distro/iso/iso-profiles/dinx/profile.yaml || fail 'ufw is missing from the DINX payload'
grep -Fq "    - ufw-dinit" distro/iso/iso-profiles/dinx/profile.yaml || fail 'ufw-dinit is missing from the DINX payload'
grep -Fq "    - gufw" distro/iso/iso-profiles/dinx/profile.yaml || fail 'gufw is missing from the DINX payload'
grep -Fq "    - qps" distro/iso/iso-profiles/dinx/profile.yaml || fail 'qps is missing from the DINX payload'
grep -Fq "    - opensnitch" distro/iso/iso-profiles/dinx/profile.yaml || fail 'opensnitch is missing from the DINX payload'
grep -Fq "    - opensnitch-dinit" distro/iso/iso-profiles/dinx/profile.yaml || fail 'opensnitch-dinit is missing from the DINX payload'

grep -Fq 'build_package opensnitch-dinit' .github/workflows/p0-iso.yml || fail 'CI does not build opensnitch-dinit'
grep -Fq 'type               = process' distro/packages/opensnitch-dinit/opensnitchd || fail 'OpenSnitch dinit service is not a process service'
grep -Fq 'command            = /usr/bin/opensnitchd' distro/packages/opensnitch-dinit/opensnitchd || fail 'OpenSnitch dinit command is incorrect'
grep -Fq 'depends-on         = dbus' distro/packages/opensnitch-dinit/opensnitchd || fail 'OpenSnitch dinit service does not wait for D-Bus'

grep -Fq '"gufw", "qps", "opensnitch_ui"' distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/noctalia/config.toml || fail 'Noctalia dock is missing firewall/process launchers'
grep -Fq 'usr/bin/ufw' scripts/check-iso-content.sh || fail 'ISO checker does not require ufw'
grep -Fq 'usr/bin/gufw' scripts/check-iso-content.sh || fail 'ISO checker does not require gufw'
grep -Fq 'usr/bin/qps' scripts/check-iso-content.sh || fail 'ISO checker does not require qps'
grep -Fq 'usr/bin/opensnitchd' scripts/check-iso-content.sh || fail 'ISO checker does not require opensnitchd'
grep -Fq 'usr/bin/opensnitch-ui' scripts/check-iso-content.sh || fail 'ISO checker does not require opensnitch-ui'
grep -Fq 'etc/dinit.d/ufw' scripts/check-iso-content.sh || fail 'ISO checker does not require the UFW dinit service'
grep -Fq 'etc/dinit.d/opensnitchd' scripts/check-iso-content.sh || fail 'ISO checker does not require the OpenSnitch dinit service'
printf 'firewall_tools_contract ufw=gufw=qps=opensnitch=true dinit_services=ufw,opensnitchd safe_defaults=manual_enable\n'
