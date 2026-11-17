#!/bin/sh
# Aqueous desktop proof (non-blocking): the compositor runs in the background
# and is killed after the capture window, so this script always terminates.
#
#   aqueous -c <init>  creates the Wayland + IPC sockets and injects
#   WAYLAND_DISPLAY / AQUEOUS_SOCKET / DISPLAY (Xwayland) into the init child,
#   staying alive while the init runs. The init starts Pearl (the IPC client
#   that renews the compositor's exit timer), an X11 client through Xwayland,
#   then captures with grim via wlr-screencopy.
set -u
R=/home/dinx/.run
mkdir -p "$R" /tmp/.X11-unix
chmod 700 "$R"; chmod 1777 /tmp/.X11-unix
chown dinx:dinx "$R"
rm -f "$R"/wayland-* "$R"/wl-*; rm -rf "$R/aqueous"
rm -f /tmp/dinx-desktop.png /tmp/aq-init.out /root/build/proof.out

cat > /tmp/aq-init.sh <<'INIT'
#!/bin/sh
{
  echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
  echo "AQUEOUS_SOCKET=$AQUEOUS_SOCKET"
  echo "DISPLAY=${DISPLAY:-none}"
  echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-none}"
  # Pearl validates XDG_CURRENT_DESKTOP against the compositor name; the
  # compositor sets WAYLAND_DISPLAY/AQUEOUS_SOCKET/DISPLAY but not this one.
  export XDG_CURRENT_DESKTOP=Aqueous
  # Xwayland: X server answers and an X11 client attaches.
  if [ -n "${DISPLAY:-}" ]; then
    if xdpyinfo -display "$DISPLAY" >/tmp/xdpy.out 2>&1; then
      echo "XWAYLAND_OK $(grep -m1 'version number' /tmp/xdpy.out)"
      xterm -display "$DISPLAY" -geometry 70x18+60+60 \
        -e 'echo DINX_XWAYLAND_WINDOW_OK; sleep 120' >/tmp/xterm.out 2>&1 &
      sleep 4
      xwininfo -display "$DISPLAY" -root -children 2>/dev/null \
        | grep -ci xterm | xargs echo "XTERM_WINDOWS="
    else
      echo "XWAYLAND_FAIL"; tail -2 /tmp/xdpy.out
    fi
  else
    echo "XWAYLAND_MISSING (no DISPLAY)"
  fi

  # Pearl shell (the IPC client that keeps the compositor alive).
  pearl >/tmp/pearl.log 2>&1 &
  P=$!
  sleep 8
  if kill -0 $P 2>/dev/null; then echo "PEARL_ALIVE=yes"; else echo "PEARL_ALIVE=no"; fi
  tail -3 /tmp/pearl.log

  # Capture the compositor output; bounded so it can never hang the proof.
  perl -e 'alarm 12; exec @ARGV' grim /tmp/dinx-desktop.png >/tmp/grim.out 2>&1
  echo "GRIM_RC=$? $(head -1 /tmp/grim.out)"
  ls -la /tmp/dinx-desktop.png 2>&1 | cut -c1-70
  echo "AQ_INIT_DONE"
} > /tmp/aq-init.out 2>&1
INIT
chmod 755 /tmp/aq-init.sh

su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
  umask 077
  mkdir -p "$XDG_RUNTIME_DIR/aqueous"; chmod 700 "$XDG_RUNTIME_DIR/aqueous"
  aqueous -c /tmp/aq-init.sh >/tmp/aq.log 2>&1 &
  echo $! > /tmp/aq.pid
' </dev/null

# Bound the whole session: give the init time to finish, then tear down.
sleep 45
cat /tmp/aq-init.out 2>/dev/null > /root/build/proof.out || echo "(init never ran)" >> /root/build/proof.out
{
  echo "===== aqueous.log tail ====="
  tail -14 /tmp/aq.log
  echo "===== dmesg signals ====="
  dmesg | grep -iE "aqueous|signal [0-9]+" | tail -4
} >> /root/build/proof.out 2>&1

# Clean up everything the session started.
pkill -f 'aqueous -c' 2>/dev/null
pkill -f xterm 2>/dev/null
sleep 2
echo AQ_PROOF_DONE
