#!/bin/sh
# Probe: is Weston's Wayland socket actually listening? Keep Weston alive.
set -u
export HOME=/home/dinx
export XDG_RUNTIME_DIR=/home/dinx/.run
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  weston --config=/home/dinx/.run/dinx-weston.ini \
    --backend=headless-backend.so --width=1280 --height=720 \
    --socket=wl-x >/tmp/w7.log 2>&1 &
  sleep 4
  ls /home/dinx/.run/
  python3 -c "import socket;s=socket.socket(socket.AF_UNIX);s.connect(\"/home/dinx/.run/wl-x\");print(\"CONNECT_OK\")" 2>&1 | tail -1
  export WAYLAND_DISPLAY=wl-x XDG_CURRENT_DESKTOP=Weston
  cd /tmp
  perl -e "alarm 8; exec @ARGV" weston-screenshooter
  echo SHOT=$?
  ls -t /tmp/wayland-screenshot*.png 2>/dev/null | head -1
  pgrep -l weston
' </dev/null
echo PROOF6_DONE
