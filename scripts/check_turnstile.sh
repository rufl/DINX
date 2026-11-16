#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
pkg="$root/distro/packages/turnstile/PKGBUILD"
source_env="$root/distro/packages/turnstile/source.env"
builder="$root/scripts/build-iso-container.sh"
workflow="$root/.github/workflows/p0-iso.yml"
iso_check="$root/scripts/check-iso-content.sh"
pam="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/pam.d/greetd"

fail() {
  printf 'turnstile_contract: FAIL: %s\n' "$1" >&2
  exit 1
}

for path in "$profile" "$groups" "$pkg" "$source_env" "$builder" "$workflow" "$iso_check" "$pam"; do
  [[ -r "$path" ]] || fail "missing file: ${path#$root/}"
done

source "$source_env"
[[ "$TURNSTILE_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail 'invalid Turnstile version'
[[ "$TURNSTILE_SOURCE_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid Turnstile checksum'
grep -Fqx '    - turnstile' "$profile" || fail 'profile is missing turnstile'
jq -e '.groups.foundation.packages | index("turnstile") != null' "$groups" >/dev/null \
  || fail 'foundation group is missing turnstile'
grep -Fq 'pkgname=turnstile' "$pkg" || fail 'package name is not turnstile'
grep -Fq 'turnstile-$pkgver.tar.gz::$TURNSTILE_SOURCE_URL' "$pkg" \
  || fail 'upstream Turnstile source is not pinned'
grep -Fq 'build_package turnstile' "$builder" || fail 'ISO builder does not build Turnstile'
grep -Fq 'scripts/check_turnstile.sh' "$workflow" || fail 'workflow does not run the Turnstile contract'
grep -Fq 'pam_turnstile.so turnstiled' "$pam" || fail 'greetd PAM stack does not start Turnstile sessions'
grep -Fq 'manage_rundir=false' "$pkg" || fail 'Turnstile must defer XDG_RUNTIME_DIR ownership to elogind in DINX'
for required in \
  '  usr/bin/turnstiled' \
  '  usr/lib/security/pam_turnstile.so' \
  '  etc/dinit.d/turnstiled' \
  '  etc/turnstile/turnstiled.conf' \
  '  etc/pam.d/turnstiled' \
  '  etc/pam.d/greetd' \
  '  usr/share/licenses/turnstile/COPYING.md'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done
if grep -Eiq '(^|[^[:alnum:]_])(systemd|systemctl|uwsm)([^[:alnum:]_]|$)' "$pkg"; then
  fail 'Turnstile package contains a forbidden systemd/UWSM dependency'
fi
printf 'turnstile_contract: PASS version=%s dinit=true pam=true manage_rundir=false\n' "$TURNSTILE_VERSION"
