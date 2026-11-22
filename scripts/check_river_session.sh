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
theme_set="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-set-theme"
desktop_toggle="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-pcmanfm-desktop"
kwm_env="$root/distro/packages/kwm/source.env"
kwim_env="$root/distro/packages/kwim/source.env"
builder="$root/scripts/build-iso-container.sh"

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
[[ -x "$launcher" && -x "$init" && -x "$first_run" && -x "$theme_set" && -x "$desktop_toggle" ]] || fail 'River session launchers are not executable'
[[ -r "$theme_sync" ]] || fail 'Morghulis theme synchronizer is missing'
sh -n "$launcher" "$init" "$first_run" "$theme_sync" "$theme_set" "$desktop_toggle" || fail 'River session launcher has invalid shell syntax'
grep -Fq 'exec river -c /usr/local/libexec/dinx-river-init' "$launcher" || fail 'session does not start River'
grep -Fq 'start kwm' "$init" || fail 'session does not start KWM'
grep -Fq 'start morghulis' "$init" || fail 'session does not start Morghulis'
grep -Fq 'start pcmanfm --desktop' "$init" || fail 'session does not start the PCManFM desktop manager'
grep -Fq 'dinx-pcmanfm-desktop --enabled' "$init" || fail 'session does not persist the PCManFM desktop visibility setting'
grep -Fq 'dinx-morghulis-first-run' "$init" || fail 'session does not start the Morghulis first-run setup'
grep -Fq 'start_optional bc250-control-centerd' "$init" || fail 'session does not supervise the optional BC-250 daemon'
grep -Fq 'preferences="$config_home/morghulis/preferences.json"' "$theme_sync" || fail 'theme sync still reads Pearl preferences'
grep -Fqx 'Exec=dbus-run-session /usr/local/libexec/dinx-river-session' "$session" || fail 'Wayland session command is incorrect'
grep -Fqx 'Exec=pcmanfm %U' "$pcmanfm" || fail 'PCManFM launcher does not preserve file arguments'
# Owner decision 2026-11-17: kwm and kwim stay on released upstream tags built by a
# dedicated Zig 0.16 toolchain, because their build.zig reads the Build.build_root
# field that Zig 0.17 removed. Re-pin to a real tag once upstream cuts a
# 0.17-compatible release; do not move to untagged master commits in the meantime.
[[ -r "$kwm_env" && -r "$kwim_env" ]] || fail 'KWM/KWIM source pins are missing'
for env in "$kwm_env" "$kwim_env"; do
  name=$(basename "$(dirname "$env")")
  grep -Eq '^[A-Z]+_SOURCE_URL=https://github\.com/kewuaa/[a-z]+/archive/refs/tags/v[0-9]+(\.[0-9]+)*\.tar\.gz$' "$env" \
    || fail "$name is not pinned to a released upstream tag archive"
  grep -Eq '^[A-Z]+_VERSION=[0-9]+(\.[0-9]+)+$' "$env" \
    || fail "$name version pin is not a semantic release version"
  grep -Eq '^[A-Z]+_ZIG_VERSION=0\.16\.[0-9]+$' "$env" \
    || fail "$name must stay on the Zig 0.16 toolchain until upstream supports 0.17"
  grep -Eq '^[A-Z]+_ZIG_SOURCE_SHA256=[0-9a-f]{64}$' "$env" \
    || fail "$name Zig toolchain checksum is not pinned"
done
grep -Fq 'kwm_zig_version=0.16.0' "$builder" \
  || fail 'builder no longer provides the dedicated Zig 0.16 toolchain for KWM/KWIM'
grep -Fq '[[ "$package_name" == kwim || "$package_name" == kwm ]]' "$builder" \
  || fail 'builder no longer routes KWM/KWIM to the Zig 0.16 toolchain'
printf 'river_session_contract session=river+kwm+morghulis file_manager=pcmanfm desktop=pcmanfm persistent_theme=dinx-set-theme persistent_desktop=dinx-pcmanfm-desktop kwm_kwim=tagged+zig0.16 disabled=aqueous+pearl+phyto+qps+dome\n'
