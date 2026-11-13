#!/usr/bin/env bash
set -euo pipefail

# build-bsd-ports-local.sh
# Builds the custom DINX-BSD ports (Aqueous, Pearl, dinx-aqueous-pearl,
# dinx-pearl-greeter-host) from local source trees using Zig.
#
# Real FreeBSD .pkg files are produced ONLY on a FreeBSD host with pkg(8),
# via `pkg create` + `pkg repo`. On any other host, or when a build fails,
# this script emits staging trees and build logs only -- it never fabricates
# package archives.
#
# Usage: build-bsd-ports-local.sh [--target x86_64-freebsd]

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_BASE="${ROOT}/dist/bsd/ports/pkg"
STAGING="${OUT_BASE}/staging"
REPO="${OUT_BASE}/repo"
ZIG="${ZIG:-zig}"
TARGET="x86_64-freebsd"
if [[ "${1:-}" == --target ]]; then
  TARGET="${2:?--target requires a value}"
fi

SRC_BASE="${SRC_BASE:-/tmp/dinx-bsd-port-research}"
mkdir -p "${STAGING}" "${REPO}"

log() { printf '[ports-build] %s\n' "$*"; }

build_port() {
    local port="$1" src_dir="$2" pkg_name="$3" prefix="$4"
    shift 4
    local bins=("$@")

    log "Building port: ${port} (target=${TARGET})"
    local pkg_stage="${STAGING}/${pkg_name}"
    rm -rf "${pkg_stage}"
    mkdir -p "${pkg_stage}${prefix}/bin"

    if [[ ! -d "${src_dir}" ]]; then
        log "ERROR: source directory not found: ${src_dir}"
        return 1
    fi

    if ! (cd "${src_dir}" && "${ZIG}" build -Doptimize=ReleaseSafe \
            -Dtarget="${TARGET}" > "${pkg_stage}.build.log" 2>&1); then
        log "ERROR: zig build failed for ${port}; see ${pkg_stage}.build.log"
        return 1
    fi

    local installed=0
    for bin in "${bins[@]}"; do
        if [[ -f "${src_dir}/zig-out/bin/${bin}" ]]; then
            cp "${src_dir}/zig-out/bin/${bin}" "${pkg_stage}${prefix}/bin/"
            log "  installed: ${bin}"
            installed=1
        fi
    done
    if [[ "${installed}" != 1 ]]; then
        log "ERROR: ${port} produced no binaries; refusing to package"
        return 1
    fi

    if [[ -d "${src_dir}/packaging" ]]; then
        (cd "${src_dir}/packaging" && find . -type f -print0) \
          | while IFS= read -r -d '' f; do
              rel="${f#./}"
              mkdir -p "${pkg_stage}${prefix}/$(dirname "${rel}")"
              cp "${src_dir}/packaging/${rel}" "${pkg_stage}${prefix}/${rel}"
            done
    fi

    if [[ "$(uname)" != FreeBSD ]]; then
        log "host is not FreeBSD: staging only for ${pkg_name}; no .pkg emitted"
        return 0
    fi
    command -v pkg >/dev/null 2>&1 || {
        log "pkg(8) not available: staging only for ${pkg_name}; no .pkg emitted"
        return 0
    }

    local meta="${STAGING}/${pkg_name}-meta"
    rm -rf "${meta}"
    mkdir -p "${meta}"
    cat > "${meta}/+MANIFEST" <<MANIFEST
name: ${pkg_name}
version: "1.0.0"
origin: dinx/${pkg_name}
comment: ${port} for DINX-BSD
maintainer: trafael@dinx.org
prefix: ${prefix}
MANIFEST
    printf '%s for DINX-BSD\n' "${port}" > "${meta}/+DESC"
    pkg create -m "${meta}" -r "${pkg_stage}" -o "${REPO}" \
      || { log "ERROR: pkg create failed for ${pkg_name}"; return 1; }
    log "Created real package: ${REPO}/${pkg_name}.pkg"
}

status=0
build_port "aqueous" \
    "${SRC_BASE}/aqueous/Aqueous-1.0.5" \
    "dinx-aqueous" "/usr/local" \
    "aqueous" "aqueousctl" || status=1

build_port "pearl" \
    "${SRC_BASE}/pearl/pearl-0.3.0" \
    "dinx-pearl" "/usr/local" \
    "pearl" "pearl-chooser" "pearl-capture-picker" "xdg-desktop-portal-pearl" || status=1

build_port "dinx-aqueous-pearl" \
    "${SRC_BASE}/pearl/pearl-0.3.0" \
    "dinx-aqueous-pearl" "/usr/local" \
    "dinx-aqueous-pearl" || status=1

build_port "dinx-pearl-greeter-host" \
    "${SRC_BASE}/pearl/pearl-0.3.0" \
    "dinx-pearl-greeter-host" "/usr/local" \
    "dinx-pearl-greeter-host" || status=1

if [[ "$(uname)" == FreeBSD ]] && command -v pkg >/dev/null 2>&1 \
   && compgen -G "${REPO}/*.pkg" >/dev/null; then
    pkg repo "${REPO}" || { log 'ERROR: pkg repo failed'; status=1; }
fi

log "Done (status=${status}). Staging: ${STAGING}; repo: ${REPO}"
exit "${status}"
