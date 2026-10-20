#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
manifest="$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json"
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"

fail() {
  printf 'feature_groups_contract: %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail 'jq is not installed'
[[ -r "$manifest" ]] || fail "feature-group manifest is missing: $manifest"
[[ -r "$profile" ]] || fail "DINX profile is missing: $profile"
jq -e '.schema == "dinx-feature-groups/v1" and (.groups | type == "object")' "$manifest" >/dev/null \
  || fail 'invalid feature-group manifest schema'

group_file=$(mktemp)
profile_file=$(mktemp)
trap 'rm -f "$group_file" "$profile_file"' EXIT
jq -r '.groups[] | .packages[]' "$manifest" | LC_ALL=C sort > "$group_file"
[[ -s "$group_file" ]] || fail 'feature-group manifest contains no packages'

if duplicate=$(uniq -d "$group_file"); [[ -n "$duplicate" ]]; then
  printf '%s\n' "$duplicate" >&2
  fail 'a package appears in more than one feature group'
fi

awk '
  /^rootfs:/ { in_rootfs = 1; next }
  in_rootfs && /^livefs:/ { exit }
  in_rootfs && /^    - / {
    sub(/^    - /, "")
    print
  }
' "$profile" | LC_ALL=C sort > "$profile_file"
[[ -s "$profile_file" ]] || fail 'profile rootfs package list is empty'

while IFS= read -r package; do
  grep -Fqx "$package" "$group_file" || fail "profile package is not assigned to a feature group: $package"
done < "$profile_file"

while IFS= read -r group; do
  iso=$(jq -r --arg group "$group" '.groups[$group].iso' "$manifest")
  [[ "$iso" == true || "$iso" == false ]] || fail "group $group has invalid iso flag"
  mapfile -t packages < <(jq -r --arg group "$group" '.groups[$group].packages[]' "$manifest")
  (( ${#packages[@]} > 0 )) || fail "group $group contains no packages"
  for package in "${packages[@]}"; do
    if [[ "$iso" == true ]]; then
      grep -Fqx "$package" "$profile_file" || fail "ISO group $group references a package absent from profile: $package"
    else
      grep -Fqx "$package" "$profile_file" && fail "optional package is present in the base ISO profile: $package"
    fi
  done
done < <(jq -r '.groups | keys[]' "$manifest")

printf 'feature_groups_contract schema=dinx-feature-groups/v1 groups=%s rootfs_packages=%s coverage=true optional_iso=false\n' \
  "$(jq '.groups | length' "$manifest")" "$(wc -l < "$profile_file")"
