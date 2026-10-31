#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-graphics-profile"
graphics_environment="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-graphics-environment.sh"
[[ -x "$helper" ]] || { printf 'check_dinx_graphics_profile: missing executable helper\n' >&2; exit 1; }
[[ -r "$graphics_environment" ]] || { printf 'check_dinx_graphics_profile: missing graphics environment policy\n' >&2; exit 1; }
source "$graphics_environment"

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-graphics-profile.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

link_driver() {
  local sysfs_device=$1 driver=$2 fixture_root=$3
  mkdir -p "$sysfs_device/device" "$fixture_root/sys/bus/pci/drivers/$driver"
  ln -s "$fixture_root/sys/bus/pci/drivers/$driver" "$sysfs_device/device/driver"
}

run_case() {
  local name=$1 driver=$2 render_node=$3 expected=$4
  local case_root="$tmp_dir/$name"
  local drm_root="$case_root/sys/class/drm"
  local dri_root="$case_root/dev/dri"
  mkdir -p "$drm_root/card0/device" "$dri_root"
  if [[ -n "$driver" ]]; then
    link_driver "$drm_root/card0" "$driver" "$case_root"
  fi
  if [[ "$render_node" == true ]]; then
    touch "$dri_root/renderD128"
    link_driver "$drm_root/renderD128" "$driver" "$case_root"
  fi
  local actual
  actual=$("$helper" "$drm_root" "$dri_root")
  [[ "$actual" == "$expected" ]] || {
    printf 'check_dinx_graphics_profile: %s expected=%s actual=%s\n' "$name" "$expected" "$actual" >&2
    exit 1
  }
}

run_multi_case() {
  local name=$1 expected=$2 card0_driver=$3 card1_driver=$4 render_driver=$5
  local case_root="$tmp_dir/$name"
  local drm_root="$case_root/sys/class/drm"
  local dri_root="$case_root/dev/dri"
  mkdir -p "$dri_root"
  link_driver "$drm_root/card0" "$card0_driver" "$case_root"
  link_driver "$drm_root/card1" "$card1_driver" "$case_root"
  touch "$dri_root/renderD128"
  link_driver "$drm_root/renderD128" "$render_driver" "$case_root"
  local actual
  actual=$("$helper" "$drm_root" "$dri_root")
  [[ "$actual" == "$expected" ]] || {
    printf 'check_dinx_graphics_profile: %s expected=%s actual=%s\n' "$name" "$expected" "$actual" >&2
    exit 1
  }
}

run_case qemu-virgl virtio_gpu true virtual-gl
run_case virtualbox-vmsvga-no-render-node vmwgfx false cpu
run_case virtualbox-vmsvga-render-node vmwgfx true cpu
run_case virtualbox-legacy vboxvideo true cpu
run_case qemu-qxl qxl true cpu
run_case physical-amdgpu amdgpu true hardware
run_multi_case physical-gpu-after-simpledrm hardware simpledrm amdgpu amdgpu
run_multi_case physical-render-node-not-virtio hardware virtio_gpu amdgpu amdgpu
check_renderers() {
  local profile=$1 expected=$2 actual
  actual=$(
    unset WLR_RENDERER GSK_RENDERER
    dinx_apply_graphics_environment "$profile"
    printf '%s,%s' "${WLR_RENDERER:-unset}" "${GSK_RENDERER:-unset}"
  )
  [[ "$actual" == "$expected" ]] || {
    printf 'check_dinx_graphics_profile: %s renderers expected=%s actual=%s\n' "$profile" "$expected" "$actual" >&2
    exit 1
  }
}

check_renderers cpu pixman,cairo
check_renderers virtual-gl gles2,gl
hardware_renderers=$(WLR_RENDERER=custom GSK_RENDERER=custom bash -c '
  . "$1"
  dinx_apply_graphics_environment hardware
  printf "%s,%s" "$WLR_RENDERER" "$GSK_RENDERER"
' bash "$graphics_environment")
[[ "$hardware_renderers" == custom,custom ]] || {
  printf 'check_dinx_graphics_profile: hardware renderer overrides were not preserved: %s\n' "$hardware_renderers" >&2
  exit 1
}
if dinx_apply_graphics_environment unknown >/dev/null 2>&1; then
  printf 'check_dinx_graphics_profile: unknown graphics profile was accepted\n' >&2
  exit 1
fi

printf 'dinx_graphics_profile_contract vmsvga_pixman=true qemu_virgl_gles=true greeter_renderer_policy=true render_node_driver_bound=true cpu_fallback=true hardware_passthrough=true\n'


