#!/bin/sh
# Correct Aqueous probe: run the compositor WITH an init command (-c), so it
# stays alive while the init runs. The init child inherits WAYLAND_DISPLAY,
# AQUEOUS_SOCKET and DISPLAY (Xwayland) that aqueous sets after addSocketAuto().
# We probe from inside the init, then exit so aqueous shuts down cleanly.
set -u
R=/home/dinx/.run
mkdir -p "$R" /tmp/.X11-unix
chmod 700 "$R"
chown dinx:dinx "$R"
rm -f "$R"/wayland-* "$R"/wl-*
rm -rf "$R/aqueous"

cat > /tmp/aq-init.sh <<'INIT'
#!/bin/sh
# Runs as aqueous' init child; env already injected by the compositor.
{
  echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
  echo "AQUEOUS_SOCKET=$AQUEOUS_SOCKET"
  echo "DISPLAY=$DISPLAY"
  echo "XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP"
  echo "--- runtime dir"
  ls -la "$XDG_RUNTIME_DIR"
  echo "--- wayland socket connect test"
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    python3 -c "import socket,os;s=socket.socket(socket.AF_UNIX);s.settimeout(1);s.connect(os.path.join(os.environ['XDG_RUNTIME_DIR'],os.environ['WAYLAND_DISPLAY']));print('WAYLAND_CONNECT_OK')" 2>&1 | tail -1
  fi
  echo "--- xwayland display probe"
  if [ -n "${DISPLAY:-}" ]; then
    xdpyinfo -display "$DISPLAY" >/tmp/xdpy.out 2>&1 && echo "XDPY_OK $(grep -m1 'vendor\|dimensions' /tmp/xdpy.out)" || (echo "XDPY_FAIL"; tail -2 /tmp/xdpy.out)
    xterm -display "$DISPLAY" -e 'sleep 30' >/tmp/xterm.out 2>&1 &
    sleep 2
    xwininfo -display "$DISPLAY" -root -children >/tmp/xwin.out 2>&1 && echo "XWIN_children=$(grep -c 'xterm\|0x' /tmp/xwin.out)" || echo "XWIN_FAIL"
  fi
  echo "--- aqueous.log tail"
  tail -8 /tmp/aq.log
  echo "AQ_INIT_DONE"
} > /tmp/aq-init.out 2>&1
sleep 1
INIT
chmod 755 /tmp/aq-init.sh

su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
  aqueous -c /tmp/aq-init.sh >/tmp/aq.log 2>&1
' </dev/null
cat /tmp/aq-init.out
echo AQ_PROBE10_DONE
