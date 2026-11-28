#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
helper="$root/distro/packages/dinx-dock/dinx-dockctl"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/config/dinx"

cat >"$tmp/bin/pkill" <<'EOF'
#!/bin/sh
if [ -e "$DINX_DOCK_TEST_RUNNING" ]; then
    edge=$(jq -r '.dock // "left"' "$DINX_DOCK_TEST_CONFIG")
    [ "$edge" != none ] || rm -f "$DINX_DOCK_TEST_RUNNING"
    exit 0
fi
exit 1
EOF
cat >"$tmp/bin/dinx-dock" <<'EOF'
#!/bin/sh
touch "$DINX_DOCK_TEST_RUNNING"
printf 'started\n' >> "$DINX_DOCK_TEST_STARTS"
EOF
chmod +x "$tmp/bin/pkill" "$tmp/bin/dinx-dock"
export PATH="$tmp/bin:/usr/bin:/bin"
export XDG_CONFIG_HOME="$tmp/config"
export DINX_DOCK_TEST_CONFIG="$tmp/config/dinx/appearance.json"
export DINX_DOCK_TEST_RUNNING="$tmp/running"
export DINX_DOCK_TEST_STARTS="$tmp/starts"

wait_for_dock() {
  for _ in {1..50}; do
    [[ -e "$DINX_DOCK_TEST_RUNNING" ]] && return 0
    sleep 0.02
  done
  printf 'smoke_dinx_dockctl: dock did not start\n' >&2
  return 1
}

[[ $("$helper" list | wc -l) -eq 6 ]]
"$helper" add com.example.Test.desktop
wait_for_dock
"$helper" list | grep -Fxq com.example.Test.desktop
"$helper" remove com.example.Test.desktop
"$helper" list | grep -Fxq org.dinx.Deetty.desktop
"$helper" set-edge none
[[ ! -e "$DINX_DOCK_TEST_RUNNING" ]]
"$helper" set-edge left
wait_for_dock
[[ $(wc -l < "$DINX_DOCK_TEST_STARTS") -eq 2 ]]
printf '%s\n' '{"version":1,"dock":"left","favorites":["only.desktop"]}' > "$DINX_DOCK_TEST_CONFIG"
if "$helper" remove only.desktop >"$tmp/remove.out" 2>&1; then
  printf 'smoke_dinx_dockctl: removing the final favorite unexpectedly succeeded\n' >&2
  exit 1
fi
grep -Fq 'cannot remove the final favorite' "$tmp/remove.out"

printf 'smoke_dinx_dockctl: defaults=true favorites=true disabled_reactivation=true final_favorite_guard=true\n'
