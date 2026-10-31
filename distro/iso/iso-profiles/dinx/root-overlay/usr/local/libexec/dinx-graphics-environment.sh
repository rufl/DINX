#!/bin/sh
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: GPL-3.0-only

dinx_apply_graphics_environment() {
  case "${1:-}" in
    cpu)
      export WLR_RENDERER=pixman
      export GSK_RENDERER=cairo
      ;;
    virtual-gl)
      export WLR_RENDERER=gles2
      export GSK_RENDERER=gl
      ;;
    hardware)
      ;;
    *)
      printf 'dinx-graphics-environment: unknown graphics profile: %s\n' "${1:-}" >&2
      return 1
      ;;
  esac
}
