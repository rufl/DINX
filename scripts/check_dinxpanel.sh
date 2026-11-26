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
builder="$root/scripts/build-iso-container.sh"
bluetooth_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-bluetooth-manager"
theme_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-set-theme"
desktop_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-pcmanfm-desktop"
fail() {
  printf 'check_dinxpanel: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$frontend" "$optional_packages" "$kernels" "$desktop" "$readme" "$profile" "$workflow" "$theme_helper" "$desktop_helper"; do
  [[ -r "$path" ]] || fail "missing $path"
done

grep -Fqx 'pkgname=dinxpanel' "$pkgbuild" || fail 'PKGBUILD package name is not dinxpanel'
grep -Fq 'depends=(gtk4 libadwaita dinitui pacman deetty nano inxi nm-connection-editor blueman pwvucontrol qt6ct firewalld firewall-config firewalld-dinit topgrade shelly brightnessctl swaylock wdisplays mission-center pcmanfm pori gparted file-roller networkmanager pipewire usbutils upower elogind)' "$pkgbuild" || fail 'runtime dependency contract is incomplete'
grep -Fq 'zig_target_flags=(-Dcpu=baseline)' "$pkgbuild" \
  || fail 'DINXPanel build target must be generic x86_64 GNU/Linux'
grep -Fq 'zig build "${zig_target_flags[@]}" -Doptimize=ReleaseSafe' "$pkgbuild" \
  || fail 'DINXPanel package build must use the generic target flags'
grep -Fq "cups-dinit: optional CUPS printing support; downloads cups and dinit service files after installation" "$pkgbuild" || fail 'optional CUPS package metadata is missing'
if grep -Fq 'wdisplays: Wayland display control panel' "$pkgbuild"; then
  fail 'wdisplays must be a runtime dependency now that the display control is in the base ISO'
fi
grep -Fq 'Exec=dinxpanel' "$desktop" || fail 'desktop launcher is incorrect'
grep -Fqx 'Name[pt_BR]=Central de Controle' "$desktop" || fail 'localized desktop name is incorrect'
grep -Fq 'Icon=org.dinx.DinxPanel' "$desktop" || fail 'desktop icon is missing'
grep -Fq '    - dinxpanel' "$profile" || fail 'DINX profile does not install dinxpanel'
[[ -x "$bluetooth_helper" ]] || fail "desktop helper is missing or not executable: $bluetooth_helper"
[[ -x "$theme_helper" && -x "$desktop_helper" ]] || fail 'appearance helpers are missing or not executable'
sh -n "$bluetooth_helper" "$theme_helper" "$desktop_helper" || fail 'DINX desktop helper has invalid shell syntax'
grep -Fq 'build_package dinxpanel' "$builder" || fail 'ISO builder does not build dinxpanel'
pori_build_line=$(grep -nF 'build_package pori' "$builder" | head -n1 | cut -d: -f1) || fail 'ISO builder does not build pori'
mission_center_build_line=$(grep -nF 'build_package mission-center' "$builder" | head -n1 | cut -d: -f1) || fail 'ISO builder does not build mission-center'
panel_build_line=$(grep -nF 'build_package dinxpanel' "$builder" | head -n1 | cut -d: -f1) || fail 'ISO builder does not build dinxpanel'
(( pori_build_line < panel_build_line && mission_center_build_line < panel_build_line )) \
  || fail 'ISO builder installs DINXPanel before its system-tool runtime dependencies'
for button in 'GPU drivers' 'Install GPU plan' 'Network' 'Bluetooth' 'Dinit services' 'Firewall' 'Display' 'Check upgrades' 'Topgrade preview' 'Topgrade' 'Shelly upgrade' 'Install CUPS' 'Install kernel' 'Brightness down' 'Brightness up' 'Lock screen' 'System monitor' 'File manager' 'PCManFM desktop preferences' 'Disks & mounts' 'Partition editor' 'Archive manager' 'Session diagnostics' 'Hardware qualification report' 'USB devices' 'Network diagnostics' 'Audio diagnostics' 'Power & battery status' 'Suspend' 'Restart' 'Power off' 'DINX tools' 'Open Deetty' 'Open Dintor' 'Refresh DINX Dock' 'Apply dark session theme' 'Apply light session theme' 'Choose wallpaper' 'Show desktop icons' 'Hide desktop icons'; do
  grep -Fq "$button" "$frontend" || fail "DINXPanel button is missing: $button"
done
grep -Fq 'gtk_label_new("Control Panel")' "$frontend" || fail 'DINXPanel cleaned heading is missing'
grep -Fq 'gtk_list_box_new' "$frontend" || fail 'DINXPanel left navigation is missing'
grep -Fq 'gtk_stack_new' "$frontend" || fail 'DINXPanel right content stack is missing'
grep -Fq 'gtk_stack_add_titled' "$frontend" || fail 'DINXPanel content pages are missing'
grep -Fq 'dinx-sidebar' "$frontend" || fail 'DINXPanel sidebar styling is missing'
grep -Fq 'dinx-page' "$frontend" || fail 'DINXPanel page styling is missing'
grep -Fq 'gtk_search_entry_new' "$frontend" || fail 'DINXPanel settings search is missing'
grep -Fq 'onNavigationSearchChanged' "$frontend" || fail 'DINXPanel settings search callback is missing'
grep -Fq 'No matching settings' "$frontend" || fail 'DINXPanel empty search state is missing'
grep -Fq 'onRedbeanSettingsClicked' "$frontend" || fail 'Redbean persistence action is missing'
grep -Fq '.config/dinx/redbean.json' "$frontend" || fail 'Redbean settings path is missing'
grep -Fq 'onDockRefreshClicked' "$frontend" || fail 'DINX Dock refresh action is missing'
grep -Fq 'pkill", "-HUP", "dinx-dock' "$frontend" || fail 'DINX Dock refresh does not use the fixed signal argv'
grep -Fq 'onKwmConfigClicked' "$frontend" || fail 'KWM persistence action is missing'
grep -Fq '.config/kwm/config.zon' "$frontend" || fail 'KWM settings path is missing'
grep -Fq 'dinx-set-theme' "$frontend" || fail 'persistent session theme action is missing'
grep -Fq 'dinx-pcmanfm-desktop' "$frontend" || fail 'persistent PCManFM desktop toggle is missing'
grep -Fq 'gtk_file_dialog_open' "$frontend" || fail 'wallpaper chooser is missing'
grep -Fq '"pcmanfm", "-w"' "$frontend" || fail 'wallpaper action does not use PCManFM'
grep -Fq 'dinx-sync-session-theme' "$frontend" || fail 'session theme refresh action is missing'
grep -Fq 'ADW_COLOR_SCHEME_FORCE_DARK' "$frontend" || fail 'DINXPanel dark mode is missing'
grep -Fq '@accent_bg_color' "$frontend" || fail 'DINXPanel semantic theme roles are missing'
if grep -Eq 'background(-color)?:[[:space:]]*#[0-9A-Fa-f]{6}' "$frontend"; then
  fail 'DINXPanel uses hard-coded background colors instead of theme roles'
fi
if grep -Fq 'YaST-inspired' "$frontend"; then
  fail 'DINXPanel still exposes the retired YaST-inspired subtitle'
fi
grep -Fq 'dinx-wdisplays' "$frontend" || fail 'display action does not use the DINX persistence wrapper'
if grep -Fq 'launch(&.{"wdisplays"})' "$frontend"; then
  fail 'display action bypasses the DINX persistence wrapper'
fi
grep -Fq 'launch(&.{"/usr/local/libexec/dinx-bluetooth-manager"})' "$frontend" || fail 'Bluetooth action does not use the DINX adapter-aware launcher'
grep -Fq 'launch(&.{"firewall-config"})' "$frontend" || fail 'Firewall action does not launch firewall-config'
grep -Fq 'launch(&.{"/usr/local/libexec/dinx-lock"})' "$frontend" || fail 'lock action does not use the DINX session helper'
for direct_call in \
  'launch(&.{"missioncenter"})' \
  'launch(&.{"pcmanfm"})' \
  'launch(&.{"pori"})' \
  'launch(&.{"gparted"})' \
  'launch(&.{"file-roller"})'; do
  grep -Fq "$direct_call" "$frontend" || fail "system tool action is missing: $direct_call"
done
grep -Fq 'requestPowerAction' "$frontend" || fail 'power actions do not use the confirmation flow'
grep -Fq 'adw_alert_dialog_new' "$frontend" || fail 'power actions lack an Adwaita confirmation dialog'
grep -Fq 'ADW_RESPONSE_DESTRUCTIVE' "$frontend" || fail 'destructive power response is not marked'
for power_call in \
  'launch(&.{ "loginctl", "suspend" })' \
  'launch(&.{ "loginctl", "reboot" })' \
  'launch(&.{ "loginctl", "poweroff" })'; do
  grep -Fq "$power_call" "$frontend" || fail "power action is missing: $power_call"
done
grep -Fq 'dinitui_command = command' "$frontend" || fail 'GPU command is not retained for the asynchronous task'
grep -Fq 'const argv = [_][]const u8{ "dinitui", task.dinitui_command }' "$frontend" || fail 'GPU workflow is not delegated through fixed dinitui argv'
grep -Fq -- '--gpu-status' "$frontend" || fail 'GPU detection action is missing'
grep -Fq -- '--install-gpu-drivers' "$frontend" || fail 'GPU installation action is missing'
# The upgrade report is read-only: checkupdates (pacman-contrib) covers the
# official repositories and paru -Qu covers the AUR. Octopi is the interactive
# package manager and has no CLI, so it is launched as an app, not queried here.
grep -Fq '"checkupdates"' "$frontend" || fail 'official-repository update discovery is missing'
grep -Fq '"paru", "-Qu"' "$frontend" || fail 'AUR update discovery is missing'
if grep -Fq 'shelly' "$frontend"; then
  fail 'DINXPanel still invokes the retired Shelly upgrade workflow'
fi
grep -Fq '"fwupdmgr", "refresh"' "$frontend" || fail 'fwupd metadata refresh is missing'
grep -Fq '"fwupdmgr", "get-updates"' "$frontend" || fail 'firmware update discovery is missing'
for terminal_call in \
  '"deetty", "-e", "topgrade", "--dry-run"' \
  '"deetty", "-e", "topgrade"' \
  '"deetty", "-e", "shelly", "upgrade", "all"' \
  '"deetty", "-e", "inxi", "-GSC"' \
  '"deetty", "-e", "dinx-doctor"' \
  '"deetty", "-e", "lsusb"' \
  '"deetty", "-e", "nmcli", "device", "status"' \
  '"deetty", "-e", "wpctl", "status"' \
  '"deetty", "-e", "upower", "-d"' \
  '"deetty", "-e", "dinx-alpha7-hardware-report"'; do
  grep -Fq "$terminal_call" "$frontend" || fail "terminal action does not use Deetty with fixed argv: $terminal_call"
done
if grep -Eq '"(foot|ghostty)"' "$frontend"; then
  fail 'DINXPanel launches a removed terminal emulator'
fi
grep -Fq 'optional_packages.install' "$frontend" || fail 'CUPS download is not wired to the optional package installer'
grep -Fq 'optional_package_install' "$frontend" || fail 'CUPS installation is not isolated in the asynchronous package task'
grep -Fq 'pub const cups_user_install_argv' "$optional_packages" || fail 'CUPS non-root package argv is missing'
grep -Fq 'pub const cups_install_argv' "$optional_packages" || fail 'CUPS pkexec package argv is missing'
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

printf 'dinxpanel_contract package=true shortcuts=true upgrades=true firmware=true search=true qualification_report=true system_tools=true diagnostics=true power=true confirmations=true privilege_fallback=true gpu_bridge=true kernels=true argv_safe=true shell_integrations=true appearance_controls=true wallpaper=true no_removal=true\n'
