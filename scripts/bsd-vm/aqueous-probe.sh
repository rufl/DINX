#!/bin/sh
# Aqueous Wayland socket probe (FreeBSD). Polls every 250ms for up to 10s so
# the compositor's startup window is not missed, cleans stale sockets first,
# and reports which wayland-N socket actually accepts connections.
set -u
R=/home/dinx/.run
mkdir -p "$R" /tmp/.X11-unix
chmod 700 "$R"
chown dinx:dinx "$R"
rm -f "$R"/wayland-*
rm -rf "$R/aqueous"
su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
  aqueous >/tmp/aq.log 2>&1 &
  AQ=$!
  OK=""
  i=0
  while [ $i -lt 40 ]; do
    for s in /home/dinx/.run/wayland-*; do
      case "$s" in *.lock) continue ;; esac
      [ -S "$s" ] || continue
      if python3 -c "import socket,sys;s=socket.socket(socket.AF_UNIX);s.settimeout(0.3);s.connect(sys.argv[1])" "$s" 2>/dev/null; then
        OK=$(basename "$s")
        break
      fi
    done
    [ -n "$OK" ] && break
    i=$((i + 1))
    sleep 0.25
  done
  echo "SOCKET_OK=$OK after=$((i))ticks alive=$(kill -0 $AQ 2>/dev/null && echo yes || echo no)"
  ls /home/dinx/.run/
  echo "--- aqueous.log (socket/wayland/xwayland lines)"
  grep -inE "listen|socket|wayland-|xwayland|display" /tmp/aq.log | tail -12
  echo "--- aqueous.log tail"
  tail -5 /tmp/aq.log
  kill $AQ 2>/dev/null
' </dev/null
echo AQ_PROBE_DONE
