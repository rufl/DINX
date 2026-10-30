#!/usr/bin/env bash
set -euo pipefail

repo_root=${1:-$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}
repo_root=$(CDPATH= cd -- "$repo_root" && pwd -P)
git -C "$repo_root" rev-parse --verify HEAD >/dev/null 2>&1 || {
  printf 'hash-dinx-source-tree: not a Git checkout with HEAD: %s\n' "$repo_root" >&2
  exit 1
}

mapfile -d '' -t untracked_paths < <(
  git -C "$repo_root" ls-files --others --exclude-standard -z -- . ':(exclude)dist/**'
)
{
  printf 'tracked-diff\0'
  git -C "$repo_root" diff --binary HEAD --
  printf '\0untracked-files\0'
  if (( ${#untracked_paths[@]} > 0 )); then
    tar --format=posix --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
      --pax-option=delete=atime,delete=ctime --create --file=- --directory="$repo_root" \
      -- "${untracked_paths[@]}"
  fi
} | sha256sum | cut -d ' ' -f 1
