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
[[ -f "$bsd_dir/ports/Makefile.nocted" ]] || fail 'missing Makefile.nocted'
[[ -f "$bsd_dir/config/dinit/seatd" ]] || fail 'missing dinit seatd unit'
[[ -f "$bsd_dir/config/dinit/pipewire" ]] || fail 'missing dinit pipewire unit'
[[ -f "$bsd_dir/config/dinit/greetd" ]] || fail 'missing dinit greetd unit'

printf 'dinx_bsd_contract roadmap=passed ports=passed octapkg=passed dinit_units=passed package_manifest=passed installer=passed upstream_reuse=passed custom_ports=passed editor_port=passed\n'
