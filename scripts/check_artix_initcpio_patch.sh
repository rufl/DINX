#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
patcher="$repo_root/scripts/patch-artix-initcpio.sh"
[[ -x "$patcher" ]] || { printf 'initramfs patcher is not executable\n' >&2; exit 1; }

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

config="$tmp_dir/mkinitcpio-default.conf"
cat > "$config" <<'EOF'
MODULES=(loop dm-snapshot)
HOOKS=(base udev block filesystems)
EOF
"$patcher" --ensure-graphics-modules "$config"
cat > "$tmp_dir/expected.conf" <<'EOF'
MODULES=(loop dm-snapshot vmwgfx vboxvideo)
HOOKS=(base udev block filesystems)
EOF
if ! cmp -s "$tmp_dir/expected.conf" "$config"; then
  diff -u "$tmp_dir/expected.conf" "$config" >&2 || true
  printf 'initramfs MODULES patch did not add exactly vmwgfx and vboxvideo\n' >&2
  exit 1
fi
"$patcher" --ensure-graphics-modules "$config"
cmp -s "$tmp_dir/expected.conf" "$config" || {
  printf 'initramfs MODULES patch is not idempotent\n' >&2
  exit 1
}

helper="$tmp_dir/initcpio.sh"
cat > "$helper" <<'EOF'
prepare_initramfs_mkinitcpio() {
    artix-chroot "$mnt" mkinitcpio -k "$k" \
        -c /etc/"$mkinitcpio_conf" \
        -g /boot/initramfs.img
}
EOF
"$patcher" --patch-artix-helper "$helper"
if ! awk '
  /"\$DINX_INITRAMFS_PATCHER" --ensure-graphics-modules "\$mnt\/etc\/\$mkinitcpio_conf"/ { patch_line = NR }
  /artix-chroot "\$mnt" mkinitcpio -k "\$k"/ { build_line = NR }
  END { exit !(patch_line && build_line == patch_line + 1) }
' "$helper"; then
  printf 'Artix helper does not patch the bootfs config immediately before mkinitcpio\n' >&2
  exit 1
fi

unsupported_helper="$tmp_dir/unsupported-initcpio.sh"
printf '%s\n' 'prepare_initramfs_mkinitcpio() { true; }' > "$unsupported_helper"
if "$patcher" --patch-artix-helper "$unsupported_helper" >/dev/null 2>&1; then
  printf 'unsupported Artix helper layout was accepted\n' >&2
  exit 1
fi

if [[ ${1:-} == --check-installed ]]; then
  buildiso_path=$(command -v buildiso) \
    || { printf 'Artix buildiso is not installed\n' >&2; exit 1; }
  artools_paths=$(awk -F"'" '
    /^LIBDIR=/ { libdir = $2; libdir_count++ }
    /^DATADIR=/ { datadir = $2; datadir_count++ }
    END {
      if (libdir_count != 1 || datadir_count != 1 || libdir == "" || datadir == "") exit 1
      print libdir
      print datadir
    }
  ' "$buildiso_path") || { printf 'cannot resolve Artix buildiso directories\n' >&2; exit 1; }
  mapfile -t artools_paths <<< "$artools_paths"
  [[ ${#artools_paths[@]} -eq 2 ]] \
    || { printf 'invalid Artix buildiso directories\n' >&2; exit 1; }
  artix_lib_dir=${artools_paths[0]}
  artix_data_dir=${artools_paths[1]}
  case "$artix_lib_dir" in
    "$artix_data_dir"/*) ;;
    *) printf 'Artix library directory is outside its data directory: %s\n' "$artix_lib_dir" >&2; exit 1 ;;
  esac
  artix_helper="$artix_lib_dir/iso/initcpio.sh"
  [[ -r "$artix_helper" ]] \
    || { printf 'Artix initramfs helper is missing: %s\n' "$artix_helper" >&2; exit 1; }
  cp -- "$artix_helper" "$tmp_dir/installed-initcpio.sh"
  "$patcher" --patch-artix-helper "$tmp_dir/installed-initcpio.sh"
  printf 'Installed Artix helper contract passed: %s\n' "$artix_helper"
elif [[ $# -ne 0 ]]; then
  printf 'usage: %s [--check-installed]\n' "${BASH_SOURCE[0]}" >&2
  exit 1
fi

printf 'Artix initramfs patch contract passed.\n'
