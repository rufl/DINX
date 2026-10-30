#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pkg_dir="$root/distro/packages/dinxpanel"
pkgbuild="$pkg_dir/PKGBUILD"
frontend="$pkg_dir/src/main.zig"
optional_packages="$pkg_dir/src/optional_packages.zig"
kernels="$pkg_dir/src/kernels.zig"
desktop="$pkg_dir/resources/dinxpanel.desktop"
readme="$pkg_dir/README.md"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
workflow="$root/.github/workflows/p0-iso.yml"
fail() {
  printf 'check_dinxpanel: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$frontend" "$optional_packages" "$kernels" "$desktop" "$readme" "$profile" "$workflow"; do
  [[ -r "$path" ]] || fail "missing $path"
done

grep -Fqx 'pkgname=dinxpanel' "$pkgbuild" || fail 'PKGBUILD package name is not dinxpanel'
grep -Fq 'depends=(gtk4 libadwaita dinitui pacman deetty nano inxi nm-connection-editor blueman pwvucontrol qt6ct gufw topgrade shelly brightnessctl swaylock wdisplays)' "$pkgbuild" || fail 'runtime dependency contract is incomplete'
grep -Fq "cups-dinit: optional CUPS printing support; downloads cups and dinit service files after installation" "$pkgbuild" || fail 'optional CUPS package metadata is missing'
if grep -Fq 'wdisplays: Wayland display control panel' "$pkgbuild"; then
  fail 'wdisplays must be a runtime dependency now that the display control is in the base ISO'
fi
grep -Fq 'Exec=dinxpanel' "$desktop" || fail 'desktop launcher is incorrect'
grep -Fqx 'Name[pt_BR]=Central de Controle' "$desktop" || fail 'localized desktop name is incorrect'
grep -Fq 'Icon=org.dinx.DinxPanel' "$desktop" || fail 'desktop icon is missing'
grep -Fq '    - dinxpanel' "$profile" || fail 'DINX profile does not install dinxpanel'
grep -Fq 'build_package dinxpanel' "$workflow" || fail 'ISO workflow does not build dinxpanel'
for button in 'GPU drivers' 'Install GPU plan' 'Network' 'Bluetooth' 'Dinit services' 'Display' 'Check upgrades' 'Topgrade preview' 'Topgrade' 'Shelly upgrade' 'Install CUPS' 'Kernel installer' 'Brightness down' 'Brightness up' 'Lock screen'; do
  grep -Fq "$button" "$frontend" || fail "DINXPanel button is missing: $button"
done
grep -Fq 'dinx-wdisplays' "$frontend" || fail 'display action does not use the DINX persistence wrapper'
if grep -Fq 'launch(&.{"wdisplays"})' "$frontend"; then
  fail 'display action bypasses the DINX persistence wrapper'
fi
grep -Fq 'dinitui_command = command' "$frontend" || fail 'GPU command is not retained for the asynchronous task'
grep -Fq 'const argv = [_][]const u8{ "dinitui", task.dinitui_command }' "$frontend" || fail 'GPU workflow is not delegated through fixed dinitui argv'
grep -Fq -- '--gpu-status' "$frontend" || fail 'GPU detection action is missing'
grep -Fq -- '--install-gpu-drivers' "$frontend" || fail 'GPU installation action is missing'
grep -Fq '"shelly", "sync"' "$frontend" || fail 'Shelly metadata refresh is missing'
grep -Fq '"shelly", "list-updates", "all"' "$frontend" || fail 'Shelly update discovery is missing'
grep -Fq '"shelly", "upgrade", "all"' "$frontend" || fail 'Shelly upgrade action is missing'
grep -Fq '"fwupdmgr", "refresh"' "$frontend" || fail 'fwupd metadata refresh is missing'
grep -Fq '"fwupdmgr", "get-updates"' "$frontend" || fail 'firmware update discovery is missing'
grep -Fq '"topgrade", "--dry-run", "--show-skipped", "--no-self-update", "--no-tmux"' "$frontend" || fail 'Topgrade preview is missing'
for terminal_call in \
  '"deetty", "-e", "topgrade", "--dry-run"' \
  '"deetty", "-e", "topgrade"' \
  '"deetty", "-e", "shelly", "upgrade", "all"' \
  '"deetty", "-e", "inxi", "-GSC"'; do
  grep -Fq "$terminal_call" "$frontend" || fail "terminal action does not use Deetty with fixed argv: $terminal_call"
done
if grep -Eq '"(foot|ghostty)"' "$frontend"; then
  fail 'DINXPanel launches a removed terminal emulator'
fi
grep -Fq 'optional_packages.install' "$frontend" || fail 'CUPS download is not wired to the optional package installer'
grep -Fq 'optional_package_install' "$frontend" || fail 'CUPS installation is not isolated in the asynchronous package task'
grep -Fq 'pub const cups_user_install_argv' "$optional_packages" || fail 'CUPS non-root package argv is missing'
grep -Fq 'pub const cups_install_argv' "$optional_packages" || fail 'CUPS pkexec package argv is missing'
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

printf 'dinxpanel_contract package=true shortcuts=true upgrades=true firmware=true optional_cups=true privilege_fallback=true gpu_bridge=true kernels=true argv_safe=true no_removal=true\n'
