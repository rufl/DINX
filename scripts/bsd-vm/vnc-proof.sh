#!/bin/sh
# Validate the GPU-less desktop path usable from VirtualBox/QEMU:
#   Aqueous (headless backend, no DRM needed) + Pearl + wayvnc
# wayvnc attaches to the compositor as an ordinary Wayland client (it needs
# only wlr-screencopy plus virtual input), so no kernel GPU driver is required.
# The host then reaches the live desktop over VNC.
#
# QEMU forwards host 15900 -> guest 5900; in VirtualBox add a NAT port
# forwarding rule for the same pair.
set -u
R=/home/dinx/.run
mkdir -p "$R" /tmp/.X11-unix
chmod 700 "$R"; chmod 1777 /tmp/.X11-unix
chown dinx:dinx "$R"
rm -f "$R"/wayland-* "$R"/wl-*; rm -rf "$R/aqueous"
rm -f /root/build/vncproof.out /tmp/aq-init-vnc.out /tmp/vnc-shot.png

pkg install -y wayvnc >/dev/null 2>&1
echo "wayvnc=$(command -v wayvnc || echo MISSING)"

cat > /tmp/aq-init-vnc.sh <<'INIT'
#!/bin/sh
{
  export XDG_CURRENT_DESKTOP=Aqueous
  echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
  echo "AQUEOUS_SOCKET=${AQUEOUS_SOCKET:-none}"
  echo "DISPLAY=${DISPLAY:-none}"

  # Publish the headless session over VNC (no DRM needed).
  wayvnc --render-cursor 0.0.0.0 5900 >/tmp/wayvnc.log 2>&1 &
  echo "WAYVNC_PID=$!"
  sleep 3

  # The shell: Pearl.
  pearl >/tmp/pearl.log 2>&1 &
  P=$!
  sleep 8
  if kill -0 $P 2>/dev/null; then echo "PEARL_ALIVE=yes"; else echo "PEARL_ALIVE=no"; fi
  tail -2 /tmp/pearl.log

  # An X11 client through Xwayland, to prove X11 compatibility.
  if [ -n "${DISPLAY:-}" ] && command -v xterm >/dev/null 2>&1; then
    xterm -display "$DISPLAY" -geometry 60x16+40+40 \
      -e 'echo DINX_X11_OK; sleep 300' >/tmp/xterm.log 2>&1 &
    sleep 4
    xwininfo -display "$DISPLAY" -root -children 2>/dev/null \
      | grep -ci xterm | xargs echo "XTERM_WINDOWS="
  fi

  echo "--- wayvnc listening:"
  sockstat -4l 2>/dev/null | grep 5900 | cut -c1-90
  echo "--- wayvnc.log:"
  tail -6 /tmp/wayvnc.log
  echo "--- grim capture:"
  perl -e 'alarm 12; exec @ARGV' grim /tmp/vnc-shot.png >/tmp/grim2.out 2>&1
  echo "GRIM_RC=$? $(head -1 /tmp/grim2.out)"
  ls -la /tmp/vnc-shot.png 2>&1 | cut -c1-60
  echo "VNC_INIT_DONE"
} > /tmp/aq-init-vnc.out 2>&1
# Keep the session alive so the host can connect to VNC afterwards.
sleep 600
INIT
chmod 755 /tmp/aq-init-vnc.sh

su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
  umask 077
  mkdir -p "$XDG_RUNTIME_DIR/aqueous"; chmod 700 "$XDG_RUNTIME_DIR/aqueous"
  nohup aqueous -c /tmp/aq-init-vnc.sh >/tmp/aq-vnc.log 2>&1 < /dev/null &
' </dev/null

sleep 30
cp /tmp/aq-init-vnc.out /root/build/vncproof.out 2>/dev/null \
  || echo "(init never produced output)" > /root/build/vncproof.out
{
  echo "===== aqueous.log tail ====="
  tail -6 /tmp/aq-vnc.log
  echo "===== processes ====="
  pgrep -l "aqueous|pearl|wayvnc|xterm" | cut -c1-60
} >> /root/build/vncproof.out 2>&1

sh /root/build/push.sh /root/build/vncproof.out /tmp/vnc-shot.png
echo VNC_PROOF_DONE
