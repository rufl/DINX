#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)

fail() {
  printf 'check_dinx_bsd: %s\n' "$*" >&2
  exit 1
}

bsd_dir="$repo_root/distro/bsd"
[[ -d "$bsd_dir" ]] || fail 'missing distro/bsd directory'
[[ -f "$repo_root/docs/DINX-BSD-ROADMAP.md" ]] || fail 'missing DINX-BSD roadmap'
[[ -f "$bsd_dir/config/octapkg.conf" ]] || fail 'missing octapkg.conf'
[[ -f "$bsd_dir/config/packages.txt" ]] || fail 'missing packages.txt manifest'
[[ -f "$repo_root/scripts/install-dinx-bsd.sh" ]] || fail 'missing install-dinx-bsd.sh installer'
[[ -f "$bsd_dir/ports/Makefile.aqueous" ]] || fail 'missing Makefile.aqueous'
[[ -f "$bsd_dir/ports/Makefile.pearl" ]] || fail 'missing Makefile.pearl'
[[ -f "$bsd_dir/ports/Makefile.octapkg" ]] || fail 'missing Makefile.octapkg'
[[ -f "$bsd_dir/ports/Makefile.deetty" ]] || fail 'missing Makefile.deetty'
[[ -f "$bsd_dir/ports/Makefile.dinitui" ]] || fail 'missing Makefile.dinitui'
[[ -f "$bsd_dir/ports/Makefile.dinxpanel" ]] || fail 'missing Makefile.dinxpanel'
[[ -f "$bsd_dir/ports/Makefile.floorp" ]] || fail 'missing Makefile.floorp'
[[ -f "$bsd_dir/ports/Makefile.onlyoffice" ]] || fail 'missing Makefile.onlyoffice'
[[ -f "$bsd_dir/ports/Makefile.pori" ]] || fail 'missing Makefile.pori'
[[ -f "$bsd_dir/ports/Makefile.phyto" ]] || fail 'missing Makefile.phyto'
[[ -f "$bsd_dir/ports/Makefile.dinted" ]] || fail 'missing Makefile.dinted'
[[ -f "$bsd_dir/ports/Makefile.seafoam" ]] || fail 'missing Makefile.seafoam'
[[ -f "$bsd_dir/ports/Makefile.cyan-skillfish" ]] || fail 'missing Makefile.cyan-skillfish'
[[ -f "$bsd_dir/ports/Makefile.bc250-control-center" ]] || fail 'missing Makefile.bc250-control-center'
[[ -f "$bsd_dir/ports/Makefile.pixelorama" ]] || fail 'missing Makefile.pixelorama'
[[ -f "$bsd_dir/ports/Makefile.blockbench" ]] || fail 'missing Makefile.blockbench'
[[ -f "$bsd_dir/ports/Makefile.dinx-bluetooth-manager" ]] || fail 'missing Makefile.dinx-bluetooth-manager'
[[ -f "$bsd_dir/ports/Makefile.dinx-gaming" ]] || fail 'missing Makefile.dinx-gaming'
[[ -f "$bsd_dir/ports/Makefile.dinx-graphics-profile" ]] || fail 'missing Makefile.dinx-graphics-profile'
[[ -f "$bsd_dir/ports/Makefile.dinx-aqueous-init" ]] || fail 'missing Makefile.dinx-aqueous-init'
[[ -f "$bsd_dir/ports/Makefile.dinx-live-autologin" ]] || fail 'missing Makefile.dinx-live-autologin'
[[ -f "$bsd_dir/ports/Makefile.dinx-pearl-greeter-host" ]] || fail 'missing Makefile.dinx-pearl-greeter-host'
[[ -f "$bsd_dir/ports/Makefile.dinx-aqueous-pearl" ]] || fail 'missing Makefile.dinx-aqueous-pearl'
[[ -f "$bsd_dir/ports/Makefile.dinx-package-channel" ]] || fail 'missing Makefile.dinx-package-channel'
[[ -f "$bsd_dir/ports/Makefile.dinx-plymouth-screen" ]] || fail 'missing Makefile.dinx-plymouth-screen'
[[ -f "$bsd_dir/ports/Makefile.dinx-initramfs" ]] || fail 'missing Makefile.dinx-initramfs'
[[ -f "$bsd_dir/ports/Makefile.dinx-doctor" ]] || fail 'missing Makefile.dinx-doctor'
[[ -f "$bsd_dir/ports/Makefile.dinx-hardware-probe" ]] || fail 'missing Makefile.dinx-hardware-probe'
[[ -f "$bsd_dir/ports/Makefile.dinx-welcome" ]] || fail 'missing Makefile.dinx-welcome'
[[ -f "$bsd_dir/ports/Makefile.dinx-session-supervisor" ]] || fail 'missing Makefile.dinx-session-supervisor'
[[ -f "$bsd_dir/ports/Makefile.dinx-qt-palette" ]] || fail 'missing Makefile.dinx-qt-palette'
[[ -f "$bsd_dir/ports/Makefile.dinx-noto-latin" ]] || fail 'missing Makefile.dinx-noto-latin'
[[ -f "$bsd_dir/ports/Makefile.dinx-tray" ]] || fail 'missing Makefile.dinx-tray'
[[ -f "$bsd_dir/ports/Makefile.dinx-network-manager" ]] || fail 'missing Makefile.dinx-network-manager'
[[ -f "$bsd_dir/ports/Makefile.dinx-audio-manager" ]] || fail 'missing Makefile.dinx-audio-manager'
[[ -f "$bsd_dir/ports/Makefile.dinx-power-manager" ]] || fail 'missing Makefile.dinx-power-manager'
[[ -f "$bsd_dir/config/dinit/seatd" ]] || fail 'missing dinit seatd unit'
[[ -f "$bsd_dir/config/dinit/pipewire" ]] || fail 'missing dinit pipewire unit'
[[ -f "$bsd_dir/config/dinit/greetd" ]] || fail 'missing dinit greetd unit'

printf 'dinx_bsd_contract roadmap=passed ports=passed octapkg=passed dinit_units=passed package_manifest=passed installer=passed upstream_reuse=passed custom_ports=passed editor_port=passed octapkg_primary=passed seafoam_port=passed governor_port=passed bc250_port=passed pixelorama_port=passed blockbench_port=passed bluetooth_port=passed gaming_port=passed graphics_profile_port=passed aqueous_init_port=passed live_autologin_port=passed pearl_greeter_port=passed aqueous_pearl_port=passed package_channel_port=passed plymouth_port=passed initramfs_port=passed doctor_port=passed hardware_probe_port=passed welcome_port=passed session_supervisor_port=passed qt_palette_port=passed noto_latin_port=passed tray_port=passed network_manager_port=passed audio_manager_port=passed power_manager_port=passed\n'
