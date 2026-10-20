#!/usr/bin/env bash
set -euo pipefail

repo_dir=${1:-}

fail() {
  printf 'package_repository_contract: %s\n' "$*" >&2
  exit 1
}

[[ -n "$repo_dir" ]] || fail "usage: $0 REPOSITORY_DIR"
[[ -d "$repo_dir" ]] || fail "repository directory does not exist: $repo_dir"
command -v gpg >/dev/null 2>&1 || fail 'gpg is not installed'
command -v bsdtar >/dev/null 2>&1 || fail 'bsdtar is not installed'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is not installed'

metadata="$repo_dir/dinx-repository-metadata.txt"
key_file="$repo_dir/dinx-package-signing-key.gpg"
database="$repo_dir/dinx.db.tar.gz"
[[ -r "$metadata" ]] || fail "repository metadata is missing: $metadata"
[[ -r "$key_file" ]] || fail "repository signing key is missing: $key_file"
[[ -s "$database" ]] || fail "repository database is missing: $database"

read_value() {
  local key=$1
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$metadata"
}

require_value() {
  local key=$1
  local pattern=$2
  local value
  value=$(read_value "$key")
  [[ -n "$value" ]] || fail "missing repository metadata field: $key"
  [[ "$value" =~ $pattern ]] || fail "invalid repository metadata field $key: $value"
}

[[ "$(read_value schema)" == 'dinx-package-repository/v1' ]] || fail 'unsupported repository metadata schema'
require_value channel '^(ci|testing|stable)$'
require_value snapshot '^[0-9a-f]{64}$'
require_value signing_fingerprint '^[A-Fa-f0-9]{40}$'
require_value package_count '^[1-9][0-9]*$'
require_value publication '^github-release-assets/v1$'
require_value database_sha256 '^[0-9a-f]{64}$'
require_value key_sha256 '^[0-9a-f]{64}$'

mapfile -d '' packages < <(
  find "$repo_dir" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0 | sort -z
)
(( ${#packages[@]} > 0 )) || fail 'repository contains no package archives'
actual_count=${#packages[@]}
expected_count=$(read_value package_count)
[[ "$actual_count" == "$expected_count" ]] || fail "package count mismatch: metadata=$expected_count actual=$actual_count"

package_snapshot=$(
  for package in "${packages[@]}"; do
    name=$(basename "$package")
    digest=$(sha256sum "$package" | cut -d ' ' -f 1)
    printf '%s  %s\n' "$digest" "$name"
  done | LC_ALL=C sort | sha256sum | cut -d ' ' -f 1
)
[[ "$package_snapshot" == "$(read_value snapshot)" ]] || fail 'repository package snapshot does not match metadata'
actual_database_sha256=$(sha256sum "$database" | cut -d ' ' -f 1)
actual_key_sha256=$(sha256sum "$key_file" | cut -d ' ' -f 1)
[[ "$actual_database_sha256" == "$(read_value database_sha256)" ]] \
  || fail 'repository database checksum does not match metadata'
[[ "$actual_key_sha256" == "$(read_value key_sha256)" ]] \
  || fail 'repository key checksum does not match metadata'

fingerprint=$(tr '[:lower:]' '[:upper:]' <<<"$(read_value signing_fingerprint)")
gpg_home=$(mktemp -d)
ownership_file=$(mktemp)
trap 'rm -rf "$gpg_home" "$ownership_file"' EXIT
chmod 700 "$gpg_home"
gpg --batch --homedir "$gpg_home" --import "$key_file" >/dev/null 2>&1 || fail 'repository signing key could not be imported'
actual_fingerprint=$(gpg --batch --homedir "$gpg_home" --with-colons --list-keys \
  | awk -F: '$1 == "fpr" { print toupper($10); exit }')
[[ "$actual_fingerprint" == "$fingerprint" ]] || fail "repository signing fingerprint mismatch: metadata=$fingerprint key=$actual_fingerprint"

verify_signature() {
  local file=$1
  local signature="$file.sig"
  local status_file
  [[ -s "$signature" ]] || fail "signature is missing: $(basename "$signature")"
  status_file=$(mktemp)
  if ! gpg --batch --homedir "$gpg_home" --status-fd=1 --verify "$signature" "$file" >"$status_file" 2>&1; then
    cat "$status_file" >&2
    rm -f "$status_file"
    fail "signature verification failed: $(basename "$file")"
  fi
  grep -Fq "VALIDSIG $fingerprint " "$status_file" || {
    cat "$status_file" >&2
    rm -f "$status_file"
    fail "signature is not from the declared repository key: $(basename "$file")"
  }
  rm -f "$status_file"
}

verify_signature "$database"
for package in "${packages[@]}"; do
  verify_signature "$package"
done

: > "$ownership_file"
for package in "${packages[@]}"; do
  package_name=$(basename "$package")
  while IFS= read -r path; do
    path=${path#./}
    case "$path" in
      ''|.PKGINFO|.BUILDINFO|.MTREE|.INSTALL|*/)
        continue
        ;;
    esac
    printf '%s\t%s\n' "$path" "$package_name" >> "$ownership_file"
  done < <(bsdtar -tf "$package")
done

duplicates=$(LC_ALL=C sort -t $'\t' -k1,1 -k2,2 "$ownership_file" \
  | awk -F '\t' '
      $1 == previous_path && $2 != previous_package {
        print previous_path ": " previous_package ", " $2
      }
      { previous_path = $1; previous_package = $2 }
    ')
[[ -z "$duplicates" ]] || {
  printf '%s\n' "$duplicates" >&2
  fail 'package archives contain duplicate non-directory paths'
}

rootfs=${DINX_PACKAGE_ROOTFS:-}
if [[ -n "$rootfs" ]]; then
  [[ -d "$rootfs" ]] || fail "DINX_PACKAGE_ROOTFS does not exist: $rootfs"
  command -v pacman >/dev/null 2>&1 || fail 'pacman is required for rootfs ownership checks'
  while IFS=$'\t' read -r path _package_name; do
    [[ -n "$path" ]] || continue
    pacman --root "$rootfs" -Qo "/$path" >/dev/null 2>&1 \
      || fail "installed rootfs has no pacman owner for: /$path"
  done < "$ownership_file"
  ownership_state=rootfs_verified
else
  ownership_state=archive_verified
fi

printf 'package_repository_contract schema=dinx-package-repository/v1 channel=%s publication=%s packages=%s signed=true conflicts=false snapshot=%s database_sha256=%s key_sha256=%s ownership=%s\n' \
  "$(read_value channel)" "$(read_value publication)" "$actual_count" "$package_snapshot" \
  "$actual_database_sha256" "$actual_key_sha256" "$ownership_state"
