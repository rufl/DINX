#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
root_greetd="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/config.toml"
users_conf="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/modules/users.conf"
package_dir="$root/distro/packages/dinx-live-autologin"
wrapper="$package_dir/dinx-live-autologin"
service="$package_dir/dinx-live-autologin.service"
workflow="$root/.github/workflows/p0-iso.yml"

fail() {
  printf 'check_dinx_live_autologin: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$root_greetd" "$users_conf" "$wrapper" "$service" "$workflow"; do
  [[ -r "$path" ]] || fail "missing $path"
done

bash -n "$wrapper" || fail 'live autologin wrapper has invalid shell syntax'
grep -Fq '  autologin: true' "$profile" || fail 'live-session autologin is not enabled'

livefs_packages=$(awk '
  /^livefs:/{in_live=1; next}
  in_live && /^  packages:/{in_packages=1; next}
  in_packages && /^  packages-init:/{exit}
  in_packages{print}
' "$profile")
grep -Fqx '    - dinx-live-autologin' <<<"$livefs_packages" \
  || fail 'live-only autologin package is not in livefs packages'

grep -Fq 'command = "/usr/lib/pearl/pearl-greeter-host"' "$root_greetd" \
  || fail 'installed greetd fallback does not launch Pearl Greeter'
grep -Fq 'user = "pearl-greeter"' "$root_greetd" \
  || fail 'installed greetd fallback user is not the dedicated Pearl Greeter account'
! grep -Fq '[initial_session]' "$root_greetd" \
  || fail 'installed greetd config must not enable autologin'
grep -Fq 'displayAutologin: false' "$users_conf" \
  || fail 'Calamares display autologin must remain disabled'
grep -Fq 'doAutologin: false' "$users_conf" \
  || fail 'Calamares user autologin must remain disabled'

grep -Fq "AUTOLOGIN=true" "$wrapper" || fail 'live wrapper does not guard on AUTOLOGIN=true'
grep -Fq '[initial_session]' "$wrapper" || fail 'live wrapper does not configure greetd initial_session'
grep -Fq 'command = "dbus-run-session /usr/local/libexec/dinx-aqueous-pearl"' "$wrapper" \
  || fail 'live initial Aqueous/Pearl command is missing'
grep -Fq 'user = "dinx"' "$wrapper" || fail 'live initial session user is missing'
grep -Fq 'before = greetd' "$service" || fail 'live autologin service does not precede greetd'
grep -Fq 'after = artix-live' "$service" || fail 'live autologin service ordering is incomplete'
grep -Fq 'boot.d/dinx-live-autologin' "$package_dir/PKGBUILD" \
  || fail 'live autologin service is not linked into dinit boot'

grep -Fq 'build_package dinx-live-autologin' "$workflow" \
  || fail 'CI does not build the live autologin package'
grep -Fq 'run: ./scripts/check_dinx_session.sh' "$workflow" \
  || fail 'CI dropped the existing DINX session contract'
! grep -Fq 'DINX_QEMU_POST_KEYS' "$workflow" \
  || fail 'Linux QEMU smoke still injects manual live credentials'

printf 'dinx_live_autologin_contract=live=true initial_session=true fallback_pearl_greeter=true installed_autologin=false dinit=true\n'
