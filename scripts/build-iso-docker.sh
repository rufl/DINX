#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(git -C "$script_dir/.." rev-parse --show-toplevel 2>/dev/null) || {
  printf 'build-iso-docker: run this from a DINX Git checkout\n' >&2
  exit 1
}
repo_root=$(CDPATH= cd -- "$repo_root" && pwd -P)

fail() {
  printf 'build-iso-docker: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: bash scripts/build-iso-docker.sh

Builds DINX in the pinned, privileged Artix Docker image. It does not install
Artix build packages on the host. By default, artifacts go to a unique
dist/local-iso-<UTC-time>-<pid>/ directory. The package repository is signed
with an ephemeral key and is not a release repository.

Options are controlled through environment variables:
  DINX_LOCAL_BUILD_DIR       Choose an output directory under checkout dist/.
  DINX_ISO_OUTPUT            Override the ISO output directory under dist/.
  DINX_PACKAGE_OUTPUT        Override package directory under dist/ (must end in /packages).
  DINX_ARTIX_IMAGE           Override the digest-pinned Artix builder image.
  DINX_ISO_CHROOTS           Use a chroot directory outside the checkout or under dist/.
  DINX_KEEP_CHROOTS=1        Keep the temporary chroot after a successful build.
  DINX_LOCAL_QEMU_SMOKE=1    Also boot and capture the ISO with scripts/smoke-iso.sh.
  DINX_SKIP_CONTRACTS=1      Skip local static/fixture contracts.
  DEETTY_SOURCE_CHECKOUT   Authenticated local checkout of pinned private NOCTTY source.
USAGE
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi
[[ $# -eq 0 ]] || fail 'unknown argument; use --help'

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required host command not found: $1"
}

for command in docker git realpath sha256sum tar find; do
  require_command "$command"
done
if ! docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
  fail 'Docker Engine is not reachable. Start a rootful Docker daemon and grant this user access; the ISO build requires --privileged and loop-device support.'
fi

image=${DINX_ARTIX_IMAGE:-artixlinux/artixlinux@sha256:e746e31ffe48f9526759711de0a3bc4cb7a8f61d7339dc9b11fe6bee4a722507}
[[ "$image" =~ ^[[:alnum:]./_-]+@sha256:[0-9a-f]{64}$ ]] \
  || fail 'DINX_ARTIX_IMAGE must be an OCI image pinned by sha256 digest'

commit=$(git -C "$repo_root" rev-parse HEAD)
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || fail 'could not resolve the checked-out commit'
run_id=${DINX_RUN_ID:-${GITHUB_RUN_ID:-$(date +%s)}}
[[ "$run_id" =~ ^[0-9]+$ ]] || fail 'DINX_RUN_ID must contain only digits'

repository=${DINX_REPOSITORY:-${GITHUB_REPOSITORY:-}}
if [[ -z "$repository" ]]; then
  remote=$(git -C "$repo_root" config --get remote.origin.url || true)
  case "$remote" in
    https://github.com/*) repository=${remote#https://github.com/} ;;
    http://github.com/*) repository=${remote#http://github.com/} ;;
    ssh://git@github.com/*) repository=${remote#ssh://git@github.com/} ;;
    git@github.com:*) repository=${remote#git@github.com:} ;;
    *) repository="local/$(basename "$repo_root")" ;;
  esac
  repository=${repository%.git}
fi
[[ "$repository" =~ ^[^[:space:]]+$ ]] || fail 'DINX_REPOSITORY must not contain whitespace'

build_context=${DINX_BUILD_CONTEXT:-}
if [[ -z "$build_context" ]]; then
  if [[ ${GITHUB_ACTIONS:-false} == true ]]; then
    build_context=github-actions
  else
    build_context=local-docker
  fi
fi
[[ "$build_context" == local-docker || "$build_context" == github-actions ]] \
  || fail 'DINX_BUILD_CONTEXT must be local-docker or github-actions'

resolve_repo_path() {
  local path=$1
  if [[ "$path" != /* ]]; then
    path="$repo_root/$path"
  fi
  realpath -m -- "$path"
}

container_path() {
  local path=$1
  case "$path" in
    "$repo_root"/*) printf '/workspace/%s\n' "${path#"$repo_root"/}" ;;
    *) fail "build paths must be under the checkout for Docker bind mounts: $path" ;;
  esac
}

if [[ "$build_context" == github-actions ]]; then
  build_root="$repo_root/dist"
  iso_output_host=$(resolve_repo_path "${DINX_ISO_OUTPUT:-$repo_root/dist/iso}")
  package_output_host=$(resolve_repo_path "${DINX_PACKAGE_OUTPUT:-$repo_root/dist/packages}")
  package_bundle_host="$repo_root/dist/dinx-package-repository.tar"
else
  default_build_root="$repo_root/dist/local-iso-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  build_root=$(resolve_repo_path "${DINX_LOCAL_BUILD_DIR:-$default_build_root}")
  iso_output_host=$(resolve_repo_path "${DINX_ISO_OUTPUT:-$build_root/iso}")
  package_output_host=$(resolve_repo_path "${DINX_PACKAGE_OUTPUT:-$build_root/packages}")
  package_bundle_host=$(resolve_repo_path "${DINX_PACKAGE_BUNDLE:-$build_root/dinx-package-repository.tar}")
fi
if [[ "$build_context" == local-docker ]]; then
  for path in "$build_root" "$iso_output_host" "$package_output_host" "$package_bundle_host"; do
    case "$path" in
      "$repo_root"/dist/*) ;;
      *) fail "local build outputs must be under $repo_root/dist so metadata excludes generated artifacts: $path" ;;
    esac
  done
fi
iso_output_container=$(container_path "$iso_output_host")
package_output_container=$(container_path "$package_output_host")
case "$package_output_host" in
  */packages) ;;
  *) fail 'DINX_PACKAGE_OUTPUT must end in /packages so the repository bundle has the expected layout' ;;
esac
[[ "$iso_output_host" != "$package_output_host" ]] || fail 'ISO and package output directories must differ'

require_empty_output() {
  local path=$1
  if [[ -e "$path" ]]; then
    [[ -d "$path" ]] || fail "build output already exists and is not a directory: $path"
    [[ -z $(find "$path" -mindepth 1 -maxdepth 1 -print -quit) ]] \
      || fail "build output is not empty; choose a new directory to avoid overwriting data: $path"
  fi
}
require_empty_output "$iso_output_host"
require_empty_output "$package_output_host"
[[ ! -e "$package_bundle_host" ]] \
  || fail "package bundle already exists; choose a fresh build directory: $package_bundle_host"
mkdir -p -- "$iso_output_host" "$package_output_host" "$(dirname -- "$package_bundle_host")"

source_env="$repo_root/distro/packages/deetty/source.env"
version=$(awk -F= '$1 == "DEETTY_VERSION" { print $2; exit }' "$source_env")
[[ -n "$version" ]] || fail 'Deetty source version is missing'
source_archive="$repo_root/distro/packages/deetty/noctty-$version.tar.gz"
if [[ ! -r "$source_archive" ]]; then
  source_checkout=${DEETTY_SOURCE_CHECKOUT:-"$repo_root/third_party/noctty"}
  if [[ "$source_checkout" != /* ]]; then
    source_checkout="$repo_root/$source_checkout"
  fi
  "$repo_root/scripts/prepare_first_party_apps.sh" "$source_checkout"
fi
"$repo_root/scripts/check_first_party_apps.sh"

case ${DINX_SKIP_CONTRACTS:-false} in
  true|1) ;;
  false|0) ZIG=${ZIG:-zig} "$repo_root/scripts/check_dinx_contracts.sh" ;;
  *) fail 'DINX_SKIP_CONTRACTS must be true/false or 1/0' ;;
esac

source_tree_sha256=
if [[ "$build_context" == local-docker ]]; then
  source_tree_sha256=$("$repo_root/scripts/hash-dinx-source-tree.sh" "$repo_root")
fi
require_persistent=${DINX_REQUIRE_PERSISTENT_PACKAGE_SIGNING:-false}
[[ "$require_persistent" == true || "$require_persistent" == false ]] \
  || fail 'DINX_REQUIRE_PERSISTENT_PACKAGE_SIGNING must be true or false'
if [[ "$require_persistent" == true ]]; then
  [[ -n ${DINX_PACKAGE_SIGNING_KEY:-} ]] || fail 'persistent signing requires DINX_PACKAGE_SIGNING_KEY'
  [[ ${DINX_PACKAGE_SIGNING_FINGERPRINT:-} =~ ^[A-Fa-f0-9]{40}$ ]] \
    || fail 'persistent signing requires a 40-hex DINX_PACKAGE_SIGNING_FINGERPRINT'
fi

keep_chroots=${DINX_KEEP_CHROOTS:-false}
case "$keep_chroots" in
  true|false|1|0) ;;
  *) fail 'DINX_KEEP_CHROOTS must be true/false or 1/0' ;;
esac
created_chroots=false
if [[ -n ${DINX_ISO_CHROOTS:-} ]]; then
  chroots_dir=$(realpath -m -- "$DINX_ISO_CHROOTS")
elif [[ "$build_context" == github-actions ]]; then
  chroots_dir="${RUNNER_TEMP:-/tmp}/dinx-artools"
else
  chroots_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-artools.XXXXXX")
  created_chroots=true
fi
case "$chroots_dir" in
  "$repo_root"|"$repo_root"/*)
    case "$chroots_dir" in
      "$repo_root"/dist/*) ;;
      *) fail "buildiso chroots inside the checkout must be under $repo_root/dist: $chroots_dir" ;;
    esac
    ;;
esac
mkdir -p -- "$chroots_dir"

cleanup() {
  local status=$?
  trap - EXIT
  if [[ "$created_chroots" == true ]]; then
    if (( status == 0 )) && [[ "$keep_chroots" != true && "$keep_chroots" != 1 ]]; then
      rm -rf -- "$chroots_dir"
    else
      printf 'build-iso-docker: keeping buildiso chroots at %s\n' "$chroots_dir" >&2
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

host_uid=$(id -u)
host_gid=$(id -g)
docker run --rm --privileged \
  --volume "$repo_root:/workspace" \
  --volume "$chroots_dir:/var/lib/artools/buildiso" \
  --workdir /workspace \
  --env DINX_ISO_OUTPUT="$iso_output_container" \
  --env DINX_PACKAGE_OUTPUT="$package_output_container" \
  --env DINX_COMMIT="$commit" \
  --env DINX_RUN_ID="$run_id" \
  --env DINX_REPOSITORY="$repository" \
  --env DINX_BUILD_CONTEXT="$build_context" \
  --env DINX_SOURCE_TREE_SHA256="$source_tree_sha256" \
  --env DINX_HOST_UID="$host_uid" \
  --env DINX_HOST_GID="$host_gid" \
  --env DINX_PACKAGE_SIGNING_KEY \
  --env DINX_PACKAGE_SIGNING_FINGERPRINT \
  --env DINX_REQUIRE_PERSISTENT_PACKAGE_SIGNING="$require_persistent" \
  --env DINX_ARTIX_IMAGE="$image" \
  "$image" \
  bash /workspace/scripts/build-iso-container.sh

if [[ ${DINX_SKIP_POSTBUILD_CHECKS:-false} != true ]]; then
  mapfile -t iso_paths < <(find "$iso_output_host" -type f -name '*.iso' -print | LC_ALL=C sort)
  (( ${#iso_paths[@]} == 1 )) \
    || fail "expected exactly one ISO under $iso_output_host; found ${#iso_paths[@]}"
  iso_path=${iso_paths[0]}
  metadata_path="$(dirname -- "$iso_path")/build-metadata.txt"
  [[ -r "$metadata_path" ]] || fail "build metadata missing: $metadata_path"
  (cd "$(dirname -- "$iso_path")" && sha512sum "$(basename -- "$iso_path")" > "$(basename -- "$iso_path").sha512")
  "$repo_root/scripts/check_build_metadata.sh" "$metadata_path" "$iso_path"
  "$repo_root/scripts/check-iso-content.sh" "$iso_path"
  DINX_ISO_PATH="$iso_path" "$repo_root/scripts/check_dinx_budget.sh"
  tar --format=posix --owner=0 --group=0 --numeric-owner \
    --directory "$(dirname -- "$package_output_host")" \
    --create --file "$package_bundle_host" packages
  [[ -s "$package_bundle_host" ]] || fail 'signed package repository bundle is empty'
  case ${DINX_LOCAL_QEMU_SMOKE:-false} in
    true|1)
      DINX_QEMU_TIMEOUT=${DINX_QEMU_TIMEOUT:-90} \
      DINX_QEMU_BOOT_KEYS=${DINX_QEMU_BOOT_KEYS:-down,down,ret} \
      DINX_QEMU_BOOT_SCREENSHOT=${DINX_QEMU_BOOT_SCREENSHOT:-$build_root/dinx-boot-screen.ppm} \
      DINX_QEMU_BOOT_SCREENSHOT_DELAY=${DINX_QEMU_BOOT_SCREENSHOT_DELAY:-3} \
      DINX_QEMU_SCREENSHOT=${DINX_QEMU_SCREENSHOT:-$build_root/dinx-graphical-screen.ppm} \
      DINX_QEMU_SCREENSHOT_DELAY=${DINX_QEMU_SCREENSHOT_DELAY:-60} \
      DINX_QEMU_POST_SCREENSHOT=${DINX_QEMU_POST_SCREENSHOT:-$build_root/dinx-session-screen.ppm} \
      DINX_QEMU_POST_SCREENSHOT_DELAY=${DINX_QEMU_POST_SCREENSHOT_DELAY:-10} \
        "$repo_root/scripts/smoke-iso.sh" "$iso_path"
      ;;
    false|0) ;;
    *) fail 'DINX_LOCAL_QEMU_SMOKE must be true/false or 1/0' ;;
  esac
  printf '\nDINX local ISO: %s\nSHA-512: %s\nBuild metadata: %s\nSigned package repository: %s (ephemeral key)\n' \
    "$iso_path" "$(cut -d ' ' -f 1 "$(dirname -- "$iso_path")/$(basename -- "$iso_path").sha512")" \
    "$metadata_path" "$package_bundle_host"
else
  printf 'build-iso-docker: Artix ISO build completed; post-build checks were skipped by request\n'
fi
