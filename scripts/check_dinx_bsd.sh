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
[[ -f "$bsd_dir/ports/Makefile.aqueous" ]] || fail 'missing Makefile.aqueous'
[[ -f "$bsd_dir/ports/Makefile.pearl" ]] || fail 'missing Makefile.pearl'
[[ -f "$bsd_dir/ports/Makefile.octapkg" ]] || fail 'missing Makefile.octapkg'
[[ -f "$bsd_dir/ports/Makefile.deetty" ]] || fail 'missing Makefile.deetty'
[[ -f "$bsd_dir/config/dinit/seatd" ]] || fail 'missing dinit seatd unit'
[[ -f "$bsd_dir/config/dinit/pipewire" ]] || fail 'missing dinit pipewire unit'
[[ -f "$bsd_dir/config/dinit/greetd" ]] || fail 'missing dinit greetd unit'

printf 'dinx_bsd_contract roadmap=passed ports=passed octapkg=passed dinit_units=passed additional_ports=passed\n'
