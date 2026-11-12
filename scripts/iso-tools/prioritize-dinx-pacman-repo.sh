#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'prioritize-dinx-pacman-repo: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || fail 'usage: prioritize-dinx-pacman-repo.sh PACMAN_CONF DINX_SERVER_URL'
config=$1
server=$2
[[ -f "$config" ]] || fail "pacman config not found: $config"
[[ "$server" =~ ^https?://[^[:space:]]+$ ]] || fail "invalid DINX repository URL: $server"
if grep -Eq '^[[:space:]]*\[dinx\][[:space:]]*$' "$config"; then
  fail 'config already contains a [dinx] repository section'
fi

tmp=$(mktemp "${config}.dinx.XXXXXX") || fail 'cannot create temporary pacman config'
trap 'rm -f -- "$tmp"' EXIT
if ! awk -v server="$server" '
  function trim(value) {
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    return value
  }
  BEGIN { options_seen = 0; repo_inserted = 0 }
  {
    line = $0
    if (line ~ /^[[:space:]]*\[[[:alnum:]_-]+\][[:space:]]*$/) {
      section = trim(line)
      if (section == "[options]") {
        options_seen = 1
      } else if (!repo_inserted) {
        print "[dinx]"
        print "SigLevel = Required"
        print "Server = " server
        print ""
        repo_inserted = 1
      }
    }
    print line
  }
  END { if (!options_seen || !repo_inserted) exit 1 }
' "$config" > "$tmp"; then
  fail 'config must contain [options] and at least one repository section'
fi
if ! awk '
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
  }
  END { if (!first_repo_seen || dinx_count != 1) exit 1 }
' "$tmp"; then
  fail 'DINX must be the first and only [dinx] sync repository'
fi
chmod --reference="$config" "$tmp"
mv -- "$tmp" "$config"
trap - EXIT
printf 'dinx_pacman_repo_priority first_repository=dinx url=%s\n' "$server"
