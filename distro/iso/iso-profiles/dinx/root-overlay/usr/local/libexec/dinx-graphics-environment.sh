#!/bin/sh
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: GPL-3.0-only

dinx_apply_graphics_environment() {
  case "${1:-}" in
    cpu)
      export WLR_RENDERER=pixman
      unset GSK_RENDERER
      ;;
    virtual-gl)
      export WLR_RENDERER=gles2
      unset GSK_RENDERER
      ;;
    vulkan)
      export WLR_RENDERER=vulkan
      unset GSK_RENDERER
      ;;
    hardware)
      ;;
    *)
      printf 'dinx-graphics-environment: unknown graphics profile: %s\n' "${1:-}" >&2
      return 1
      ;;
  esac
}
