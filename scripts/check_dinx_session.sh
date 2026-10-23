#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
labwc="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/labwc/rc.xml"
autostart="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/labwc/autostart"
wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-labwc"
aqueous_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-pearl"
aqueous_init="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-init"
session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions/dinx-labwc.desktop"
aqueous_session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions/dinx-aqueous-pearl.desktop"
noctalia="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/noctalia/config.toml"
lock="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-lock"
idle="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-idle"
desktop="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/dinx-lock.desktop"
architecture="$root/docs/architecture.md"
compatibility="$root/docs/compatibility.md"
pt_architecture="$root/docs/pt-BR/architecture.md"
pt_compatibility="$root/docs/pt-BR/compatibility.md"
shell_profile="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/profile.d/dinx.sh"
fish_config="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/fish/config.fish"
useradd_defaults="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/default/useradd"
users_conf="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/modules/users.conf"
labwc_environment="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/labwc/environment"



fail() {
  printf 'check_dinx_session: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$labwc" "$autostart" "$wrapper" "$aqueous_wrapper" "$aqueous_init" "$session" "$aqueous_session" "$noctalia" "$lock" "$idle" "$desktop" "$shell_profile" "$fish_config" "$useradd_defaults" "$users_conf" "$labwc_environment"; do
  [[ -r "$path" ]] || fail "missing $path"
done
[[ -x "$lock" ]] || fail 'lock wrapper is not executable'
[[ -x "$idle" ]] || fail 'idle wrapper is not executable'

for package in labwc brightnessctl swayidle swaylock fish aqueous pearl; do
  grep -Fq "    - $package" "$profile" || fail "profile is missing $package"
done
for package in aqueous-core aqueous-session; do
  if grep -Fqx "    - $package" "$profile"; then
    fail "obsolete split Aqueous package remains in the profile: $package"
  fi
done
grep -Fq 'export SHELL=/bin/fish' "$shell_profile" || fail 'POSIX shell default is not Fish'
grep -Fq 'set -gx SHELL /bin/fish' "$fish_config" || fail 'Fish system shell default is missing'
grep -Fq 'SHELL=/bin/fish' "$useradd_defaults" || fail 'new-user shell default is not Fish'
grep -Fq 'shell: /bin/fish' "$users_conf" || fail 'Calamares user shell is not Fish'
grep -Fq 'SHELL=/bin/fish' "$labwc_environment" || fail 'labwc session shell default is not Fish'


for doc in "$architecture" "$compatibility" "$pt_architecture" "$pt_compatibility"; do
grep -Fq 'Aqueous' "$doc" || fail "alternate-session boundary is undocumented: ${doc#$root/}"
grep -Fq 'dinit' "$doc" || fail "dinit boundary is undocumented: ${doc#$root/}"
done


grep -Fq '<desktops number="2" />' "$labwc" || fail 'labwc does not start with two virtual desktops'
grep -Fq '<keybind key="W-l">' "$labwc" || fail 'Super+L lock shortcut is missing'
grep -Fq 'command="/usr/local/libexec/dinx-lock"' "$labwc" || fail 'labwc lock command is missing'
grep -Fq 'command="brightnessctl set 5%-"' "$labwc" || fail 'brightness-down shortcut is missing'
grep -Fq 'command="brightnessctl set 5%+"' "$labwc" || fail 'brightness-up shortcut is missing'
grep -Fq 'noctalia >/dev/null 2>&1 &' "$autostart" || fail 'Noctalia is not started by the DINX session'
grep -Fq '/usr/local/libexec/dinx-idle >/dev/null 2>&1 &' "$autostart" || fail 'idle manager is not started by the DINX session'
grep -Fq 'exec labwc --merge-config' "$wrapper" || fail 'labwc wrapper does not merge user configuration'
grep -Fq 'exec /usr/bin/aqueous -c /usr/local/libexec/dinx-aqueous-init' "$aqueous_wrapper" || fail 'Aqueous wrapper does not launch the direct DINX init child'
grep -Fq 'exec /usr/bin/pearl' "$aqueous_init" || fail 'Pearl is not the direct Aqueous session shell'
grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-aqueous-pearl' "$aqueous_session" || fail 'Aqueous/Pearl session command is incorrect'
grep -Fq 'TryExec=/usr/local/libexec/dinx-aqueous-pearl' "$aqueous_session" || fail 'Aqueous/Pearl session TryExec is missing'
if grep -Eq 'systemd|systemctl|uwsm|loginctl' "$aqueous_wrapper" "$aqueous_init" "$aqueous_session"; then
  fail 'Aqueous/Pearl direct session contains a forbidden systemd or uwsm integration'
fi
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
for specialist in swayimg vlc org.strawberrymusicplayer.strawberry org.kde.kolourpaint gufw qps opensnitch_ui nm-connection-editor blueman-manager com.shellyorg.shelly; do
  if grep -Fq "\"$specialist\"" <<<"$dock_line"; then
    fail "specialist launcher remains pinned in the dock: $specialist"
  fi
done

if grep -Eq '/bin/sh -c|systemctl|loginctl suspend' "$lock" "$idle"; then
  fail 'session wrappers contain forbidden shell indirection or systemd suspend calls'
fi

printf 'dinx_session_contract lock=true idle=true before_suspend=true brightness=true energy=true launcher=true hierarchy=true aqueous_pearl=direct_dinit=true systemd=false\n'
