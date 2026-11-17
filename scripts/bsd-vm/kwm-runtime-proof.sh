#!/bin/sh
# Final runtime proof with a real font installed: kwm must get past the fcft
# bar font load (the run that died earlier was purely font-less), stay in its
# poll loop, then exit cleanly on SIGTERM through the self-pipe.
exec > /root/kwmbuild/kwm-runtime3.out 2>&1
# The dev VM layout; override BIN when kwm was built elsewhere
BIN=${BIN:-/root/kwmbuild/kwm/zig-out/bin/kwm}

echo "== font install =="
pkg install -y terminus-font >/dev/null 2>&1
echo "terminus_rc=$?"
pkg install -y fontconfig >/dev/null 2>&1
echo "fontconfig_rc=$?"
fc-cache -f >/dev/null 2>&1
echo "fc-match: $(fc-match monospace 2>&1)"

XDG_RUNTIME_DIR=/tmp/kwmrt3
rm -rf "$XDG_RUNTIME_DIR"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR WAYLAND_DISPLAY=wayland-kwm3 WLR_BACKENDS=headless

timeout 45 river -c "$BIN" > /tmp/river-kwm3.log 2>&1 &
rpid=$!
i=0; kpid=""
while [ $i -lt 100 ]; do
  kpid=$(pgrep -x kwm | head -1); [ -n "$kpid" ] && break
  kill -0 $rpid 2>/dev/null || break
  i=$((i+1)); sleep 0.2
done
echo "kwm_pid=${kpid:-none}"
if [ -n "$kpid" ]; then
  sleep 6
  st=$(ps -o pid,stat,etime -p "$kpid" 2>/dev/null | tail -1)
  echo "after 6s: $st"
  case "$st" in *Z*) echo "KWM_DIED_EARLY=zombie";; *) echo "KWM_ALIVE=yes";; esac
  kill -TERM "$kpid" 2>/dev/null
  j=0
  while [ $j -lt 40 ]; do
    s=$(ps -o stat= -p "$kpid" 2>/dev/null | tr -d ' ')
    [ -z "$s" ] && break
    case "$s" in Z*) break;; esac
    j=$((j+1)); sleep 0.2
  done
  s=$(ps -o stat= -p "$kpid" 2>/dev/null | tr -d ' ')
  if [ -z "$s" ]; then echo "SIGNAL_HANDLED=yes (pid gone)"
  elif [ "$s" = Z ]; then echo "SIGNAL_HANDLED=yes (exited, awaiting reap)"
  else echo "SIGNAL_HANDLED=no (stat=$s)"; fi
fi
wait $rpid 2>/dev/null
echo "== log =="
grep -c 'NoFont' /tmp/river-kwm3.log
tail -18 /tmp/river-kwm3.log
echo KWM_RUNTIME3_DONE
