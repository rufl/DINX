#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pkg_dir="$root/distro/packages/dinxpanel"
pkgbuild="$pkg_dir/PKGBUILD"
frontend="$pkg_dir/src/main.zig"
kernels="$pkg_dir/src/kernels.zig"
desktop="$pkg_dir/resources/dinxpanel.desktop"
readme="$pkg_dir/README.md"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
workflow="$root/.github/workflows/p0-iso.yml"
fail() {
  printf 'check_dinxpanel: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$frontend" "$kernels" "$desktop" "$readme" "$profile" "$workflow"; do
  [[ -r "$path" ]] || fail "missing $path"
done

grep -Fqx 'pkgname=dinxpanel' "$pkgbuild" || fail 'PKGBUILD package name is not dinxpanel'
grep -Fq 'depends=(gtk4 libadwaita dinitui pacman foot nano inxi nm-connection-editor blueman pwvucontrol qt6ct gufw topgrade shelly brightnessctl swaylock)' "$pkgbuild" || fail 'runtime dependency contract is incomplete'
grep -Fq "fwupd: firmware metadata and update checks" "$pkgbuild" || fail 'optional firmware integration is missing'
grep -Fq 'makedepends=(zig)' "$pkgbuild" || fail 'Zig build dependency is missing'
grep -Fq 'Exec=dinxpanel' "$desktop" || fail 'desktop launcher is incorrect'
grep -Fq 'Icon=org.dinx.DinxPanel' "$desktop" || fail 'desktop icon is missing'
grep -Fq '    - dinxpanel' "$profile" || fail 'DINX profile does not install dinxpanel'
grep -Fq 'build_package dinxpanel' "$workflow" || fail 'ISO workflow does not build dinxpanel'
for button in 'GPU drivers' 'Install GPU plan' 'Network' 'Bluetooth' 'Dinit services' 'Display' 'MangoWC options' 'Check upgrades' 'Topgrade preview' 'Topgrade' 'Shelly upgrade' 'Kernel installer' 'Brightness down' 'Brightness up' 'Lock screen'; do
  grep -Fq "$button" "$frontend" || fail "DINXPanel button is missing: $button"
done
grep -Fq 'dinitui", command' "$frontend" || fail 'GPU workflow is not delegated through fixed dinitui argv'
grep -Fq -- '--gpu-status' "$frontend" || fail 'GPU detection action is missing'
grep -Fq -- '--install-gpu-drivers' "$frontend" || fail 'GPU installation action is missing'
grep -Fq '"shelly", "sync"' "$frontend" || fail 'Shelly metadata refresh is missing'
grep -Fq '"shelly", "list-updates", "all"' "$frontend" || fail 'Shelly update discovery is missing'
grep -Fq '"shelly", "upgrade", "all"' "$frontend" || fail 'Shelly upgrade action is missing'
grep -Fq '"fwupdmgr", "refresh"' "$frontend" || fail 'fwupd metadata refresh is missing'
grep -Fq '"fwupdmgr", "get-updates"' "$frontend" || fail 'firmware update discovery is missing'
grep -Fq '"topgrade", "--dry-run", "--show-skipped", "--no-self-update", "--no-tmux"' "$frontend" || fail 'Topgrade preview is missing'
grep -Fq '"topgrade" });' "$frontend" || fail 'Topgrade action is missing'
for kernel in linux linux-lts linux-zen linux-hardened; do
  grep -Fq ".id = \"$kernel\"" "$kernels" || fail "kernel catalog is missing $kernel"
done
grep -Fq 'kernel operations install packages and headers but never remove' "$readme" || fail 'kernel safety policy is undocumented'
grep -Fq 'rollback' "$readme" || fail 'kernel rollback policy is undocumented'
grep -Fq 'Firmware discovery uses' "$readme" || fail 'firmware update policy is undocumented'
grep -Fq 'g_spawn_async' "$frontend" || fail 'panel launch path is not argv-based'
grep -Fq 'std.Thread.spawn' "$frontend" || fail 'blocking panel operations are not moved off the GTK thread'
grep -Fq 'g_idle_add' "$frontend" || fail 'panel worker results are not marshalled to the GTK thread'
grep -Fq 'active_tasks' "$frontend" || fail 'panel task lifetime guard is missing'
grep -Fq 'kernel_status_completed' "$frontend" || fail 'panel smoke completion state is missing'
grep -Fq 'dinxpanel_smoke surface=true kernel_status=' "$frontend" || fail 'panel smoke output contract is missing'
if grep -Eq '/bin/sh|systemctl|g_spawn_command_line' "$frontend" "$kernels"; then
  fail 'DINXPanel contains shell/systemd or command-line-string execution'
fi

printf 'dinxpanel_contract package=true shortcuts=true upgrades=true firmware=true gpu_bridge=true kernels=true argv_safe=true no_removal=true\n'
