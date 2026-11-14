#!/bin/sh
# Direct Wayland-client connectivity test against a LIVE Aqueous.
# aqueous -c '<long init>' keeps the compositor alive while we probe from
# a second process: does a real Wayland client connect to the socket?
set -u
R=/home/dinx/.run
mkdir -p "$R" /tmp/.X11-unix
chmod 700 "$R"; chmod 1777 /tmp/.X11-unix
chown dinx:dinx "$R"
rm -f "$R"/wayland-* "$R"/wl-*; rm -rf "$R/aqueous"
rm -f /tmp/aqprobe.out

# long-lived init keeps aqueous running; log the env it received
cat > /tmp/aq-init.sh <<'INIT'
#!/bin/sh
echo "INIT WAYLAND_DISPLAY=$WAYLAND_DISPLAY DISPLAY=$DISPLAY SOCKET=$AQUEOUS_SOCKET" > /tmp/aq-init-env.out
sleep 45
INIT
chmod 755 /tmp/aq-init.sh

su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
  aqueous -c /tmp/aq-init.sh >/tmp/aq.log 2>&1 &
  AQ=$!
  sleep 6
  {
    echo "=== init env ==="; cat /tmp/aq-init-env.out 2>&1
    echo "=== runtime dir ==="; ls -la /home/dinx/.run/
    echo "=== aquous subdir mode ==="; stat -f "%Sp %N" /home/dinx/.run/aqueous 2>&1
    WD=$(grep -o "wayland-[0-9]*" /tmp/aq-init-env.out | head -1)
    echo "=== connect $WD ==="
    python3 -c "import socket,os;s=socket.socket(socket.AF_UNIX);s.settimeout(2);s.connect(os.path.join(\"/home/dinx/.run\",\"$WD\"));print(\"WAYLAND_CONNECT_OK\")" 2>&1 | tail -1
    echo "=== wayland-info (real client) ==="
    WAYLAND_DISPLAY=$WD timeout 6 wayland-info 2>&1 | head -8 || echo "wayland-info unavailable"
    echo "=== xwayland via DISPLAY ==="
    DISP=$(grep -o "DISPLAY=:[0-9]*" /tmp/aq-init-env.out | head -1 | cut -d= -f2)
    xdpyinfo -display "$DISP" >/tmp/x.out 2>&1 && grep -m1 "version number" /tmp/x.out || tail -2 /tmp/x.out
  } > /tmp/aqprobe.out 2>&1
  kill $AQ 2>/dev/null
' </dev/null
nc -N 10.0.2.2 9000 < /tmp/aqprobe.out
echo AQPROBE_DONE
