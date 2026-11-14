#!/bin/sh
# Headless proof v2: Aqueous (headless wlroots) + grim capture early, before
# the compositor's idle exit. aqueousctl (IPC keepalive) needs the compat shim
# preloaded for `environ`; the compositor itself must NOT be preloaded.
set -u
export HOME=/home/dinx
export XDG_RUNTIME_DIR=/home/dinx/.run
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
aqueous >/tmp/aqueous.log 2>&1 &
AQ=$!
sleep 1
(while kill -0 $AQ 2>/dev/null; do LD_PRELOAD=/usr/local/lib/libdinxcompat.so aqueousctl windows >/dev/null 2>&1; sleep 1; done) &
sleep 3
ls -la "$XDG_RUNTIME_DIR" | cut -c1-60
python3 -c 'import socket;s=socket.socket(socket.AF_UNIX);s.connect("/home/dinx/.run/wayland-1");print("CONNECT_OK")' 2>&1 | tail -1
WAYLAND_DISPLAY=wayland-1 grim /tmp/proof.png
echo GRIM=$?
sleep 1
ls -la /tmp/proof.png 2>&1 | cut -c1-60
kill $AQ 2>/dev/null
echo PROOF2_DONE
