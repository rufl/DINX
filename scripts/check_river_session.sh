#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
mimeapps="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/mimeapps.list"
launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-river-session"
init="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-river-init"
session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions/dinx-river-kwm-morghulis.desktop"
pcmanfm="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/pcmanfm.desktop"
first_run="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-morghulis-first-run"
theme_sync="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-sync-session-theme"

fail() { printf 'river_session_contract: FAIL: %s\n' "$1" >&2; exit 1; }
for package in river kwm morghulis pcmanfm pori mission-center; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
  grep -Fq "        \"$package\"," "$groups" || fail "desktop group is missing $package"
done
for package in aqueous pearl phyto qps dome; do
  if grep -Fqx "    - $package" "$profile" || grep -Fq "        \"$package\"," "$groups"; then
    fail "disabled package remains selected: $package"
  fi
done
for retired_path in \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions/dinx-aqueous-pearl.desktop" \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/org.aqueous.Phyto.desktop" \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/qps.desktop"; do
  [[ ! -e "$retired_path" ]] || fail "retired launcher remains: ${retired_path#$root/}"
done
grep -Fqx 'inode/directory=pcmanfm.desktop;' "$mimeapps" || fail 'PCManFM is not the default directory handler'
[[ -x "$launcher" && -x "$init" && -x "$first_run" ]] || fail 'River session launchers are not executable'
[[ -r "$theme_sync" ]] || fail 'Morghulis theme synchronizer is missing'
sh -n "$launcher" "$init" "$first_run" "$theme_sync" || fail 'River session launcher has invalid shell syntax'
grep -Fq 'exec river -c /usr/local/libexec/dinx-river-init' "$launcher" || fail 'session does not start River'
grep -Fq 'start kwm' "$init" || fail 'session does not start KWM'
grep -Fq 'start morghulis' "$init" || fail 'session does not start Morghulis'
grep -Fq 'start pcmanfm --desktop' "$init" || fail 'session does not start the PCManFM desktop manager'
grep -Fq 'dinx-morghulis-first-run' "$init" || fail 'session does not start the Morghulis first-run setup'
grep -Fq 'start_optional bc250-control-centerd' "$init" || fail 'session does not supervise the optional BC-250 daemon'
grep -Fq 'preferences="$config_home/morghulis/preferences.json"' "$theme_sync" || fail 'theme sync still reads Pearl preferences'
grep -Fqx 'Exec=dbus-run-session /usr/local/libexec/dinx-river-session' "$session" || fail 'Wayland session command is incorrect'
grep -Fqx 'Exec=pcmanfm %U' "$pcmanfm" || fail 'PCManFM launcher does not preserve file arguments'
printf 'river_session_contract session=river+kwm+morghulis file_manager=pcmanfm desktop=pcmanfm first_run=morghulis disabled=aqueous+pearl+phyto+qps+dome\n'
