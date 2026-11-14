#!/bin/sh
# A/B isolate: does the init child run WITHOUT Xwayland? And is the Wayland
# socket connectable by a real client while the compositor is alive?
set -u
R=/home/dinx/.run
mkdir -p "$R" /tmp/.X11-unix
chmod 700 "$R"; chmod 1777 /tmp/.X11-unix
chown dinx:dinx "$R"
rm -f "$R"/wayland-* "$R"/wl-*; rm -rf "$R/aqueous"
rm -f /tmp/aq-init-env.out /tmp/ab.out
# The compositor's IPC dir check requires 0700; pre-create it and force umask.
mkdir -p "$R/aqueous"; chmod 700 "$R/aqueous"; chown dinx:dinx "$R/aqueous"

cat > /tmp/aq-init.sh <<'INIT'
#!/bin/sh
echo "INIT_RAN WAYLAND_DISPLAY=$WAYLAND_DISPLAY DISPLAY=${DISPLAY:-none}" > /tmp/aq-init-env.out
sleep 30
INIT
chmod 755 /tmp/aq-init.sh

su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
  umask 077
  # A) no xwayland
  aqueous -no-xwayland -c /tmp/aq-init.sh >/tmp/aqA.log 2>&1 &
  A=$!
  sleep 6
  {
    echo "=== A: no-xwayland ==="
    cat /tmp/aq-init-env.out 2>&1
    ls -la /home/dinx/.run/ | grep wayland
    WD=$(ls /home/dinx/.run/ | grep -o "^wayland-[0-9]*$" | head -1)
    echo "WD=$WD"
    WAYLAND_DISPLAY=$WD timeout 5 wayland-info 2>&1 | head -5
    echo "--- A log tail"
    tail -4 /tmp/aqA.log
  } > /tmp/ab.out 2>&1
  kill $A 2>/dev/null
' </dev/null
nc -N 10.0.2.2 9000 < /tmp/ab.out
echo AB_DONE
