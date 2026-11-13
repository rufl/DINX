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
root_greetd_service="$root_overlay/etc/dinit.d/greetd"
live_greetd="$live_overlay/etc/dinit.d/greetd"
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
  "$live_overlay/etc/default/grub" "$live_overlay/etc/hostname" "$live_policy" "$live_greetd" \
  "$live_overlay/etc/dinit.d/seatd" \
  "$root_greetd_service"; do
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
grep -Fqx 'vt = 7' "$root_greetd" \
  || fail 'installed greetd must use its dedicated VT, separate from tty1 getty'
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
grep -Fq 'install -d -o dinx -g dinx -m 0700 /run/dinx-session' "$wrapper" \
  || fail 'live wrapper does not provision the private session runtime dir'
grep -Fq 'usermod --append --groups render dinx' "$wrapper" \
  || fail 'live user is missing DRM render-node access'
grep -Fq 'getent group render' "$wrapper" \
  || fail 'live autologin does not guard render-group enrollment'
grep -Fq "printf '%s\\n' 'dinxlive' > /etc/hostname" "$wrapper" \
  || fail 'live wrapper does not persist the dinxlive hostname'
grep -Fq 'hostname dinxlive' "$wrapper" || fail 'live wrapper does not set the active dinxlive hostname'
hostname_setup_line=$(grep -nF "printf '%s\\n' 'dinxlive' > /etc/hostname" "$wrapper" | cut -d: -f1)
autologin_gate_line=$(grep -nF 'if [ ! -r "$live_conf" ]' "$wrapper" | cut -d: -f1)
! grep -Fq '/usr/bin/pacman-key' "$wrapper" \
  || fail 'live greeter startup must not run keyring operations that can block greetd'
((hostname_setup_line < autologin_gate_line)) \
  || fail 'hostname setup is incorrectly gated on autologin'
grep -Fqx 'depends-on = local.target' "$service" \
  || fail 'live hostname service does not depend on local.target'
grep -Fqx 'depends-on = artix-live' "$service" \
  || fail 'live hostname service does not depend on artix-live'
! grep -Fqx 'depends-on = pacman-init' "$service" \
  || fail 'live autologin must not be gated on pacman keyring setup'
grep -Fqx 'waits-for = firewalld' "$service" \
  || fail 'live autologin does not wait for the Firewalld startup attempt'
grep -Fq "depends=('dinit' 'seatd' 'firewalld-dinit')" "$pkgbuild" \
  || fail 'live autologin dependencies must be dinit, seatd and firewalld-dinit only'
grep -Fq "'firewalld-dinit'" "$pkgbuild" \
  || fail 'live autologin package does not declare its Firewalld service dependency'
! grep -Fqx 'depends-on = local.target artix-live' "$service" \
  || fail 'live hostname service combines dependencies into one unresolved service name'
grep -Fq 'before = greetd' "$service" || fail 'live autologin service does not precede greetd'
grep -Fq 'before = login.target' "$service" || fail 'live autologin service does not precede the login target'
grep -Fqx 'type = scripted' "$live_greetd" \
  || fail 'live greetd shadow is not a scripted no-op service'
grep -Fqx 'command = /bin/true' "$live_greetd" \
  || fail 'live greetd shadow does not disable the display manager'
session_service="$package_dir/dinx-live-session.service"
session_launcher="$package_dir/dinx-live-session"
[[ -r "$session_service" && -r "$session_launcher" ]] || fail 'live session service or launcher is missing'
[[ -x "$session_launcher" ]] || fail 'live session launcher is not executable'
sh -n "$session_launcher" || fail 'live session launcher has invalid shell syntax'
grep -Fqx 'type = process' "$session_service" \
  || fail 'live session service is not a process service'
grep -Fqx 'command = /usr/local/libexec/dinx-live-session' "$session_service" \
  || fail 'live session service command is incorrect'
grep -Fqx 'depends-on = seatd' "$session_service" \
  || fail 'live session does not wait for the seatd seat manager'
grep -Fqx 'depends-on = dinx-live-autologin' "$session_service" \
  || fail 'live session does not wait for live boot preparation'
grep -Fq 'runuser -u dinx' "$session_launcher" \
  || fail 'live session does not start as the dinx user'
grep -Fq 'DINX_LIVE_SESSION=1' "$session_launcher" \
  || fail 'live session launcher does not mark the session as live'
grep -Fq 'dbus-run-session /usr/local/libexec/dinx-aqueous-pearl' "$session_launcher" \
  || fail 'live session launcher does not start the Aqueous/Pearl wrapper'
grep -Fq 'XDG_RUNTIME_DIR=/run/dinx-session' "$session_launcher" \
  || fail 'live session launcher does not select the private runtime dir'
grep -Fq 'boot.d/dinx-live-session' "$pkgbuild" \
  || fail 'live session service is not linked into dinit boot'
grep -Fqx 'type = process' "$live_overlay/etc/dinit.d/seatd" \
  || fail 'live seatd service is not a process service'
grep -Fqx 'command = /usr/bin/seatd -g seat' "$live_overlay/etc/dinit.d/seatd" \
  || fail 'live seatd service does not serve the seat group socket'
grep -Fq '$1 == "seat"' "$wrapper" \
  || fail 'live boot helper does not grant the dinx user seatd access'
grep -Fq 'while [ ! -S /run/seatd.sock ]' "$wrapper" \
  || fail 'live autologin helper does not wait for the seatd socket before the session starts'
grep -Fq 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "$wrapper" \
  || fail 'live autologin helper does not set an explicit PATH for dinit service execution'
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
grep -Fqx 'type             = process' "$root_greetd_service" \
  || fail 'installed greetd override is not a process service'
grep -Fqx 'command          = /usr/bin/greetd' "$root_greetd_service" \
  || fail 'installed greetd override does not start greetd'
grep -Fqx 'smooth-recovery  = true' "$root_greetd_service" \
  || fail 'installed greetd override does not preserve smooth recovery'
grep -Fqx 'restart-delay    = 7' "$root_greetd_service" \
  || fail 'installed greetd override does not wait for Pearl Greeter teardown'
grep -Fqx 'depends-on       = login.target' "$root_greetd_service" \
  || fail 'installed greetd override dropped its login target dependency'
! grep -Fq 'dinx-live-autologin' "$root_greetd_service" \
  || fail 'live-only autologin dependency leaked into the installed greetd service'
[[ ! -e "$root_policy" ]] \
  || fail 'live-only Polkit authorization leaked into the installed rootfs overlay'
grep -Fq 'subject.user === "dinx"' "$live_policy" \
  || fail 'live Polkit rule is not scoped to the dinx live user'
if grep -Eq 'subject\.(active|local)' "$live_policy"; then
  fail 'live Polkit rule still requires elogind session state'
fi
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

printf 'dinx_live_autologin_contract live=true direct_session=true seatd=true private_runtime_dir=true greeter_installed_only=true keyring_independent=true render_group=true live_root_overrides=true installed_rootfs_clean=true polkit_live_only=true dinit=true\n'
