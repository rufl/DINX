#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
helper="$root/scripts/iso-tools/prioritize-dinx-pacman-repo.sh"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-pacman-repo-priority.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

fail() {
  printf 'smoke_dinx_pacman_repo_priority: %s\n' "$*" >&2
  exit 1
}

config="$work_dir/iso-x86_64.conf"
cat > "$config" <<'EOF'
[options]
Architecture = auto
DownloadUser = root

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist
EOF

"$helper" "$config" http://127.0.0.1:8765 > "$work_dir/helper.log"
grep -Fqx 'dinx_pacman_repo_priority first_repository=dinx url=http://127.0.0.1:8765' "$work_dir/helper.log" \
  || fail 'helper did not report the injected priority repository'
grep -Fqx 'Architecture = auto' "$config" || fail 'existing pacman options were not preserved'
grep -Fqx 'DownloadUser = root' "$config" || fail 'existing pacman download-user option was not preserved'
grep -Fqx 'SigLevel = Required' "$config" || fail 'DINX repository signatures are not required'
grep -Fqx 'Server = http://127.0.0.1:8765' "$config" || fail 'DINX repository URL is incorrect'
awk '
  function trim(value) {
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    return value
  }
  /^[[:space:]]*\[[[:alnum:]_-]+\][[:space:]]*$/ {
    section = trim($0)
    if (section == "[options]") next
    if (!first_repo_seen) {
      if (section != "[dinx]") exit 1
      first_repo_seen = 1
    }
    if (section == "[dinx]") dinx_count++
    if (section == "[core]") core_position = NR
    if (section == "[extra]") extra_position = NR
  }
  END {
    if (!first_repo_seen || dinx_count != 1 || core_position <= 0 || extra_position <= core_position) exit 1
  }
' "$config" || fail 'DINX is not first or Artix repository order changed'

cp -- "$config" "$work_dir/expected.conf"
if "$helper" "$config" http://127.0.0.1:8765 >/dev/null 2>&1; then
  fail 'duplicate DINX repository injection unexpectedly succeeded'
fi
cmp -s -- "$config" "$work_dir/expected.conf" || fail 'duplicate-injection failure changed the config'

invalid_config="$work_dir/no-repositories.conf"
printf '[options]\nArchitecture = auto\n' > "$invalid_config"
cp -- "$invalid_config" "$work_dir/invalid.expected"
if "$helper" "$invalid_config" http://127.0.0.1:8765 >/dev/null 2>&1; then
  fail 'config without a repository unexpectedly succeeded'
fi
cmp -s -- "$invalid_config" "$work_dir/invalid.expected" || fail 'invalid-config failure changed the config'

printf 'smoke_dinx_pacman_repo_priority dinx_first=true artix_order_preserved=true required_signature=true duplicate_rejected=true invalid_config_unchanged=true\n'
