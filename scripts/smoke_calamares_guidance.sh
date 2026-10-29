#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
guide_qml="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/notesqml.qml"

fail() {
  printf 'calamares_guidance_smoke: %s\n' "$*" >&2
  exit 1
}

[[ $EUID -ne 0 ]] || fail 'run as your regular desktop user, not with sudo'
for command in jq qmlscene6; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done
if [[ -z ${DISPLAY:-} && -z ${WAYLAND_DISPLAY:-} ]]; then
  fail 'run this script from a logged-in graphical desktop session'
fi
[[ -r "$guide_qml" ]] || fail "guide QML is missing: $guide_qml"

bash "$repo_root/scripts/check_calamares_partitioning.sh"
if command -v qmllint >/dev/null 2>&1; then
  qmllint "$guide_qml"
fi

printf '%s\n' \
  'Rendering the DINX bilingual install-guidance page as a Qt Quick preview.' \
  'This checks the page layout, not Calamares module integration; the Artix ISO build smoke covers integration.' \
  'This preview does not access disks or install anything. Close the window to finish.'
qmlscene6 "$guide_qml"
