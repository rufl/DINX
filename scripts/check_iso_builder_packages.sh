#!/usr/bin/env bash
set -euo pipefail

manifest=${1:?usage: check_iso_builder_packages.sh PACKAGE_MANIFEST}
[[ -r "$manifest" ]] || {
  printf 'builder package check: cannot read manifest: %s\n' "$manifest" >&2
  exit 1
}

installed_output=$(pacman -Qq) || {
  printf 'builder package check: cannot query installed packages\n' >&2
  exit 1
}
declare -A installed_packages=()
while IFS= read -r package; do
  [[ -n "$package" ]] && installed_packages["$package"]=1
done <<< "$installed_output"

required_entries=0
while IFS= read -r entry || [[ -n "$entry" ]]; do
  [[ -n "$entry" && "$entry" != \#* ]] || continue
  ((required_entries += 1))
  [[ -n "${installed_packages[$entry]+present}" ]] && continue

  group_members=$(pacman -Sgq "$entry" 2>/dev/null) || {
    printf 'builder package check: manifest entry is neither installed nor an available sync group: %s\n' "$entry" >&2
    exit 1
  }
  [[ -n "$group_members" ]] || {
    printf 'builder package check: sync group has no members: %s\n' "$entry" >&2
    exit 1
  }
  while IFS= read -r member; do
    [[ -n "$member" ]] || continue
    [[ -n "${installed_packages[$member]+present}" ]] || {
      printf 'builder package check: group %s is missing installed member %s\n' "$entry" "$member" >&2
      exit 1
    }
  done <<< "$group_members"
done < "$manifest"

((required_entries > 0)) || {
  printf 'builder package check: manifest has no package entries: %s\n' "$manifest" >&2
  exit 1
}
