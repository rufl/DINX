#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
redbean="$root/distro/packages/redbean/src"
dock="$root/distro/packages/dinx-dock/src/main.zig"
pori_patch="$root/distro/packages/pori/pori-memory.patch"
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
river_session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-river-session"
kwm="$root/distro/packages/kwm/PKGBUILD"
kwim="$root/distro/packages/kwim/PKGBUILD"
morghulis="$root/distro/packages/morghulis/morghulis-dinx-no-libgtop.patch"
fail() {
  printf 'shell_memory_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$redbean/main.zig" "$redbean/gtk.h" "$dock" "$pori_patch" \
  "$supervisor" "$river_session" "$kwm" "$kwim" "$morghulis"; do
  [[ -r "$path" ]] || fail "missing input: ${path#$root/}"
done

# Redbean: parsed configuration, C-owned lists, and GTK objects each have an
# explicit release boundary. These are source contracts, not a claim of a
# runtime allocator proof.
grep -Fq 'config_arena.deinit()' "$redbean/main.zig" \
  || fail 'Redbean configuration arena has no teardown'
grep -Fq 'releaseConfig(config_state)' "$redbean/main.zig" \
  || fail 'Redbean parsed configuration has no teardown'
grep -Fq 'g_list_free_full(results, g_free)' "$redbean/gtk.h" \
  || fail 'Redbean file-search result strings are not fully released'
grep -Fq 'g_list_free(outputs)' "$redbean/gtk.h" \
  || fail 'Redbean River output list is not released'
grep -Fq 'g_strfreev(categories)' "$redbean/gtk.h" \
  || fail 'Redbean application category vector is not released'

# DINX Dock: reloads must destroy the JSON parse tree and old GAppInfo refs;
# the single-instance fd is intentionally held until process teardown.
grep -Fq 'defer parsed.deinit()' "$dock" \
  || fail 'DINX Dock JSON reload has no parse-tree teardown'
grep -Fq 'defer allocator.free(text)' "$dock" \
  || fail 'DINX Dock config buffer has no teardown'
grep -Fq 'c.g_object_unref(@ptrCast(info))' "$dock" \
  || fail 'DINX Dock favorite references are not released'
grep -Fq 'releaseFavorites()' "$dock" \
  || fail 'DINX Dock has no favorite reload teardown'
grep -Fq 'c.close(lock_fd)' "$dock" \
  || fail 'DINX Dock lock fd has no teardown'

# Pori's dialog callback owns option strings through the dialog lifetime, then
# releases its arena after the callback returns.
grep -Fq 'std.heap.ArenaAllocator' "$pori_patch" \
  || fail 'Pori dialog does not isolate option allocations'
grep -Fq 'arena.deinit();' "$pori_patch" \
  || fail 'Pori dialog arena is not released'

# River/KWM/KWIM are long-lived external processes: the supervisor tracks every
# child and terminates all tracked children on every exit path.
grep -Fq 'child_pids=' "$supervisor" \
  || fail 'session supervisor has no child ownership list'
grep -Fq 'trap cleanup EXIT' "$supervisor" \
  || fail 'session supervisor has no exit cleanup'
grep -Fq 'stop_child()' "$supervisor" \
  || fail 'session supervisor has no bounded child teardown'
grep -Fq 'wait "$pid"' "$supervisor" \
  || fail 'session supervisor does not reap tracked children'
grep -Fq 'kill -TERM "$pid"' "$supervisor" \
  || fail 'session supervisor does not terminate tracked children'
grep -Fq -- '-Doptimize=ReleaseSafe' "$kwm" \
  || fail 'KWM is not built with bounded-release optimization'
grep -Fq -- '-Doptimize=ReleaseSafe' "$kwim" \
  || fail 'KWIM is not built with bounded-release optimization'
grep -Fq 'start_required wm kwm' "$supervisor" \
  || fail 'KWM is not supervised as a required River component'
grep -Fq 'starts KWIM' "$supervisor" \
  || fail 'KWIM ownership is not documented at the KWM boundary'

# Morghulis runs under the bounded-memory GTK renderer selected by the session.
grep -Fq 'GSK_RENDERER="${GSK_RENDERER:-cairo}"' "$river_session" \
  || fail 'the River session does not select the bounded-memory GTK renderer'

# Morghulis no longer loads libgtop; its uptime path reads a bounded procfs
# record instead of retaining a library-owned monitor object.
grep -Fq '+        try {' "$morghulis" \
  || fail 'Morghulis procfs uptime fallback is missing'
grep -Fq '+            FileUtils.get_contents("/proc/uptime"' "$morghulis" \
  || fail 'Morghulis procfs uptime fallback is missing'
if grep -Eq '^\+.*GTop\.Uptime' "$morghulis"; then
  fail 'Morghulis still retains the removed libgtop uptime object'
fi

printf 'shell_memory_contract redbean=true dock=true pori=true morghulis=true river=true kwm=true kwim=true runtime_valgrind=not_claimed\n'
