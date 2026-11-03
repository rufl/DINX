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
    function emit_array(    count, i, value, output, udev_count, plymouth_count, have_vmwgfx, have_vboxvideo) {
      count = split(array_content, values, /[[:space:]]+/)
      output = ""
      if (array_name == "MODULES") {
        for (i = 1; i <= count; i++) {
          value = values[i]
          if (value == "") continue
          if (value == "vmwgfx") have_vmwgfx = 1
          if (value == "vboxvideo") have_vboxvideo = 1
          if (output != "") output = output " "
          output = output value
        }
        if (!have_vmwgfx) {
          if (output != "") output = output " "
          output = output "vmwgfx"
        }
        if (!have_vboxvideo) {
          if (output != "") output = output " "
          output = output "vboxvideo"
        }
      } else {
        for (i = 1; i <= count; i++) {
          value = values[i]
          if (value == "") continue
          if (value == "udev") udev_count++
          if (value == "plymouth") {
            plymouth_count++
            continue
          }
          if (output != "") output = output " "
          output = output value
          if (value == "udev") output = output " plymouth"
        }
        if (udev_count != 1 || plymouth_count > 1) return 0
      }
      print array_prefix output array_suffix
      array_name = ""
      array_content = ""
      array_prefix = ""
      array_suffix = ""
      return 1
    }
    function consume_array(fragment,    close_pos, suffix) {
      close_pos = index(fragment, ")")
      if (!close_pos) {
        array_content = array_content " " fragment
        return 1
      }
      suffix = substr(fragment, close_pos)
      if (suffix !~ /^\)[[:space:]]*(#.*)?$/) return 0
      array_content = array_content " " substr(fragment, 1, close_pos - 1)
      array_suffix = suffix
      return emit_array()
    }
    function start_array(name,    open_pos) {
      if (name == "MODULES") {
        if (modules_seen++) return 0
      } else {
        if (hooks_seen++) return 0
      }
      array_name = name
      open_pos = index($0, "(")
      array_prefix = substr($0, 1, open_pos)
      array_content = ""
      return consume_array(substr($0, open_pos + 1))
    }
    {
      if (array_name != "") {
        if (!consume_array($0)) exit 1
        next
      }
      if ($0 ~ /^[[:space:]]*MODULES[[:space:]]*=\(/) {
        if (!start_array("MODULES")) exit 1
        next
      }
      if ($0 ~ /^[[:space:]]*HOOKS[[:space:]]*=\(/) {
        if (!start_array("HOOKS")) exit 1
        next
      }
      print
    }
    END {
      if (array_name != "" || modules_seen != 1 || hooks_seen != 1) exit 1
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
