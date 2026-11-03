#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'patch-artix-initcpio: %s\n' "$*" >&2
  exit 1
}

ensure_boot_support() {
  local config_path=$1
  local config_dir tmp_file

  [[ -f "$config_path" && ! -L "$config_path" ]] \
    || fail "initramfs config is not a regular file: $config_path"
  config_dir=$(dirname -- "$config_path")
  tmp_file=$(mktemp "$config_dir/.mkinitcpio-default.XXXXXX")
  trap 'rm -f -- "$tmp_file"' EXIT

  awk '
    /^[[:space:]]*MODULES[[:space:]]*=\(/ {
      if (modules_seen++) exit 1
      open = index($0, "(")
      rest = substr($0, open + 1)
      if (rest !~ /\)[[:space:]]*(#.*)?$/) exit 1
      close_pos = index(rest, ")")
      body = substr(rest, 1, close_pos - 1)
      suffix = substr(rest, close_pos)
      prefix = substr($0, 1, open)
      count = split(body, names, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        if (names[i] == "vmwgfx") have_vmwgfx = 1
        if (names[i] == "vboxvideo") have_vboxvideo = 1
      }
      if (!have_vmwgfx) body = body " vmwgfx"
      if (!have_vboxvideo) body = body " vboxvideo"
      sub(/[[:space:]]+$/, "", body)
      printf "%s%s%s\n", prefix, body, suffix
      next
    }
    /^[[:space:]]*HOOKS[[:space:]]*=\(/ {
      if (hooks_seen++) exit 1
      open = index($0, "(")
      rest = substr($0, open + 1)
      if (rest !~ /\)[[:space:]]*(#.*)?$/) exit 1
      close_pos = index(rest, ")")
      body = substr(rest, 1, close_pos - 1)
      suffix = substr(rest, close_pos)
      prefix = substr($0, 1, open)
      count = split(body, names, /[[:space:]]+/)
      udev_count = 0
      plymouth_count = 0
      for (i = 1; i <= count; i++) {
        if (names[i] == "udev") udev_count++
        if (names[i] == "plymouth") plymouth_count++
      }
      if (udev_count != 1 || plymouth_count > 1) exit 1
      body = ""
      for (i = 1; i <= count; i++) {
        if (names[i] == "" || names[i] == "plymouth") continue
        if (body != "") body = body " "
        body = body names[i]
        if (names[i] == "udev") body = body " plymouth"
      }
      printf "%s%s%s\n", prefix, body, suffix
      next
    }
    { print }
    END {
      if (modules_seen != 1 || hooks_seen != 1) exit 1
    }
  ' "$config_path" > "$tmp_file" \
    || fail "unsupported MODULES or HOOKS array in $config_path"

  chmod --reference="$config_path" "$tmp_file"
  mv -f -- "$tmp_file" "$config_path"
  trap - EXIT
}

patch_artix_helper() {
  local helper_path=$1
  local helper_dir tmp_file

  [[ -f "$helper_path" && ! -L "$helper_path" ]] \
    || fail "Artix initramfs helper is not a regular file: $helper_path"
  helper_dir=$(dirname -- "$helper_path")
  tmp_file=$(mktemp "$helper_dir/.initcpio.XXXXXX")
  trap 'rm -f -- "$tmp_file"' EXIT

  awk '
    index($0, "\"$DINX_INITRAMFS_PATCHER\" --ensure-boot-support \"$mnt/etc/$mkinitcpio_conf\"") {
      already_patched++
    }
    index($0, "artix-chroot \"$mnt\" mkinitcpio -k \"$k\"") {
      target_count++
      indentation = $0
      sub(/[^[:space:]].*$/, "", indentation)
      printf "%s\"$DINX_INITRAMFS_PATCHER\" --ensure-boot-support \"$mnt/etc/$mkinitcpio_conf\"\n", indentation
    }
    { print }
    END {
      if (target_count != 1 || already_patched != 0) exit 1
    }
  ' "$helper_path" > "$tmp_file" \
    || fail "unsupported Artix initramfs helper layout in $helper_path"

  chmod --reference="$helper_path" "$tmp_file"
  mv -f -- "$tmp_file" "$helper_path"
  trap - EXIT
}

case "${1:-}" in
  --ensure-boot-support)
    [[ $# -eq 2 ]] || fail 'usage: patch-artix-initcpio.sh --ensure-boot-support CONFIG'
    ensure_boot_support "$2"
    ;;
  --patch-artix-helper)
    [[ $# -eq 2 ]] || fail 'usage: patch-artix-initcpio.sh --patch-artix-helper HELPER'
    patch_artix_helper "$2"
    ;;
  *)
    fail 'usage: patch-artix-initcpio.sh {--ensure-boot-support CONFIG|--patch-artix-helper HELPER}'
    ;;
esac
