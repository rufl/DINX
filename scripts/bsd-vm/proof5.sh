#!/bin/sh
# Fully redirected graphical proof: Weston headless + Xwayland + Pearl + xterm,
# screenshot via weston-screenshooter bounded by perl alarm. Run as root.
set -u
export HOME=/home/dinx
export XDG_RUNTIME_DIR=/home/dinx/.run
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
mkdir -p "$XDG_RUNTIME_DIR" /tmp/.X11-unix
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
  cd /tmp
  perl -e "alarm 10; exec @ARGV" weston-screenshooter >/tmp/shot.log 2>&1
  echo SHOT=$?
  f=$(ls -t /tmp/wayland-screenshot*.png 2>/dev/null | head -1)
  [ -n "$f" ] && cp "$f" /tmp/proof.png
  ls -la /tmp/proof.png 2>&1 | cut -c1-60
  kill $WE 2>/dev/null
  echo PROOF5_DONE
' </dev/null
echo PROOF5_EXIT
