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

for command_name in git clangd dbus-run-session xvfb-run; do
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
  local output
  icon_home=$(mktemp -d "${TMPDIR:-/tmp}/nocted-p3-icon.XXXXXX")
  mkdir -p "$icon_home/icons/hicolor/scalable/apps"
  cp resources/com.noctty.NoctEd.svg "$icon_home/icons/hicolor/scalable/apps/com.noctty.NoctEd.svg"
  output=$(
    NOCTTY_DEDICATED_DISPLAY=1 \
    NOCTTY_ISOLATED_DISPLAY=x11 \
    NOCTED_GDK_BACKEND=x11 \
    NOCTALIA_COLOR_SCHEME="$theme" \
    WAYLAND_DISPLAY= \
    XDG_DATA_HOME="$icon_home" \
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
