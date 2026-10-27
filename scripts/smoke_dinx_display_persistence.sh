#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-wdisplays"
saver="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-save-shikane-profile"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fakebin="$tmp/bin"
state="$tmp/state"
config_home="$tmp/config"
mkdir -p "$fakebin" "$state" "$config_home/shikane"

cat >"$fakebin/wdisplays" <<'EOF'
#!/bin/sh
: > "$DINX_DISPLAY_SMOKE_STATE/wdisplays-ran"
if [ "${DINX_DISPLAY_SMOKE_FAIL:-0}" = 1 ]; then
    exit 7
fi
EOF
cat >"$fakebin/shikanectl" <<'EOF'
#!/bin/sh
set -eu
case "${1:-}" in
    export)
        [ "${2:-}" = 'DINX wdisplays' ]
        printf '[[profile]]\n'
        printf 'name = "DINX wdisplays"\n'
        printf '[[profile.output]]\n'
        printf 'search = "n=DP-1"\n'
        printf 'enable = true\n'
        if [ "${DINX_DISPLAY_SMOKE_MODE:-1}" = 2 ]; then
            printf 'position = "10,20"\n'
        else
            printf 'position = "0,0"\n'
        fi
        ;;
    reload)
        if [ "${DINX_DISPLAY_SMOKE_MODE:-1}" = 3 ]; then
            exit 9
        fi
        : > "$DINX_DISPLAY_SMOKE_STATE/reloaded"
        ;;
    *)
        exit 2
        ;;
esac
EOF
chmod +x "$fakebin/wdisplays" "$fakebin/shikanectl"

cat >"$config_home/shikane/config.toml" <<'EOF'
timeout = 0

[[profile]]
name = "keep-me"
[[profile.output]]
search = "n=eDP-1"
enable = true
EOF

export DINX_DISPLAY_SMOKE_STATE="$state"
export XDG_CONFIG_HOME="$config_home"
export HOME="$tmp/home"
export PATH="$fakebin:$(dirname "$launcher"):$PATH"

"$launcher"
grep -Fqx 'name = "keep-me"' "$config_home/shikane/config.toml"
grep -Fqx 'position = "0,0"' "$config_home/shikane/config.toml"
[[ $(grep -Fc 'name = "DINX wdisplays"' "$config_home/shikane/config.toml") -eq 1 ]]
test -e "$state/wdisplays-ran"
test -e "$state/reloaded"

export DINX_DISPLAY_SMOKE_MODE=2
"$saver"
grep -Fqx 'position = "10,20"' "$config_home/shikane/config.toml"
if grep -Fq 'position = "0,0"' "$config_home/shikane/config.toml"; then
    printf 'smoke: stale generated position survived replacement\n' >&2
    exit 1
fi
[[ $(grep -Fc 'name = "DINX wdisplays"' "$config_home/shikane/config.toml") -eq 1 ]]

before=$(sha256sum "$config_home/shikane/config.toml" | cut -d ' ' -f 1)
export DINX_DISPLAY_SMOKE_FAIL=1
if "$launcher"; then
    printf 'smoke: failing wdisplays unexpectedly succeeded\n' >&2
    exit 1
fi
after=$(sha256sum "$config_home/shikane/config.toml" | cut -d ' ' -f 1)
test "$before" = "$after"
export DINX_DISPLAY_SMOKE_FAIL=0
export DINX_DISPLAY_SMOKE_MODE=3
if "$saver"; then
    printf 'smoke: failing Shikane reload unexpectedly succeeded\n' >&2
    exit 1
fi
grep -Fqx 'position = "0,0"' "$config_home/shikane/config.toml"

printf 'dinx_display_persistence_smoke save=true replace=true failure_safe=true reload=true reload_failure=true\n'
