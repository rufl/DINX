#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'firewall_tools_contract: %s\n' "$*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

for path in \
  distro/packages/portmaster/PKGBUILD \
  distro/packages/portmaster/source.env \
  distro/packages/portmaster/dinx-portmaster \
  distro/packages/portmaster/dinx-portmaster-core-service \
  distro/packages/portmaster/portmaster-dinit \
  distro/packages/portmaster/portmaster.desktop; do
  [[ -f "$path" ]] || fail "missing Portmaster package file: $path"
done

grep -Fq '    - portmaster' distro/iso/iso-profiles/dinx/profile.yaml || fail 'Portmaster is missing from the DINX payload'
grep -Fq '    - qps' distro/iso/iso-profiles/dinx/profile.yaml || fail 'Qps is missing from the DINX payload'
grep -Fq '    "portmaster"' distro/iso/iso-profiles/dinx/feature-groups.json || fail 'Portmaster is missing from the desktop feature group'
grep -Fq 'build_package portmaster' scripts/build-iso-container.sh || fail 'ISO builder does not build Portmaster'
grep -Fq 'portmaster topgrade' distro/packages/dinxpanel/PKGBUILD || fail 'DINXPanel does not depend on Portmaster'
grep -Fq "'iptables'" distro/packages/portmaster/PKGBUILD || fail 'Portmaster package does not declare its firewall backend'
grep -Fq '/usr/bin/pkexec /usr/bin/dinitctl start portmaster' distro/packages/portmaster/dinx-portmaster || fail 'Portmaster launcher does not start the service on demand'
grep -Fq 'WEBKIT_DISABLE_COMPOSITING_MODE=1' distro/packages/portmaster/dinx-portmaster || fail 'Portmaster launcher omits the upstream WebKit rendering workaround'
grep -Fq 'type               = process' distro/packages/portmaster/portmaster-dinit || fail 'Portmaster dinit service is not a process service'
grep -Fq 'command            = /usr/local/libexec/dinx-portmaster-core-service' distro/packages/portmaster/portmaster-dinit || fail 'Portmaster dinit service command is incorrect'
grep -Fq 'portmaster-core -recover-iptables' distro/packages/portmaster/dinx-portmaster-core-service || fail 'Portmaster service does not recover firewall rules on stop'
if grep -Eq 'gufw|ufw(-dinit)?|opensnitch(-dinit)?' \
  distro/iso/iso-profiles/dinx/profile.yaml \
  distro/iso/iso-profiles/dinx/feature-groups.json; then
  fail 'retired Gufw, UFW or OpenSnitch package remains in the ISO input lists'
fi

for required_path in \
  'usr/bin/portmaster' \
  'usr/lib/portmaster/portmaster-core' \
  'usr/lib/portmaster/portmaster.zip' \
  'etc/dinit.d/portmaster' \
  'usr/share/applications/portmaster.desktop' \
  'usr/bin/qps'; do
  grep -Fq "$required_path" scripts/check-iso-content.sh || fail "ISO checker does not require $required_path"
done
printf 'firewall_tools_contract portmaster=true qps=true backend=iptables service=on-demand replaced=ufw,gufw,opensnitch\n'
