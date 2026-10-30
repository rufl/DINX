#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-graphics-profile"
[[ -x "$helper" ]] || { printf 'check_dinx_graphics_profile: missing executable helper\n' >&2; exit 1; }

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-graphics-profile.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

run_case() {
  local name=$1 driver=$2 render_node=$3 expected=$4
  local case_root="$tmp_dir/$name"
  local drm_root="$case_root/sys/class/drm"
  local dri_root="$case_root/dev/dri"
  mkdir -p "$drm_root/card0/device" "$dri_root"
  if [[ -n "$driver" ]]; then
    mkdir -p "$case_root/sys/bus/pci/drivers/$driver"
    ln -s "$case_root/sys/bus/pci/drivers/$driver" "$drm_root/card0/device/driver"
  fi
  if [[ "$render_node" == true ]]; then
    touch "$dri_root/renderD128"
  fi
  local actual
  actual=$("$helper" "$drm_root" "$dri_root")
  [[ "$actual" == "$expected" ]] || {
    printf 'check_dinx_graphics_profile: %s expected=%s actual=%s\n' "$name" "$expected" "$actual" >&2
    exit 1
  }
}

run_case no-render-node vmwgfx false cpu
run_case qemu-virgl virtio_gpu true virtual-gl
run_case virtualbox-vmsvga vmwgfx true virtual-gl
run_case virtualbox-legacy vboxvideo true cpu
run_case qemu-qxl qxl true cpu
run_case physical-amdgpu amdgpu true hardware

printf 'dinx_graphics_profile_smoke qemu_virgl=true virtualbox_vmsvga=true cpu_fallback=true hardware_passthrough=true\n'
