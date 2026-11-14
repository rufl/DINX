#!/bin/sh
# Aqueous desktop proof: the compositor stays alive while its init child runs
# (aqueous -c <cmd>). Inside the init we inherit WAYLAND_DISPLAY,
# AQUEOUS_SOCKET and DISPLAY (Xwayland), so we can launch the Pearl shell,
# prove Xwayland with an X11 client, and capture with grim (wlroots
# wlr-screencopy -- works with Aqueous, unlike weston-screenshooter).
set -u
R=/home/dinx/.run
mkdir -p "$R" /tmp/.X11-unix
chmod 700 "$R"
chown dinx:dinx "$R"
rm -f "$R"/wayland-* "$R"/wl-*
rm -rf "$R/aqueous"
rm -f /tmp/dinx-desktop.png /tmp/dinx-init.out

cat > /tmp/aq-init.sh <<'INIT'
#!/bin/sh
{
  echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
  echo "AQUEOUS_SOCKET=$AQUEOUS_SOCKET"
  echo "DISPLAY=$DISPLAY"
  echo "XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP"
  # IPC keepalive: aqueous arms an exit timer that only connected IPC clients
  # renew; without one the compositor tears itself down mid-session.
  (while :; do LD_PRELOAD=/usr/local/lib/libdinxcompat.so aqueousctl windows >/dev/null 2>&1; sleep 2; done) &
  KA=$!

  # 1. Xwayland proof: X server answers and an X11 client attaches.
  if [ -n "${DISPLAY:-}" ]; then
    if xdpyinfo -display "$DISPLAY" >/tmp/xdpy.out 2>&1; then
      echo "XDPY_OK $(grep -m1 'version number' /tmp/xdpy.out)"
    else
      echo "XDPY_FAIL"; tail -2 /tmp/xdpy.out
    fi
    xterm -display "$DISPLAY" -geometry 70x20+40+40 -e 'echo DINX_XWAYLAND_OK; sleep 25' >/tmp/xterm.out 2>&1 &
    sleep 3
    xwininfo -display "$DISPLAY" -root -children 2>/dev/null | grep -c xterm | xargs echo "XTERM_WINDOWS="
  else
    echo "NO_DISPLAY (xwayland not exposed)"
  fi

  # 2. Pearl shell as a Wayland client (inherited WAYLAND_DISPLAY).
  pearl >/tmp/pearl.log 2>&1 &
  PEARL=$!
  sleep 6
  if kill -0 $PEARL 2>/dev/null; then echo "PEARL_ALIVE=yes"; else echo "PEARL_ALIVE=no"; fi
  tail -2 /tmp/pearl.log

  # 3. Capture the compositor output (wlr-screencopy).
  grim /tmp/dinx-desktop.png 2>/tmp/grim.out
  echo "GRIM=$? $(cat /tmp/grim.out | head -1)"
  ls -la /tmp/dinx-desktop.png 2>&1 | cut -c1-60
  echo "AQ_INIT_DONE"
} > /tmp/aq-init.out 2>&1
sleep 2
INIT
chmod 755 /tmp/aq-init.sh

su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
  aqueous -c /tmp/aq-init.sh >/tmp/aq.log 2>&1
' </dev/null

cat /tmp/aq-init.out 2>/dev/null
echo "--- aqueous.log"
grep -iE "xwayland|listening|socket|error" /tmp/aq.log | tail -8
cp /root/build/Aqueous/compositor/zig-out/bin/aqueous /usr/local/bin/aqueous 2>/dev/null
echo AQ_DESKTOP_DONE
