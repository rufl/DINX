#!/usr/bin/env bash

_DINX_PACKAGE_CACHE_SCHEMA=dinx-package-artifact-cache/v1

_dinx_package_cache_valid_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9+_-]*$ ]]
}

_dinx_package_cache_valid_key() {
  [[ "$1" =~ ^[0-9a-f]{64}$ ]]
}

_dinx_package_cache_valid_archive_name() {
  [[ "$1" =~ ^[A-Za-z0-9+._:-]+\.pkg\.tar\.zst$ ]]
}

# Key the package source tree and its effective build environment, not the full DINX checkout.
dinx_package_cache_key() {
  (($# >= 6)) || return 2
  local package=$1
  local package_dir=$2
  local makepkg_conf_sha256=$3
  local builder_sha256=$4
  local installed_packages_sha256=$5
  shift 5
  _dinx_package_cache_valid_name "$package" || return 2
  [[ -d "$package_dir" && ! -L "$package_dir" ]] || return 2
  [[ "$makepkg_conf_sha256" =~ ^[0-9a-f]{64}$ ]] || return 2
  [[ "$builder_sha256" =~ ^[0-9a-f]{64}$ ]] || return 2
  [[ "$installed_packages_sha256" =~ ^[0-9a-f]{64}$ ]] || return 2

  local -a makepkg_options=() extra_env=()
  local parse_environment=false
  local arg
  for arg in "$@"; do
    if [[ "$arg" == -- && "$parse_environment" == false ]]; then
      parse_environment=true
      continue
    fi
    if [[ "$parse_environment" == true ]]; then
      extra_env+=("$arg")
    else
      makepkg_options+=("$arg")
    fi
  done
  [[ "$parse_environment" == true ]] || return 2

  local library_sha256
  library_sha256=$(sha256sum -- "${BASH_SOURCE[0]}") || return 2
  library_sha256=${library_sha256%% *}
  local zig_path zig_sha256
  local -a zig_hashes=()
  for arg in "${extra_env[@]}"; do
    if [[ "$arg" == ZIG=* ]]; then
      zig_path=${arg#ZIG=}
      [[ -x "$zig_path" && ! -L "$zig_path" ]] || return 2
      zig_sha256=$(sha256sum -- "$zig_path") || return 2
      zig_hashes+=("${zig_sha256%% *}")
    fi
  done

  local -a source_excludes=(
    --exclude='./pkg'
    --exclude='./.git' --exclude='*/.git'
    --exclude='./.zig-cache' --exclude='./zig-cache' --exclude='./zig-out' --exclude='./target'
    --exclude='*/.zig-cache' --exclude='*/zig-cache' --exclude='*/zig-out' --exclude='*/target'
    --exclude='*.pkg.tar.*' --exclude='*.sig'
  )
  case "$package" in
    dinitui|dinxpanel|seafoam-settings)
      source_excludes+=(--exclude='./src/stage')
      ;;
    *)
      source_excludes+=(--exclude='./src')
      ;;
  esac

  local result
  result=$(
    {
      printf 'schema=%s\n' "$_DINX_PACKAGE_CACHE_SCHEMA"
      printf 'package=%s\n' "$package"
      printf 'makepkg_conf_sha256=%s\n' "$makepkg_conf_sha256"
      printf 'builder_sha256=%s\n' "$builder_sha256"
      printf 'cache_implementation_sha256=%s\n' "$library_sha256"
      printf 'installed_packages_sha256=%s\n' "$installed_packages_sha256"
      for arg in "${makepkg_options[@]}"; do
        printf 'makepkg_option=%q\n' "$arg"
      done
      local index=0
      for arg in "${extra_env[@]}"; do
        printf 'build_environment=%q\n' "$arg"
        if [[ "$arg" == ZIG=* ]]; then
          printf 'zig_binary_%s_sha256=%s\n' "$index" "${zig_hashes[0]}"
          zig_hashes=("${zig_hashes[@]:1}")
        fi
        index=$((index + 1))
      done
      printf 'source_tree_begin\n'
      tar --format=posix --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
        --pax-option=delete=atime,delete=ctime --wildcards --wildcards-match-slash \
        "${source_excludes[@]}" \
        --create --file=- --directory="$package_dir" .
    } | sha256sum
  ) || return 2
  printf '%s\n' "${result%% *}"
}

_dinx_package_cache_entry_valid() {
  local entry=$1 package=$2 key=$3
  [[ -d "$entry" && ! -L "$entry" ]] || return 1
  [[ -f "$entry/metadata" && ! -L "$entry/metadata" ]] || return 1
  [[ -f "$entry/SHA256SUMS" && ! -L "$entry/SHA256SUMS" ]] || return 1
  grep -Fxc "schema=$_DINX_PACKAGE_CACHE_SCHEMA" "$entry/metadata" | grep -Fxq 1 || return 1
  grep -Fxc "package=$package" "$entry/metadata" | grep -Fxq 1 || return 1
  grep -Fxc "key=$key" "$entry/metadata" | grep -Fxq 1 || return 1
  [[ $(grep -Ec '^archive_count=' "$entry/metadata") -eq 1 ]] || return 1
  local archive_count
  archive_count=$(awk -F= '$1 == "archive_count" { print $2; exit }' "$entry/metadata")
  [[ "$archive_count" =~ ^[1-9][0-9]*$ ]] || return 1

  local -a archives=() checksummed=()
  mapfile -t archives < <(find "$entry" -maxdepth 1 -type f -name '*.pkg.tar.zst' -printf '%f\n' | LC_ALL=C sort)
  (( ${#archives[@]} == archive_count )) || return 1
  local digest name
  while read -r digest name; do
    [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || return 1
    _dinx_package_cache_valid_archive_name "$name" || return 1
    checksummed+=("$name")
  done < "$entry/SHA256SUMS"
  (( ${#checksummed[@]} == archive_count )) || return 1
  local index
  for ((index = 0; index < archive_count; index++)); do
    [[ "${archives[index]}" == "${checksummed[index]}" ]] || return 1
  done
  (cd "$entry" && sha256sum --check --status SHA256SUMS) || return 1
}

dinx_package_cache_restore() {
  (($# == 5)) || return 2
  local cache_root=$1 package=$2 key=$3 package_repo=$4 signing_home=$5
  _dinx_package_cache_valid_name "$package" || return 2
  _dinx_package_cache_valid_key "$key" || return 2
  [[ -d "$cache_root" && ! -L "$cache_root" ]] || return 1
  local package_root="$cache_root/$package"
  if [[ ! -e "$package_root" && ! -L "$package_root" ]]; then
    return 1
  fi
  [[ -d "$package_root" && ! -L "$package_root" ]] || return 2
  local entry="$package_root/$key"
  [[ -e "$entry" || -L "$entry" ]] || return 1
  if ! _dinx_package_cache_entry_valid "$entry" "$package" "$key"; then
    printf 'dinx-package-cache: corrupt entry; rebuilding package=%s key=%s\n' "$package" "$key" >&2
    rm -rf -- "$entry" || return 2
    return 1
  fi
  [[ -d "$package_repo" && ! -L "$package_repo" ]] || return 2
  [[ -d "$signing_home" && ! -L "$signing_home" ]] || return 2

  local staging name
  staging=$(mktemp -d "$package_repo/.dinx-cache-restore.XXXXXXXX") || return 2
  local -a archives=()
  mapfile -t archives < <(find "$entry" -maxdepth 1 -type f -name '*.pkg.tar.zst' -printf '%f\n' | LC_ALL=C sort)
  for name in "${archives[@]}"; do
    if [[ -e "$package_repo/$name" || -L "$package_repo/$name" ]]; then
      rm -rf -- "$staging"
      return 2
    fi
    if ! cp -- "$entry/$name" "$staging/$name" \
      || ! gpg --batch --yes --homedir "$signing_home" --detach-sign \
        --output "$staging/$name.sig" "$staging/$name"; then
      rm -rf -- "$staging"
      return 2
    fi
  done
  for name in "${archives[@]}"; do
    if ! mv -- "$staging/$name" "$package_repo/$name" \
      || ! mv -- "$staging/$name.sig" "$package_repo/$name.sig"; then
      rm -rf -- "$staging"
      return 2
    fi
  done
  rm -rf -- "$staging"
  printf 'dinx-package-cache: hit package=%s archives=%s\n' "$package" "${#archives[@]}"
}

dinx_package_cache_store() {
  (($# >= 4)) || return 1
  local cache_root=$1 package=$2 key=$3
  shift 3
  local -a package_archives=("$@")
  _dinx_package_cache_valid_name "$package" || return 1
  _dinx_package_cache_valid_key "$key" || return 1
  (( ${#package_archives[@]} > 0 )) || return 1
  mkdir -p -- "$cache_root" || return 1
  [[ -d "$cache_root" && ! -L "$cache_root" ]] || return 1
  local package_root="$cache_root/$package"
  mkdir -p -- "$package_root" || return 1
  [[ -d "$package_root" && ! -L "$package_root" ]] || return 1

  local temporary
  temporary=$(mktemp -d "$package_root/.$key.tmp.XXXXXXXX") || return 1
  local archive name
  local -a archive_names=()
  local -A seen_names=()
  for archive in "${package_archives[@]}"; do
    [[ -f "$archive" && ! -L "$archive" ]] || { rm -rf -- "$temporary"; return 1; }
    name=$(basename -- "$archive")
    _dinx_package_cache_valid_archive_name "$name" || { rm -rf -- "$temporary"; return 1; }
    [[ -z ${seen_names[$name]+present} ]] || { rm -rf -- "$temporary"; return 1; }
    seen_names[$name]=1
    archive_names+=("$name")
    cp -- "$archive" "$temporary/$name" || { rm -rf -- "$temporary"; return 1; }
  done
  mapfile -t archive_names < <(printf '%s\n' "${archive_names[@]}" | LC_ALL=C sort)
  if ! (
    cd "$temporary" || exit 1
    {
      printf 'schema=%s\n' "$_DINX_PACKAGE_CACHE_SCHEMA"
      printf 'package=%s\n' "$package"
      printf 'key=%s\n' "$key"
      printf 'archive_count=%s\n' "${#archive_names[@]}"
    } > metadata
    sha256sum -- "${archive_names[@]}" > SHA256SUMS
  ); then
    rm -rf -- "$temporary"
    return 1
  fi
  [[ -d "$temporary" && ! -L "$temporary" && -O "$temporary" ]] \
    || { rm -rf -- "$temporary"; return 1; }

  local entry="$package_root/$key"
  if [[ -e "$entry" || -L "$entry" ]]; then
    if _dinx_package_cache_entry_valid "$entry" "$package" "$key"; then
      rm -rf -- "$temporary"
      return 0
    fi
    rm -rf -- "$entry" || { rm -rf -- "$temporary"; return 1; }
  fi
  if mv -T -- "$temporary" "$entry"; then
    printf 'dinx-package-cache: stored package=%s archives=%s\n' "$package" "${#archive_names[@]}"
    return 0
  fi
  if _dinx_package_cache_entry_valid "$entry" "$package" "$key"; then
    rm -rf -- "$temporary"
    return 0
  fi
  rm -rf -- "$temporary"
  return 1
}
dinx_invalidate_pacman_package_cache() {
  (($# == 2)) || return 2
  local package_repo=$1 pacman_cache=$2 archive name count=0
  [[ -d "$package_repo" && ! -L "$package_repo" ]] || return 2
  [[ -d "$pacman_cache" && ! -L "$pacman_cache" ]] || return 2
  local -a package_archives=("$package_repo"/*.pkg.tar.zst)
  for archive in "${package_archives[@]}"; do
    [[ -f "$archive" && ! -L "$archive" ]] || continue
    name=${archive##*/}
    rm -f -- "$pacman_cache/$name" "$pacman_cache/$name.sig" || return 2
    count=$((count + 1))
  done
  printf 'dinx-package-cache: invalidated pacman repository entries=%s\n' "$count"
}
