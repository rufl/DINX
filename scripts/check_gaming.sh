#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-gaming"
desktop="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions/dinx-gaming.desktop"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
workflow="$root/.github/workflows/p0-iso.yml"
iso_check="$root/scripts/check-iso-content.sh"

fail() {
  printf 'check_gaming: %s\n' "$*" >&2
  exit 1
}

for path in "$session" "$desktop" "$profile" "$workflow" "$iso_check"; do
  [[ -r "$path" ]] || fail "missing $path"
done

[[ -x "$session" ]] || fail 'gaming launcher is not executable'
grep -Fq 'XDG_CURRENT_DESKTOP=DINX-Gaming' "$session" || fail 'gaming desktop identity is missing'
grep -Fq 'SDL_VIDEODRIVER=wayland' "$session" || fail 'Wayland client contract is missing'
grep -Fq 'DINX_GAMEMODE' "$session" || fail 'GameMode control is missing'
grep -Fq 'DINX_MANGOHUD' "$session" || fail 'MangoHud control is missing'
grep -Fq 'dinitui --gaming-enter' "$session" || fail 'Gaming launcher does not enter the transactional profile'
grep -Fq 'dinitui --gaming-leave' "$session" || fail 'Gaming launcher does not restore the transactional profile'
grep -Fq 'failed to enter Gaming profile' "$session" || fail 'Gaming entry failures are not surfaced'
grep -Fq 'failed to restore the previous profile' "$session" || fail 'Gaming restoration failures are not surfaced'
grep -Fq 'DINX_GAMING_CHILD_MODE=1 setsid "$0"' "$session" || fail 'Gamescope is not isolated in a signal-safe process group'
grep -Fq 'kill -TERM "-$game_pid"' "$session" || fail 'Gaming shutdown does not terminate the Gamescope process group'

if grep -Fq 'dinitui --gaming-leave >/dev/null 2>&1 || true' "$session"; then
  fail 'Gaming restoration failures are ignored'
fi
grep -Fq 'gamescope --backend drm --steam --fullscreen -- steam -tenfoot' "$session" || fail 'Gamescope Steam command is not the standalone session contract'
if grep -Eq 'systemctl|/bin/sh -c|dbus-daemon' "$session"; then
  fail 'gaming launcher contains an init or shell indirection'
fi

grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-gaming' "$desktop" || fail 'gaming session desktop command is incorrect'
grep -Fq 'TryExec=/usr/local/libexec/dinx-gaming' "$desktop" || fail 'gaming session TryExec is missing'
grep -Fq 'Name=DINX Gaming' "$desktop" || fail 'gaming session name is missing from desktop metadata'

for package in gamescope gamemode mangohud steam steam-devices lib32-gamemode lib32-mesa lib32-vulkan-radeon lib32-vulkan-mesa-layers; do
  grep -Fqx "    - $package" "$profile" || fail "DINX profile is missing $package"
done

grep -Fq 'scripts/check_gaming.sh' "$workflow" || fail 'workflow does not run the gaming contract gate'
grep -Fq 'scripts/gaming_p5_qualification.sh' "$workflow" || fail 'workflow trigger does not include gaming qualification changes'
grep -Fq "gamescope \\" "$workflow" || fail 'ISO builder does not install Gamescope for qualification'
grep -Fq '[lib32]' "$workflow" || fail 'ISO builder does not enable the Artix lib32 repository'
grep -Fq 'usr/local/libexec/dinx-gaming' "$iso_check" || fail 'ISO payload check does not require the gaming launcher'
grep -Fq 'usr/share/wayland-sessions/dinx-gaming.desktop' "$iso_check" || fail 'ISO payload check does not require the gaming session'
grep -Fq 'usr/bin/gamescope' "$iso_check" || fail 'ISO payload check does not require Gamescope'
grep -Fq 'usr/bin/gamemoderun' "$iso_check" || fail 'ISO payload check does not require GameMode'
grep -Fq 'usr/bin/mangohud' "$iso_check" || fail 'ISO payload check does not require MangoHud'
grep -Fq 'usr/bin/steam' "$iso_check" || fail 'ISO payload check does not require Steam'

printf 'gaming_contract session=true gamescope=true steam=true multilib=true wayland_session=true profile_transaction=true signal_cleanup=true\n'
