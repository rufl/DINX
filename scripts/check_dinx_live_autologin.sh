#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
root_greetd="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/config.toml"
users_conf="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/modules/users.conf"
package_dir="$root/distro/packages/dinx-live-autologin"
wrapper="$package_dir/dinx-live-autologin"
root_ro="$package_dir/root-ro"
root_rw="$package_dir/early-root-rw.target"
pkgbuild="$package_dir/PKGBUILD"
root_overlay="$root/distro/iso/iso-profiles/dinx/root-overlay"
live_overlay="$root/distro/iso/iso-profiles/dinx/live-overlay"
live_policy="$live_overlay/etc/polkit-1/rules.d/00-dinx-live-passwordless.rules"
root_policy="$root_overlay/etc/polkit-1/rules.d/00-dinx-live-passwordless.rules"
service="$package_dir/dinx-live-autologin.service"
workflow="$root/.github/workflows/p0-iso.yml"
builder="$root/scripts/build-iso-container.sh"

fail() {
  printf 'check_dinx_live_autologin: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$root_greetd" "$users_conf" "$wrapper" "$service" "$root_ro" "$root_rw" "$pkgbuild" "$workflow" \
  "$live_overlay/etc/default/grub" "$live_overlay/etc/hostname" "$live_policy"; do
  [[ -r "$path" ]] || fail "missing $path"
done

bash -n "$wrapper" || fail 'live autologin wrapper has invalid shell syntax'
(
  cd "$package_dir"
  source ./PKGBUILD
  [[ ${#source[@]} -eq ${#sha256sums[@]} ]] || exit 1
  for index in "${!source[@]}"; do
    printf '%s  %s\n' "${sha256sums[$index]}" "${source[$index]}" | sha256sum --check --status || exit 1
  done
) || fail 'live autologin package source checksums are invalid'

grep -Fq '  autologin: true' "$profile" || fail 'live-session autologin is not enabled'

grep -Fq '  hostname: dinxlive' "$profile" || fail 'live-session profile hostname is not dinxlive'
grep -Fqx 'dinxlive' "$live_overlay/etc/hostname" \
  || fail 'live overlay hostname file is not dinxlive'
livefs_packages=$(awk '
  /^livefs:/{in_live=1; next}
  in_live && /^  packages:/{in_packages=1; next}
  in_packages && /^  packages-init:/{exit}
  in_packages{print}
' "$profile")
grep -Fqx '    - dinx-live-autologin' <<<"$livefs_packages" \
  || fail 'live-only autologin package is not in livefs packages'

grep -Fq 'command = "/usr/local/libexec/dinx-pearl-greeter-host"' "$root_greetd" \
  || fail 'installed greetd fallback does not launch the graphics-safe Pearl Greeter wrapper'
grep -Fq 'user = "pearl-greeter"' "$root_greetd" \
  || fail 'installed greetd fallback user is not the dedicated Pearl Greeter account'
! grep -Fq '[initial_session]' "$root_greetd" \
  || fail 'installed greetd config must not enable autologin'
grep -Fq 'displayAutologin: false' "$users_conf" \
  || fail 'Calamares display autologin must remain disabled'
grep -Fq 'doAutologin: false' "$users_conf" \
  || fail 'Calamares user autologin must remain disabled'
grep -Fqx '    - render' "$users_conf" \
  || fail 'installed users are missing DRM render-node access'

grep -Fq "AUTOLOGIN=true" "$wrapper" || fail 'live wrapper does not guard on AUTOLOGIN=true'
grep -Fq '[initial_session]' "$wrapper" || fail 'live wrapper does not configure greetd initial_session'
grep -Fq 'command = "env DINX_LIVE_SESSION=1 dbus-run-session /usr/local/libexec/dinx-aqueous-pearl"' "$wrapper" \
  || fail 'live initial Aqueous/Pearl command does not mark the live session'
grep -Fq 'user = "dinx"' "$wrapper" || fail 'live initial session user is missing'
grep -Fq 'usermod --append --groups render dinx' "$wrapper" \
  || fail 'live user is missing DRM render-node access'
grep -Fq 'getent group render' "$wrapper" \
  || fail 'live autologin does not guard render-group enrollment'
grep -Fq "printf '%s\\n' 'dinxlive' > /etc/hostname" "$wrapper" \
  || fail 'live wrapper does not persist the dinxlive hostname'
grep -Fq 'hostname dinxlive' "$wrapper" || fail 'live wrapper does not set the active dinxlive hostname'
hostname_setup_line=$(grep -nF "printf '%s\\n' 'dinxlive' > /etc/hostname" "$wrapper" | cut -d: -f1)
autologin_gate_line=$(grep -nF 'if [ ! -r "$live_conf" ]' "$wrapper" | cut -d: -f1)
((hostname_setup_line < autologin_gate_line)) \
  || fail 'hostname setup is incorrectly gated on autologin'
grep -Fq 'install -d -o pearl-greeter -g pearl-greeter -m 0700 \' "$wrapper" \
  || fail 'live boot does not provision Pearl Greeter runtime directories'
grep -Fq '/var/lib/pearl-greeter /var/cache/pearl-greeter' "$wrapper" \
  || fail 'live boot does not provision Pearl Greeter state and cache paths'
greeter_dirs_setup_line=$(grep -nF 'install -d -o pearl-greeter' "$wrapper" | cut -d: -f1)
((greeter_dirs_setup_line < autologin_gate_line)) \
  || fail 'Pearl Greeter runtime directories are incorrectly gated on autologin'
grep -Fqx 'depends-on = local.target' "$service" \
  || fail 'live hostname service does not depend on local.target'
grep -Fqx 'depends-on = artix-live' "$service" \
  || fail 'live hostname service does not depend on artix-live'
grep -Fqx 'waits-for = firewalld' "$service" \
  || fail 'live autologin does not wait for the Firewalld startup attempt'
grep -Fq "depends=('dinit' 'greetd' 'firewalld-dinit')" "$pkgbuild" \
  || fail 'live autologin package does not declare its Firewalld service dependency'
! grep -Fqx 'depends-on = local.target artix-live' "$service" \
  || fail 'live hostname service combines dependencies into one unresolved service name'
grep -Fq 'before = greetd' "$service" || fail 'live autologin service does not precede greetd'
grep -Fq 'before = login.target' "$service" || fail 'live autologin service does not precede the login target'
! grep -Fq 'greetd.service' "$pkgbuild" \
  || fail 'live autologin package must not replace greetd-dinit service files'
! grep -Fq 'pkgdir/etc/dinit.d/greetd' "$pkgbuild" \
  || fail 'live autologin package must not own greetd-dinit service files'
grep -Fq 'boot.d/dinx-live-autologin' "$pkgbuild" \
  || fail 'live autologin service is not linked into dinit boot'

grep -Fq "'root-ro' 'early-root-rw.target'" "$pkgbuild" \
  || fail 'live root remount overrides are not package sources'
grep -Fq 'pkgdir/etc/dinit.d/root-ro' "$pkgbuild" \
  || fail 'live root-ro override is not installed by the package'
grep -Fq 'pkgdir/etc/dinit.d/early-root-rw.target' "$pkgbuild" \
  || fail 'live early-root-rw override is not installed by the package'
for unit in "$root_ro" "$root_rw"; do
  grep -Fqx 'command = /bin/true' "$unit" \
    || fail "live overlay remount is not bypassed in $unit"
done
for unit in "$root_overlay/etc/dinit.d/root-ro" "$root_overlay/etc/dinit.d/early-root-rw.target"; do
  [[ ! -e "$unit" ]] || fail "live-only override leaked into installed rootfs overlay: $unit"
done
[[ ! -e "$root_overlay/etc/dinit.d/greetd" ]] \
  || fail 'live greetd dependency override leaked into installed rootfs overlay'
[[ ! -e "$root_policy" ]] \
  || fail 'live-only Polkit authorization leaked into the installed rootfs overlay'
grep -Fq 'subject.user === "dinx" && subject.local && subject.active' "$live_policy" \
  || fail 'live Polkit rule is not scoped to the active local dinx user'
grep -Fq 'return polkit.Result.YES;' "$live_policy" \
  || fail 'live Polkit rule does not authorize without credentials'
if grep -Eq 'auth_(admin|self)' "$live_policy"; then
  fail 'live Polkit rule still requires authentication'
fi

grep -Fq 'build_package dinx-live-autologin' "$builder" \
  || fail 'ISO builder does not build the live autologin package'
grep -Fq 'run: ./scripts/check_dinx_session.sh' "$workflow" \
  || fail 'CI dropped the existing DINX session contract'
! grep -Fq 'DINX_QEMU_POST_KEYS' "$workflow" \
  || fail 'Linux QEMU smoke still injects manual live credentials'

printf 'dinx_live_autologin_contract=live=true initial_session=true greetd_ordering=true render_group=true fallback_pearl_greeter=true live_root_overrides=true installed_rootfs_clean=true polkit_live_only=true dinit=true\n'
