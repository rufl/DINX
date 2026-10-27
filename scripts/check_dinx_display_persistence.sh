#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
saver="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-save-shikane-profile"
launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-wdisplays"
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
seed="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/shikane/config.toml"
desktop="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/network.cycles.wdisplays.desktop"
iso_check="$root/scripts/check-iso-content.sh"
workflow="$root/.github/workflows/p0-iso.yml"
seafoam_source="$root/distro/packages/seafoam-settings/src/main.zig"
dinxpanel_source="$root/distro/packages/dinxpanel/src/main.zig"
smoke="$root/scripts/smoke_dinx_display_persistence.sh"

fail() {
  printf 'check_dinx_display_persistence: %s\n' "$*" >&2
  exit 1
}

for path in "$saver" "$launcher" "$seed" "$desktop" "$iso_check" "$workflow" "$seafoam_source" \
  "$dinxpanel_source" "$smoke" "$supervisor"; do
  [[ -r "$path" ]] || fail "missing $path"
done
[[ -x "$saver" ]] || fail 'profile saver is not executable'
[[ -x "$launcher" ]] || fail 'wdisplays wrapper is not executable'

grep -Fq "profile_name='DINX wdisplays'" "$saver" || fail 'profile name is not stable'
grep -Fq 'flock -n 9' "$saver" || fail 'saver does not serialize concurrent display updates'
grep -Fq 'shikanectl export "$profile_name"' "$saver" || fail 'saver does not export the current display state'
grep -Fq 'shikanectl reload' "$saver" || fail 'saver does not reload the daemon'
grep -Fq 'reload failed after saving' "$saver" || fail 'saver hides reload failures'
grep -Fq 'trap cleanup EXIT' "$saver" || fail 'saver cleanup is not guaranteed on normal exit'
grep -Fq "trap 'exit 143' HUP INT TERM" "$saver" || fail 'saver does not terminate cleanly on signals'
grep -Fq 'awk -v generated="$export_file"' "$saver" || fail 'saver does not merge the generated profile'
grep -Fq 'mv -f "$merged_file" "$config_path"' "$saver" || fail 'saver is not atomic'
grep -Fq 'start_required shikane shikane' "$supervisor" \
  || fail 'Aqueous supervisor does not own the display daemon'
grep -Fq 'dinx-wdisplays' "$seed" || fail 'seed config does not document the DINX display path'
grep -Fq 'timeout = 0' "$seed" || fail 'seed config is not valid Shikane TOML'
grep -Fq 'Exec=dinx-wdisplays' "$desktop" || fail 'display desktop entry does not use the DINX wrapper'
grep -Fq 'TryExec=dinx-wdisplays' "$desktop" || fail 'display desktop entry TryExec is incorrect'
grep -Fq 'dinx-wdisplays' "$seafoam_source" || fail 'Seafoam Settings bypasses the DINX display wrapper'
grep -Fq 'dinx-wdisplays' "$dinxpanel_source" || fail 'DINXPanel bypasses the DINX display wrapper'
grep -Fqx '  etc/skel/.config/shikane/config.toml' "$iso_check" || fail 'ISO contract omits the Shikane seed config'
grep -Fqx '  usr/local/bin/dinx-save-shikane-profile' "$iso_check" || fail 'ISO contract omits the profile saver'
grep -Fqx '  usr/local/bin/dinx-wdisplays' "$iso_check" || fail 'ISO contract omits the wdisplays wrapper'
grep -Fqx '  usr/share/applications/network.cycles.wdisplays.desktop' "$iso_check" || fail 'ISO contract omits the overridden display desktop entry'
grep -Fq 'scripts/check_dinx_display_persistence.sh' "$workflow" || fail 'workflow does not run the display persistence contract'
grep -Fq 'scripts/smoke_dinx_display_persistence.sh' "$workflow" || fail 'workflow does not run the display persistence smoke'

printf 'dinx_display_persistence_contract wrapper=true merge=true atomic=true reload=true session=true desktop=true\n'
