#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
: "${WIZP_SOURCE_DIR:?Set WIZP_SOURCE_DIR to a clean WIZP source checkout}"
: "${WIZP_LEAN_OUTPUT_DIR:?Set WIZP_LEAN_OUTPUT_DIR to an empty output directory}"
source_root=$(realpath -- "$WIZP_SOURCE_DIR")
eurooffice_root=$(realpath -- "${EUROOFFICE_ROOT:-/opt/eurooffice}")
output_root=$(realpath -m -- "$WIZP_LEAN_OUTPUT_DIR")

for tool in bun git tar sha256sum cmp realpath; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'wizp-lean: missing required tool: %s\n' "$tool" >&2
    exit 1
  }
done

[[ -f "$source_root/electrobun.config.ts" && -f "$source_root/build.zig" && -f "$source_root/frontend/package.json" ]] || {
  printf 'wizp-lean: WIZP_SOURCE_DIR is not the WIZP repository root: %s\n' "$source_root" >&2
  exit 1
}
[[ -f "$eurooffice_root/libcef.so" ]] || {
  printf 'wizp-lean: EuroOffice runtime missing libcef.so: %s\n' "$eurooffice_root/libcef.so" >&2
  exit 1
}

readonly CEF_VERSION='109.1.18+gf1c41e4'
readonly CHROMIUM_VERSION='109.0.5414.120'
readonly EUROOFFICE_PKGVER='9.3.8-5'
readonly ELECTROBUN_COMMIT='4eba723c85b97559e1d9e13439d9a92ede0832e8'
readonly EUROOFFICE_LIBCEF_SHA256='b86edf848d4c18c70d76eba7bcce766d2f5d735ac56effeb11fcf4ee47771689'
actual_libcef_sha=$(sha256sum "$eurooffice_root/libcef.so" | awk '{print $1}')
[[ "$actual_libcef_sha" == "$EUROOFFICE_LIBCEF_SHA256" ]] || {
  printf 'wizp-lean: unsupported EuroOffice libcef.so hash: %s\n' "$actual_libcef_sha" >&2
  exit 1
}

if [[ -e "$output_root" ]] && [[ -n "$(find "$output_root" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
  printf 'wizp-lean: output directory must be empty: %s\n' "$output_root" >&2
  exit 1
fi
mkdir -p -- "$output_root"

workdir=${WIZP_LEAN_WORKDIR:-}
created_workdir=0
if [[ -z "$workdir" ]]; then
  cache_root=${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}
  mkdir -p -- "$cache_root"
  workdir=$(mktemp -d "$cache_root/wizp-lean-build.XXXXXX")
  created_workdir=1
else
  workdir=$(realpath -m -- "$workdir")
  mkdir -p -- "$workdir"
  [[ -z "$(find "$workdir" -mindepth 1 -print -quit)" ]] || {
    printf 'wizp-lean: WIZP_LEAN_WORKDIR must be empty: %s\n' "$workdir" >&2
    exit 1
  }
fi
cleanup() {
  if (( created_workdir )) && [[ "${WIZP_LEAN_KEEP_WORKDIR:-0}" != 1 ]]; then
    rm -rf -- "$workdir"
  fi
}
trap cleanup EXIT

electrobun_root="$workdir/electrobun"
app_root="$workdir/wizp"
git clone --quiet --depth 1 --branch v1.18.1 https://github.com/blackboardsh/electrobun.git "$electrobun_root"
actual_electrobun_commit=$(git -C "$electrobun_root" rev-parse HEAD)
[[ "$actual_electrobun_commit" == "$ELECTROBUN_COMMIT" ]] || {
  printf 'wizp-lean: Electrobun tag resolved to unexpected commit: %s\n' "$actual_electrobun_commit" >&2
  exit 1
}
git -C "$electrobun_root" apply "$script_dir/electrobun-cef109.patch"
(
  cd -- "$electrobun_root/package"
  bun install --frozen-lockfile
  bun build.ts
)

mkdir -p -- "$app_root"
tar -C "$source_root" \
  --exclude='./.git' \
  --exclude='./node_modules' \
  --exclude='./frontend/node_modules' \
  --exclude='./build' \
  --exclude='./zig-out' \
  --exclude='./.zig-cache' \
  --exclude='./frontend/dist' \
  -cf - . | tar -xf - -C "$app_root"
(
  cd -- "$app_root"
  bun install
  (cd frontend && bun install)
  rm -rf -- node_modules/electrobun
  ln -s -- "$electrobun_root/package" node_modules/electrobun
  bun run build:frontend
  bun run build:linux:self-contained
  bun run build:electrobun
  bun run vendor:linux-runtime
  bun run prune:linux-package
)

package_root="$app_root/build/dev-linux-x64/WIZP-dev"
bin_dir="$package_root/bin"
cef_dir="$bin_dir/cef"
[[ -x "$bin_dir/launcher" && -x "$bin_dir/bun" && -f "$bin_dir/libNativeWrapper.so" ]] || {
  printf 'wizp-lean: Electrobun build output is incomplete: %s\n' "$package_root" >&2
  exit 1
}

shared_libraries=(libcef.so libEGL.so libGLESv2.so libvk_swiftshader.so libvulkan.so.1)
shared_resources=(icudtl.dat resources.pak v8_context_snapshot.bin snapshot_blob.bin chrome_100_percent.pak chrome_200_percent.pak vk_swiftshader_icd.json)
for file in "${shared_libraries[@]}" "${shared_resources[@]}"; do
  [[ -f "$eurooffice_root/$file" ]] || {
    printf 'wizp-lean: EuroOffice runtime is missing required CEF payload: %s\n' "$file" >&2
    exit 1
  }
done
[[ -d "$eurooffice_root/locales" ]] || {
  printf 'wizp-lean: EuroOffice runtime is missing CEF locales\n' >&2
  exit 1
}
for file in "${shared_libraries[@]}"; do
  cp -- "$eurooffice_root/$file" "$cef_dir/$file"
done
for file in "${shared_resources[@]}"; do
  cp -- "$eurooffice_root/$file" "$bin_dir/$file"
done
cp -- "$eurooffice_root/vk_swiftshader_icd.json" "$cef_dir/vk_swiftshader_icd.json"
rm -rf -- "$bin_dir/locales"
cp -a -- "$eurooffice_root/locales" "$bin_dir/locales"

for file in "${shared_libraries[@]}"; do
  cmp -s -- "$eurooffice_root/$file" "$cef_dir/$file" || {
    printf 'wizp-lean: CEF payload differs from EuroOffice: %s\n' "$file" >&2
    exit 1
  }
done
for file in "${shared_resources[@]}"; do
  cmp -s -- "$eurooffice_root/$file" "$bin_dir/$file" || {
    printf 'wizp-lean: CEF resource differs from EuroOffice: %s\n' "$file" >&2
    exit 1
  }
done
for eurooffice_locale in "$eurooffice_root"/locales/*.pak; do
  cmp -s -- "$eurooffice_locale" "$bin_dir/locales/${eurooffice_locale##*/}" || {
    printf 'wizp-lean: CEF locale differs from EuroOffice: %s\n' "${eurooffice_locale##*/}" >&2
    exit 1
  }
done

patch_sha=$(sha256sum "$script_dir/electrobun-cef109.patch" | awk '{print $1}')
source_commit=$(git -C "$source_root" rev-parse HEAD 2>/dev/null || printf '%s' "${WIZP_SOURCE_COMMIT:-unversioned}")
if [[ -n "${WIZP_SOURCE_COMMIT:-}" && "$source_commit" != "$WIZP_SOURCE_COMMIT" ]]; then
  printf 'wizp-lean: source checkout does not match pinned commit: %s\n' "$source_commit" >&2
  exit 1
fi
cat > "$package_root/Resources/wizp-lean-cef.json" <<EOF
{
  "schema": "dinx-wizp-lean-cef/v1",
  "wizp_source_commit": "$source_commit",
  "electrobun": {
    "version": "1.18.1",
    "source_commit": "$ELECTROBUN_COMMIT",
    "patch_sha256": "$patch_sha"
  },
  "cef": {
    "version": "$CEF_VERSION",
    "chromium": "$CHROMIUM_VERSION",
    "libcef_sha256": "$EUROOFFICE_LIBCEF_SHA256"
  },
  "eurooffice_pkgver": "$EUROOFFICE_PKGVER"
}
EOF

(
  cd -- "$app_root"
  bun run audit:package
  bun run audit:self-contained
)
cp -a -- "$package_root"/. "$output_root"/
printf 'wizp-lean: built %s CEF package (%s bytes) at %s\n' "$CEF_VERSION" "$(du -sb -- "$output_root" | awk '{print $1}')" "$output_root"
