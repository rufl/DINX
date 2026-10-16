#!/usr/bin/env bash
set -euo pipefail

source_dir=${1:?usage: nocted_p3_qualification.sh SOURCE_DIR}
source_dir=$(CDPATH= cd -- "$source_dir" && pwd -P)
cd "$source_dir"

fail() {
  printf 'nocted_p3_qualification: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name=$1
  command -v "$command_name" >/dev/null 2>&1 || fail "missing executable: $command_name"
}

for command_name in git clangd dbus-run-session gtk-update-icon-cache xvfb-run; do
  require_command "$command_name"
done

[[ -f resources/nocted/styles/nocted-dark.xml ]] || fail 'dark NoctEd scheme is missing'
[[ -f resources/nocted/styles/nocted-light.xml ]] || fail 'light NoctEd scheme is missing'
grep -Fq 'NOCTALIA_COLOR_SCHEME' src/nocted/main.zig || fail 'Noctalia color-scheme contract is missing'
grep -Fq 'Git Status and Diff...' src/nocted/main.zig || fail 'Git editor action is missing'

echo 'nocted_p3_gate source_contract=true git_action=true dark_scheme=true light_scheme=true noctalia_scheme=true'

./scripts/nocted_core_endurance_qualification.sh
./scripts/nocted_project_index_qualification.sh
./scripts/nocted_worker_qualification.sh
./scripts/nocted_state_recovery_qualification.sh
./scripts/nocted_task_smoke.sh

lsp_output=$(./scripts/nocted_lsp_smoke.sh)
printf '%s\n' "$lsp_output"
grep -Fq 'nocted_lsp_probe server=clangd' <<<"$lsp_output" || fail 'clangd LSP probe did not run'
grep -Fq 'response=nocted_lsp_symbol' <<<"$lsp_output" || fail 'clangd LSP symbol response is missing'
grep -Fq 'nocted_lsp_smoke client=true server=true' <<<"$lsp_output" || fail 'LSP qualification summary is missing'

zig build -Doptimize=ReleaseSafe nocted-smoke-binary
smoke_binary="$source_dir/zig-out/bin/nocted-smoke"
[[ -x "$smoke_binary" ]] || fail "missing NoctEd smoke binary: $smoke_binary"

run_native_smoke() {
  local theme=$1
  local icon_home
  local data_dirs
  local output
  icon_home=$(mktemp -d "${TMPDIR:-/tmp}/nocted-p3-icon.XXXXXX")
  data_dirs=${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
  mkdir -p \
    "$icon_home/icons/NoctedSmoke" \
    "$icon_home/icons/NoctedSmoke/16x16/apps" \
    "$icon_home/icons/NoctedSmoke/16x16/status" \
    "$icon_home/icons/NoctedSmoke/22x22/apps" \
    "$icon_home/icons/NoctedSmoke/24x24/apps" \
    "$icon_home/icons/NoctedSmoke/32x32/apps" \
    "$icon_home/icons/NoctedSmoke/48x48/apps" \
    "$icon_home/icons/NoctedSmoke/64x64/apps" \
    "$icon_home/icons/NoctedSmoke/128x128/apps" \
    "$icon_home/icons/NoctedSmoke/256x256/apps"
  cat >"$icon_home/icons/NoctedSmoke/index.theme" <<'EOF'
[Icon Theme]
Name=NoctedSmoke
Comment=DINX smoke fallback
Inherits=Adwaita
Directories=16x16/apps,16x16/status,22x22/apps,24x24/apps,32x32/apps,48x48/apps,64x64/apps,128x128/apps,256x256/apps

[16x16/apps]
Size=16
Context=Applications
Type=Threshold

[16x16/status]
Size=16
Context=Status
Type=Threshold

[22x22/apps]
Size=22
Context=Applications
Type=Threshold

[24x24/apps]
Size=24
Context=Applications
Type=Threshold

[32x32/apps]
Size=32
Context=Applications
Type=Threshold

[48x48/apps]
Size=48
Context=Applications
Type=Threshold

[64x64/apps]
Size=64
Context=Applications
Type=Threshold

[128x128/apps]
Size=128
Context=Applications
Type=Threshold

[256x256/apps]
Size=256
Context=Applications
Type=Threshold
EOF
  # Keep the harness icon in the same SVG path used by the packaged theme; the
  # host image provides the glycin SVG loader while XPM is not guaranteed.
  cat >"$icon_home/nocted.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
  <rect width="16" height="16" rx="2" fill="#0b0d12"/>
  <path d="M4 3h8v2H6v2h5v2H6v4H4z" fill="#8fb8ff"/>
</svg>
EOF
  for size in 16 22 24 32 48 64 128 256; do
    cp "$icon_home/nocted.svg" \
      "$icon_home/icons/NoctedSmoke/${size}x${size}/apps/com.noctty.NoctEd.svg"
  done
  cp "$icon_home/nocted.svg" \
    "$icon_home/icons/NoctedSmoke/16x16/status/image-missing.svg"
  for icon_name in \
    view-list-symbolic \
    view-list \
    go-up-symbolic \
    go-up \
    go-previous-symbolic \
    go-previous \
    go-down-symbolic \
    go-down \
    edit-find-symbolic \
    edit-find \
    edit-clear-symbolic \
    window-close-symbolic \
    folder-symbolic \
    folder \
    folder-remote \
    folder-documents-symbolic \
    folder-download-symbolic \
    folder-music-symbolic \
    folder-pictures-symbolic \
    folder-publicshare-symbolic \
    folder-remote-symbolic \
    folder-saved-search-symbolic \
    folder-templates-symbolic \
    folder-videos-symbolic \
    user-home-symbolic \
    user-desktop-symbolic \
    text-x-generic-symbolic \
    text-x-generic \
    dialog-warning \
    dialog-warning-symbolic \
    dialog-information \
    dialog-information-symbolic \
    dialog-question \
    dialog-question-symbolic \
    dialog-error \
    dialog-error-symbolic \
    image-missing \
    application-x-executable \
    audio-x-generic \
    font-x-generic \
    image-x-generic \
    package-x-generic \
    text-html \
    text-x-generic-template \
    text-x-script \
    video-x-generic \
    x-office-address-book \
    x-office-calendar \
    x-office-document \
    x-office-presentation \
    x-office-spreadsheet \
    document-open-recent-symbolic \
    starred-symbolic \
    bookmark-new-symbolic \
    emblem-synchronizing-symbolic \
    drive-harddisk \
    caps-lock-symbolic; do
    for size in 16 22 24 32 48 64 128 256; do
      cp "$icon_home/nocted.svg" \
        "$icon_home/icons/NoctedSmoke/${size}x${size}/apps/${icon_name}.svg"
    done
  done
  gtk-update-icon-cache -f "$icon_home/icons/NoctedSmoke" >/dev/null
  output=$(
    NOCTTY_DEDICATED_DISPLAY=1 \
    NOCTTY_ISOLATED_DISPLAY=x11 \
    NOCTED_GDK_BACKEND=x11 \
    NOCTALIA_COLOR_SCHEME="$theme" \
    GTK_ICON_THEME=NoctedSmoke \
    WAYLAND_DISPLAY= \
    XDG_DATA_HOME="$icon_home" \
    XDG_DATA_DIRS="$icon_home:$data_dirs" \
    xvfb-run -a -s '-screen 0 1440x900x24 -nolisten tcp' \
      dbus-run-session -- ./scripts/nocted_native_smoke.sh "$smoke_binary" --qualification
  )
  rm -rf "$icon_home"
  printf '%s\n' "$output"
  grep -Fq 'nocted_native_smoke_diagnostic pass=1' <<<"$output" ||
    fail "native editor smoke failed for theme=$theme"
  grep -Fq 'nocted_search_load_qualification pass=1 cycles=8' <<<"$output" ||
    fail "native search qualification failed for theme=$theme"
  grep -Fq 'nocted_project_real_project_qualification pass=1 cycles=8' <<<"$output" ||
    fail "native project lifecycle qualification failed for theme=$theme"
  grep -Fq 'nocted_project_lifecycle_teardown pass=1' <<<"$output" ||
    fail "native lifecycle teardown failed for theme=$theme"
  printf 'nocted_p3_native theme=%s x11=true diagnostics=true search=true project=true lifecycle=true\n' "$theme"
}

run_native_smoke dark
run_native_smoke light

fixture=$(mktemp -d "${TMPDIR:-/tmp}/nocted-p3-git.XXXXXX")
cleanup() {
  if [[ -n "${fixture:-}" && -d "$fixture" ]]; then
    find "$fixture" -depth -delete 2>/dev/null || true
  fi
}
trap cleanup EXIT HUP INT TERM

git -C "$fixture" init -q
git -C "$fixture" config user.email dinx@example.invalid
git -C "$fixture" config user.name DINX
printf 'const original = true;\n' >"$fixture/main.zig"
git -C "$fixture" add main.zig
git -C "$fixture" commit -q -m initial
printf 'const original = false;\nconst changed = true;\n' >"$fixture/main.zig"
printf 'untracked\n' >"$fixture/notes.txt"
git_output=$(./zig-out/bin/nocted --git-probe "$fixture")
printf '%s\n' "$git_output"
grep -Fq 'nocted_git_probe changed=2' <<<"$git_output" || fail 'Git changed-file marker count is wrong'
grep -Fq 'unstaged=1 untracked=1' <<<"$git_output" || fail 'Git status markers are wrong'
grep -Fq 'modified=1' <<<"$git_output" || fail 'Git modified marker is missing'
grep -E 'diff_bytes=[1-9][0-9]* markers=true' <<<"$git_output" >/dev/null || fail 'Git diff marker is missing'

echo 'nocted_p3_qualification core=true project_index=true workers=true state_recovery=true tasks=true lsp=true native_x11_dark=true native_x11_light=true git_status=true git_diff=true change_markers=true scratch_clean=true'
