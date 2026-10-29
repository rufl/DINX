#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-gaming"
desktop="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions/dinx-gaming.desktop"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
manifest="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
smoke="$root/scripts/gaming_p5_qualification.sh"
workflow="$root/.github/workflows/p0-iso.yml"
iso_check="$root/scripts/check-iso-content.sh"

fail() {
  printf 'check_gaming: %s\n' "$*" >&2
  exit 1
}

for path in "$session" "$desktop" "$profile" "$manifest" "$smoke" "$workflow" "$iso_check"; do
  [[ -r "$path" ]] || fail "missing $path"
done

command -v jq >/dev/null 2>&1 || fail 'jq is not installed'

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
grep -Fq 'for required in gamescope steam' "$session" || fail 'launcher does not preflight required gaming packages'
grep -Fq 'command -v "$required"' "$session" || fail 'launcher does not check each required gaming command'
grep -Fq 'optional DINX gaming packages' "$session" || fail 'missing-package guidance is absent'

if grep -Eq 'systemctl|/bin/sh -c|dbus-daemon' "$session"; then
  fail 'gaming launcher contains an init or shell indirection'
fi

grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-gaming' "$desktop" || fail 'gaming session desktop command is incorrect'
grep -Fq 'TryExec=/usr/local/libexec/dinx-gaming' "$desktop" || fail 'gaming session TryExec is missing'
grep -Fq 'Name=DINX Gaming' "$desktop" || fail 'gaming session name is missing from desktop metadata'
grep -Fq 'Hidden=true' "$desktop" || fail 'gaming session is not hidden from the default greeter'
grep -Fq 'NoDisplay=true' "$desktop" || fail 'gaming session remains selectable'

jq -e '
  .groups.gaming.iso == false and
  .groups.gaming.external == true and
  .groups.gaming.packages == [
    "gamescope",
    "gamemode",
    "mangohud",
    "steam",
    "steam-devices",
    "lib32-gamemode",
    "lib32-mesa",
    "lib32-vulkan-radeon",
    "lib32-vulkan-mesa-layers"
  ] and
  (.groups.foundation.packages | index("vulkan-radeon") != null) and
  (.groups.foundation.packages | index("vulkan-tools") != null)
' "$manifest" >/dev/null || fail 'optional gaming group or base Vulkan package boundary is incorrect'

for package in gamescope gamemode mangohud steam steam-devices lib32-gamemode lib32-mesa lib32-vulkan-radeon lib32-vulkan-mesa-layers; do
  if grep -Fqx "    - $package" "$profile"; then
    fail "optional gaming package remains in the base ISO profile: $package"
  fi
done
grep -Fqx '    - vulkan-radeon' "$profile" || fail 'base RADV driver was removed'
grep -Fqx '    - vulkan-tools' "$profile" || fail 'base Vulkan diagnostics were removed'

grep -Fq 'scripts/check_gaming.sh' "$workflow" || fail 'workflow does not run the gaming contract gate'
grep -Fq 'scripts/gaming_p5_qualification.sh' "$workflow" || fail 'workflow trigger does not include gaming qualification changes'
grep -Fq "gamescope \\" "$workflow" || fail 'ISO builder does not install Gamescope for qualification'
if grep -Fq '[lib32]' "$workflow"; then
  fail 'ISO builder still enables Artix lib32 for the base image'
fi
grep -Fq 'usr/local/libexec/dinx-gaming' "$iso_check" || fail 'ISO payload check does not require the hidden launcher'
grep -Fq 'usr/share/wayland-sessions/dinx-gaming.desktop' "$iso_check" || fail 'ISO payload check does not require the hidden session entry'
for optional_path in usr/bin/gamescope usr/bin/gamemoderun usr/bin/mangohud usr/bin/steam; do
  grep -Fq "$optional_path" "$iso_check" || fail "ISO payload check does not exclude $optional_path"
done
grep -Fq '(gamescope|gamemode|mangohud|steam(-devices)?|lib32-(gamemode|mesa|vulkan-radeon|vulkan-mesa-layers))' "$iso_check" || fail 'ISO payload check does not exclude optional gaming package metadata'
grep -Fq 'missing-gamescope' "$smoke" || fail 'gaming smoke does not check a missing Gamescope package'
grep -Fq 'missing-steam' "$smoke" || fail 'gaming smoke does not check a missing Steam package'

printf 'gaming_contract session=true optional_packages=true base_vulkan=true lib32_repository=not_enabled missing_dependencies=fail_closed=true\n'
