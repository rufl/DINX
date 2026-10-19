#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
mango="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/mango/dinx.conf"
noctalia="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/noctalia/config.toml"
lock="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-lock"
idle="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-idle"
desktop="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/dinx-lock.desktop"

fail() {
  printf 'check_dinx_session: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$mango" "$noctalia" "$lock" "$idle" "$desktop"; do
  [[ -r "$path" ]] || fail "missing $path"
done
[[ -x "$lock" ]] || fail 'lock wrapper is not executable'
[[ -x "$idle" ]] || fail 'idle wrapper is not executable'

for package in brightnessctl swayidle swaylock; do
  grep -Fq "    - $package" "$profile" || fail "profile is missing $package"
done

grep -Fq 'exec_once=/usr/local/libexec/dinx-idle' "$mango" || fail 'idle manager is not started by the DINX session'
grep -Fq 'bind=SUPER,l,spawn,/usr/local/libexec/dinx-lock' "$mango" || fail 'Super+L lock shortcut is missing'
grep -Fq 'bind=XF86MonBrightnessDown,spawn,brightnessctl set 5%-' "$mango" || fail 'brightness-down shortcut is missing'
grep -Fq 'bind=XF86MonBrightnessUp,spawn,brightnessctl set 5%+' "$mango" || fail 'brightness-up shortcut is missing'
grep -Fq 'timeout 600 /usr/local/libexec/dinx-lock' "$idle" || fail 'idle lock timeout is missing'
grep -Fq 'before-sleep /usr/local/libexec/dinx-lock' "$idle" || fail 'lock-before-suspend hook is missing'
grep -Fq 'Exec=/usr/local/libexec/dinx-lock' "$desktop" || fail 'launcher lock action is missing'
grep -Fq 'TryExec=/usr/local/libexec/dinx-lock' "$desktop" || fail 'launcher lock TryExec is missing'
grep -Fq 'type = "power_profile"' "$noctalia" || fail 'Noctalia power-profile shortcut is missing'
grep -Fq 'control-center", "session"]' "$noctalia" || fail 'Noctalia session power widget is missing'
grep -Fq 'pinned = ["firefox", "dinxpanel", "dinitui"' "$noctalia" || fail 'primary DINX hierarchy is not pinned in the dock'
grep -Fq 'end = ["screenshot", "clipboard", "tray", "network"' "$noctalia" || fail 'Noctalia status tray widget is missing from the main bar'
grep -Fq '[widget.tray]' "$noctalia" || fail 'Noctalia tray widget settings are missing'
grep -Fq 'drawer = true' "$noctalia" || fail 'Noctalia tray drawer is not enabled'
grep -Fq '    - libayatana-appindicator' "$profile" || fail 'profile is missing AppIndicator compatibility'

dock_line=$(grep -F 'pinned =' "$noctalia")
for specialist in swayimg vlc org.strawberrymusicplayer.strawberry gufw qps opensnitch_ui nm-connection-editor blueman-manager com.shellyorg.shelly; do
  if grep -Fq "\"$specialist\"" <<<"$dock_line"; then
    fail "specialist launcher remains pinned in the dock: $specialist"
  fi
done

if grep -Eq '/bin/sh -c|systemctl|loginctl suspend' "$lock" "$idle"; then
  fail 'session wrappers contain forbidden shell indirection or systemd suspend calls'
fi

printf 'dinx_session_contract lock=true idle=true before_suspend=true brightness=true energy=true launcher=true hierarchy=true\n'
