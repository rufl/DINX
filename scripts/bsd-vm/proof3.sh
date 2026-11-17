#!/bin/sh
# Nested headless proof: Weston (headless backend) provides a known-good
# Wayland socket; Aqueous runs nested on it (WLR_BACKENDS=wayland) and spawns
# Pearl via its session init; grim captures Weston's output.
set -u
export HOME=/home/dinx
export XDG_RUNTIME_DIR=/home/dinx/.run
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
weston --backend=headless-backend.so --socket=wl-weston --width=1280 --height=720 >/tmp/weston.log 2>&1 &
WE=$!
sleep 3
WAYLAND_DISPLAY=wl-weston WLR_BACKENDS=wayland WLR_LIBINPUT_NO_DEVICES=1 aqueous >/tmp/aqueous.log 2>&1 &
AQ=$!
sleep 6
WAYLAND_DISPLAY=wl-weston grim /tmp/proof.png
echo GRIM=$?
ls -la /tmp/proof.png 2>&1 | cut -c1-60
kill $AQ $WE 2>/dev/null
echo PROOF3_DONE
