#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
manifest="$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json"
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
common="$repo_root/distro/iso/iso-profiles/common/common.yaml"

fail() {
  printf 'feature_groups_contract: %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail 'jq is not installed'
[[ -r "$manifest" ]] || fail "feature-group manifest is missing: $manifest"
[[ -r "$profile" ]] || fail "DINX profile is missing: $profile"
[[ -r "$common" ]] || fail "common profile is missing: $common"
jq -e '
  .schema == "dinx-feature-groups/v1" and
  (.groups | type == "object") and
  (.inputs | type == "object")
' "$manifest" >/dev/null || fail 'invalid feature-group manifest schema'

group_file=$(mktemp)
profile_file=$(mktemp)
common_file=$(mktemp)
common_init_file=$(mktemp)
common_boot_file=$(mktemp)
profile_init_file=$(mktemp)
livefs_file=$(mktemp)
manifest_input_file=$(mktemp)
trap 'rm -f "$group_file" "$profile_file" "$common_file" "$common_init_file" "$common_boot_file" "$profile_init_file" "$livefs_file" "$manifest_input_file"' EXIT

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

{
  awk '/^packages-base:/{f=1;next}/^packages-apps:/{f=0} f&&/^  - /{sub(/^  - /,""); print}' "$common"
  awk '/^packages-apps:/{f=1;next}/^packages-misc:/{f=0} f&&/^  - /{sub(/^  - /,""); print}' "$common"
  awk '/^packages-misc:/{f=1;next}/^packages-init:/{f=0} f&&/^  - /{sub(/^  - /,""); print}' "$common"
} | LC_ALL=C sort -u > "$common_file"
awk '/^  dinit:/{f=1;next}/^  openrc:/{f=0} f&&/^    - /{sub(/^    - /,""); print}' "$common" \
  | LC_ALL=C sort -u > "$common_init_file"
awk '/^packages-boot:/{f=1;next} f&&/^  - /{sub(/^  - /,""); print}' "$common" \
  | LC_ALL=C sort -u > "$common_boot_file"
awk '/^  packages-init:/{f=1;next}/^livefs:/{f=0} f&&/^      - /{sub(/^      - /,""); print}' "$profile" \
  | LC_ALL=C sort -u > "$profile_init_file"
awk '/^livefs:/{f=1;next} f&&/^    - /{sub(/^    - /,""); print} f&&/^      - /{sub(/^      - /,""); print}' "$profile" \
  | LC_ALL=C sort -u > "$livefs_file"

check_input_set() {
  key=$1
  expected=$2
  jq -r --arg key "$key" '.inputs[$key][]' "$manifest" | LC_ALL=C sort > "$manifest_input_file"
  [[ -s "$manifest_input_file" ]] || fail "input inventory is empty: $key"
  if duplicate=$(uniq -d "$manifest_input_file"); [[ -n "$duplicate" ]]; then
    printf '%s\n' "$duplicate" >&2
    fail "input inventory contains a duplicate: $key"
  fi
  if ! cmp -s "$expected" "$manifest_input_file"; then
    diff -u "$expected" "$manifest_input_file" >&2 || true
    fail "input inventory does not match its source: $key"
  fi
}

check_input_set common "$common_file"
check_input_set common_init "$common_init_file"
check_input_set common_boot "$common_boot_file"
check_input_set profile_init "$profile_init_file"
check_input_set livefs "$livefs_file"

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

printf 'feature_groups_contract schema=dinx-feature-groups/v1 groups=%s rootfs_packages=%s input_inventory=true optional_iso=false\n' \
  "$(jq '.groups | length' "$manifest")" "$(wc -l < "$profile_file")"
