#!/usr/bin/env bash
set -euo pipefail

source_dir=${1:?usage: noctty_p2_qualification.sh SOURCE_DIR}
source_dir=$(CDPATH= cd -- "$source_dir" && pwd -P)
require_real_tui=${NOCTTY_QUALIFICATION_REQUIRE_REAL_TUI:-0}

fail() {
  printf 'noctty_p2_qualification: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name=$1
  local path
  path=$(command -v "$command_name" || true)
  [[ -n "$path" && -x "$path" && "$path" = /* ]] || fail "missing executable: $command_name"
  printf '%s\n' "$path"
}

run_target() {
  local target=$1
  zig build -Doptimize=ReleaseSafe "$target"
}

cd "$source_dir"

run_target terminal-agent-fairness-binary
run_target launch-continuity-qualification-binary
run_target terminal-real-tui-qualification-binary
run_target terminal-ncurses-qualification-binary
run_target terminal-system-tui-qualification-binary

fairness_output=$(./zig-out/bin/noctty-terminal-agent-fairness)
printf '%s\n' "$fairness_output"
grep -Fq 'terminal_agent_fairness_qualification mode=' <<<"$fairness_output"
grep -Fq 'panes=30 flood_panes=1 marker_panes=29' <<<"$fairness_output"
grep -Fq 'all_markers=true shared_pump_scratch=true glib_fd_sources=true' <<<"$fairness_output"
grep -Fq 'large_paste_bytes=8388608' <<<"$fairness_output"
grep -Fq 'paste_queue_exercised=true paste_pending_teardown=true' <<<"$fairness_output"
grep -Fq 'allocator_leak_free=true allocator_residual_bytes=0 process_residual=0 assertions=true' <<<"$fairness_output"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/noctty-p2.XXXXXX")
tmux_path=''
cleanup() {
  if [[ -n "$tmux_path" ]]; then
    TMUX_TMPDIR="$work_dir/tmux" "$tmux_path" kill-server >/dev/null 2>&1 || true
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$work_dir/bin"
tool_shim="$work_dir/bin/noctty-continuity-tool"
cat >"$tool_shim" <<'SHIM'
#!/usr/bin/env sh
set -eu
tool=${0##*/}
test "$PWD" = /tmp
test "${NOCTTY_CONTINUITY:-}" = ready
case "$tool" in
  tmux)
    test "$#" -eq 4
    test "$1" = new-session
    test "$2" = -A
    test "$3" = -s
    test "$4" = noctty-tmux
    ;;
  zellij)
    test "$#" -eq 3
    test "$1" = attach
    test "$2" = --create
    test "$3" = noctty-zellij
    ;;
  *) exit 64 ;;
esac
printf 'NOCTTY_CONTINUITY_OK:%s\n' "$tool"
SHIM
chmod +x "$tool_shim"
ln -s noctty-continuity-tool "$work_dir/bin/tmux"
ln -s noctty-continuity-tool "$work_dir/bin/zellij"

continuity_output=$(PATH="$work_dir/bin:$PATH" NOCTTY_CONTINUITY=ready \
  ./zig-out/bin/noctty-launch-continuity-qualification)
printf '%s\n' "$continuity_output"
grep -Fq 'launch_continuity_qualification mode=' <<<"$continuity_output"
grep -Fq 'kinds=tmux,zellij tmux_argv=true zellij_argv=true create_or_attach=true' <<<"$continuity_output"
grep -Fq 'production_pty=true cwd=true environment=true' <<<"$continuity_output"
grep -Fq 'controlled_exit=true allocator_leak_free=true allocator_residual_bytes=0 assertions=true' <<<"$continuity_output"
tmux_path=$(require_command tmux)
mkdir -p "$work_dir/tmux" "$work_dir/real-bin"
ln -s "$tmux_path" "$work_dir/real-bin/tmux"
ln -s "$work_dir/bin/noctty-continuity-tool" "$work_dir/real-bin/zellij"
TMUX_TMPDIR="$work_dir/tmux" "$tmux_path" -f /dev/null new-session -d -s noctty-tmux \
  'printf "NOCTTY_CONTINUITY_OK:tmux\\n"; sleep 2'
real_continuity_output=$(TMUX_TMPDIR="$work_dir/tmux" PATH="$work_dir/real-bin:$PATH" \
  NOCTTY_CONTINUITY=ready ./zig-out/bin/noctty-launch-continuity-qualification)
printf '%s\n' "$real_continuity_output"
grep -Fq 'launch_continuity_qualification mode=' <<<"$real_continuity_output"
grep -Fq 'kinds=tmux,zellij tmux_argv=true zellij_argv=true create_or_attach=true' <<<"$real_continuity_output"
grep -Fq 'controlled_exit=true allocator_leak_free=true allocator_residual_bytes=0 assertions=true' <<<"$real_continuity_output"

nano_path=$(require_command nano)
less_path=$(require_command less)
dialog_path=$(require_command dialog)
mkdir -p "$work_dir/ncurses"
printf 'NOCTTY_NCURSES_NANO\nread-only editor fixture\n' >"$work_dir/ncurses/nano-fixture.txt"
{
  printf 'NOCTTY_NCURSES_LESS\n'
  for index in $(seq 1 200); do
    printf 'pager line %03d real ncurses fixture\n' "$index"
  done
} >"$work_dir/ncurses/less-fixture.txt"
ncurses_output=$(TERM=xterm-256color "$source_dir/zig-out/bin/noctty-terminal-ncurses-qualification" \
  "$work_dir/ncurses" "$nano_path" "$less_path" "$dialog_path")
printf '%s\n' "$ncurses_output"
grep -Fq 'terminal_ncurses_qualification mode=' <<<"$ncurses_output"
grep -Fq 'applications=3' <<<"$ncurses_output"
grep -Fq 'nano_editor=true nano_alternate_screen=true nano_mouse=true' <<<"$ncurses_output"
grep -Fq 'less_pager=true less_alternate_screen=true dialog_widget=true' <<<"$ncurses_output"
grep -Fq 'allocator_leak_free=true allocator_residual_bytes=0 process_residual=0 assertions=true' <<<"$ncurses_output"

top_path=$(require_command top)
watch_path=$(require_command watch)
info_path=$(require_command info)
cc_path=$(require_command cc)
whiptail_path=$(require_command whiptail)
fzf_path=$(require_command fzf)
sqlite_path=$(require_command sqlite3)
glances_path=$(require_command glances)
bash_path=$(require_command bash)
man_path=$(require_command man)
sftp_path=$(require_command sftp)
less_path=$(require_command less)
sftp_server_path=''
for candidate in /usr/lib/ssh/sftp-server /usr/lib/openssh/sftp-server; do
  if [[ -x "$candidate" ]]; then
    sftp_server_path=$candidate
    break
  fi
done
[[ -n "$sftp_server_path" ]] || fail 'missing executable: sftp-server'
infocmp xterm-256color >/dev/null 2>&1 || fail 'missing xterm-256color terminfo'

mkdir -p "$work_dir/system"
info_wrapper_source="$work_dir/info-wrapper.c"
info_wrapper_path="$work_dir/info"
printf '%s\n' \
  '#include <fcntl.h>' \
  '#include <stddef.h>' \
  '#include <sys/types.h>' \
  '#include <sys/wait.h>' \
  '#include <unistd.h>' \
  "static const char real_info[] = \"$info_path\";" \
  "static const char fallback_marker[] = \"$work_dir/info-wrapper-fallback\";" \
  'int main(int argc, char **argv) {' \
  '  char *child_argv[32];' \
  '  if (argc >= 32) return 126;' \
  '  pid_t child = fork();' \
  '  if (child < 0) return 127;' \
  '  if (child == 0) {' \
  '    child_argv[0] = (char *)real_info;' \
  '    for (int i = 1; i < argc; ++i) child_argv[i] = argv[i];' \
  '    child_argv[argc] = NULL;' \
  '    execv(real_info, child_argv);' \
  '    _exit(127);' \
  '  }' \
  '  int status = 0;' \
  '  for (;;) {' \
  '    pid_t result = waitpid(child, &status, WNOHANG);' \
  '    if (result == child) break;' \
  '    if (result < 0) break;' \
  '    usleep(10000);' \
  '  }' \
  '  if (WIFEXITED(status) && WEXITSTATUS(status) == 0) return 0;' \
  '  int fd = open(fallback_marker, O_WRONLY | O_CREAT | O_TRUNC, 0600);' \
  '  if (fd >= 0) close(fd);' \
  '  const char screen[] = "\033[2J\033[HFile: dir\nTop\nNOCTTY_SYSTEM_INFO\n";' \
  '  write(STDOUT_FILENO, screen, sizeof(screen) - 1);' \
  '  char input[64];' \
  '  while (read(STDIN_FILENO, input, sizeof(input)) > 0) {' \
  '    for (size_t i = 0; i < sizeof(input); ++i) if (input[i] == 113) return 0;' \
  '  }' \
  '  return 0;' \
  '}' \
  >"$info_wrapper_source"
"$cc_path" "$info_wrapper_source" -o "$info_wrapper_path"

printf '%s\n' \
  'File: dir, Node: Top' \
  'NOCTTY_SYSTEM_INFO' \
  >"$work_dir/system/noctty-system.info"
printf '%s\n' alpha NOCTTY_FZF_TARGET omega >"$work_dir/system/fzf-input.txt"
printf '%s\n' "PS1='NOCTTY_BASH> '" "printf 'NOCTTY_BASH_READY\\n'" >"$work_dir/system/bashrc"
printf '%s\n' \
  '.TH NOCTTY-SYSTEM 1' \
  '.SH NAME' \
  'noctty-system \\- NOCTTY_SYSTEM_MAN' \
  '.SH DESCRIPTION' \
  'Deterministic installed man pager fixture for NOCTTY.' \
  >"$work_dir/system/noctty-system.1"
system_output=$(TERM=xterm-256color "$source_dir/zig-out/bin/noctty-terminal-system-tui-qualification" \
  "$work_dir/system" "$top_path" "$watch_path" "$info_wrapper_path" "$whiptail_path" \
  "$fzf_path" "$sqlite_path" "$glances_path" "$bash_path" "$man_path" \
  "$less_path" "$sftp_path" "$sftp_server_path")
printf '%s\n' "$system_output"
grep -Fq 'terminal_system_tui_qualification mode=' <<<"$system_output"
grep -Fq 'applications=10' <<<"$system_output"
grep -Fq 'top_monitor=true watch_refresh=true watch_plain_surface=true' <<<"$system_output"
grep -Fq 'info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true' <<<"$system_output"
grep -Fq 'glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true' <<<"$system_output"
grep -Fq 'sftp_client=true sftp_local_server=true network_bind=false' <<<"$system_output"
grep -Fq 'allocator_leak_free=true allocator_residual_bytes=0 process_residual=0 assertions=true' <<<"$system_output"
if [[ -e "$work_dir/info-wrapper-fallback" ]]; then
  info_surface=fixture_fallback
else
  info_surface=installed
fi
printf 'info_surface=%s\n' "$info_surface"

vim_path=$(command -v vim || true)
btop_path=$(command -v btop || true)
if [[ -n "$vim_path" && -x "$vim_path" && -n "$btop_path" && -x "$btop_path" ]]; then
  mkdir -p "$work_dir/real"
  printf 'NOCTTY_REAL_TUI_VIM\nreal ncurses fixture\n' >"$work_dir/real/vim-fixture.txt"
  codex_path=$(command -v codex || true)
  codex_surface=fixture
  if [[ "$require_real_tui" = 1 ]]; then
    [[ -n "$codex_path" && -x "$codex_path" ]] || fail 'real TUI gate requires codex'
    codex_surface=installed
  else
    cat >"$work_dir/codex.c" <<'C_FIXTURE'
#include <signal.h>
#include <unistd.h>

static void stop(int signal_number) {
  (void)signal_number;
  _exit(0);
}

int main(void) {
  static const char screen[] =
      "\033[?2026h\033[1;31mWelcome Codex\033[0m\r\n"
      "Sign in with ChatGPT\r\n"
      "NOCTTY deterministic Codex login surface fixture\r\n";
  (void)signal(SIGINT, stop);
  (void)write(STDOUT_FILENO, screen, sizeof(screen) - 1);
  for (;;) pause();
}
C_FIXTURE
    cc -O2 -std=c11 -Wall -Wextra "$work_dir/codex.c" -o "$work_dir/codex"
    codex_path="$work_dir/codex"
  fi
  real_output=$(TERM=xterm-256color "$source_dir/zig-out/bin/noctty-terminal-real-tui-qualification" \
    "$work_dir/real" "$codex_path" "$vim_path" "$btop_path")
  printf '%s\n' "$real_output"
  grep -Fq 'terminal_real_tui_qualification mode=' <<<"$real_output"
  grep -Fq 'applications=3' <<<"$real_output"
  grep -Fq 'codex_login_surface=true codex_sync_output=true codex_exit_code=0' <<<"$real_output"
  grep -Fq 'vim_fixture=true vim_alternate_screen=true vim_bracketed_paste=true' <<<"$real_output"
  grep -Fq 'btop_dashboard=true btop_alternate_screen=true btop_mouse=true' <<<"$real_output"
  grep -Fq 'allocator_leak_free=true allocator_residual_bytes=0 process_residual=0 assertions=true' <<<"$real_output"
  real_tui=true
else
  real_tui=false
  [[ "$require_real_tui" = 0 ]] || fail 'real TUI gate requires vim and btop'
  codex_surface=unavailable
  printf 'terminal_real_tui_qualification skipped=true reason=vim-btop-not-installed\n'
fi

printf 'noctty_p2_qualification terminal_fairness=true launch_continuity=true ncurses=true system_tui=true real_tui=%s info_surface=%s codex_surface=%s release_safe=true\n' "$real_tui" "$info_surface" "$codex_surface"
