#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -eq 1 && "$1" == -Qq ]]; then
  case "${MOCK_MODE:-complete}" in
    complete) printf '%s\n' direct-package member-a member-b ;;
    missing-member) printf '%s\n' direct-package member-a ;;
    missing-package) printf '%s\n' direct-package ;;
    *) exit 2 ;;
  esac
  exit 0
fi
if [[ "$#" -eq 2 && "$1" == -Sgq && "$2" == test-tools ]]; then
  printf '%s\n' member-a member-b
  exit 0
fi
if [[ "$#" -eq 2 && "$1" == -Sgq ]]; then
  exit 1
fi
printf 'unexpected pacman invocation: %s\n' "$*" >&2
exit 2
MOCK
chmod +x "$tmp/bin/pacman"
printf '%s\n' 'direct-package' '# test-tools group' 'test-tools' > "$tmp/manifest"

PATH="$tmp/bin:$PATH" "$root/scripts/check_iso_builder_packages.sh" "$tmp/manifest"

if MOCK_MODE=missing-member PATH="$tmp/bin:$PATH" \
  "$root/scripts/check_iso_builder_packages.sh" "$tmp/manifest" >"$tmp/missing-member.log" 2>&1; then
  printf 'builder package smoke: accepted a group with an uninstalled member\n' >&2
  exit 1
fi
grep -Fq 'group test-tools is missing installed member member-b' "$tmp/missing-member.log" || {
  cat "$tmp/missing-member.log" >&2
  printf 'builder package smoke: missing group member diagnostic was not precise\n' >&2
  exit 1
}

printf '%s\n' 'direct-package' 'missing-package' > "$tmp/missing-package-manifest"
if MOCK_MODE=missing-package PATH="$tmp/bin:$PATH" \
  "$root/scripts/check_iso_builder_packages.sh" "$tmp/missing-package-manifest" >"$tmp/missing-package.log" 2>&1; then
  printf 'builder package smoke: accepted a missing package/group manifest entry\n' >&2
  exit 1
fi
grep -Fq 'neither installed nor an available sync group: missing-package' "$tmp/missing-package.log" || {
  cat "$tmp/missing-package.log" >&2
  printf 'builder package smoke: missing package diagnostic was not precise\n' >&2
  exit 1
}

printf 'iso_builder_package_smoke installed_package=true group_expansion=true missing_member_rejected=true missing_entry_rejected=true\n'
