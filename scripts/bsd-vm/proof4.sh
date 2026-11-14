#!/bin/sh
# Graphical proof: Weston (headless backend, Xwayland on) + Pearl shell +
# an X11 client (xterm) through Xwayland, captured with weston-screenshooter.
# Run as root in the FreeBSD VM; everything runs as the dinx user.
set -u
export HOME=/home/dinx
export XDG_RUNTIME_DIR=/home/dinx/.run
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
chown dinx:dinx "$XDG_RUNTIME_DIR"
cfg="$XDG_RUNTIME_DIR/dinx-weston.ini"
cat > "$cfg" <<'EOF'
[core]
xwayland=true
idle-time=0
[shell]
panel-position=none
background-color=0xff101014
EOF
chown dinx:dinx "$cfg"
su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  weston --config=/home/dinx/.run/dinx-weston.ini \
    --backend=headless-backend.so --width=1280 --height=720 \
    --socket=wl-dinx >/tmp/weston.log 2>&1 &
  WE=$!
  sleep 4
  export WAYLAND_DISPLAY=wl-dinx XDG_CURRENT_DESKTOP=Weston
  pearl >/tmp/pearl.log 2>&1 &
  sleep 4
  DISPLAY=:0 xterm -geometry 80x24+60+60 >/tmp/xterm.log 2>&1 &
  sleep 3
  cd /tmp && weston-screenshooter
  echo SHOT=$?
  f=$(ls -t /tmp/wayland-screenshot*.png 2>/dev/null | head -1)
  [ -n "$f" ] && cp "$f" /tmp/proof.png
  ls -la /tmp/proof.png 2>&1 | cut -c1-60
  kill $WE 2>/dev/null
'
echo PROOF4_DONE
