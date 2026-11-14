#!/bin/sh
# Headless graphical proof: Aqueous (wlroots headless backend) + Pearl shell,
# captured with grim (wlr-screencopy). Run as root inside the FreeBSD VM.
# QEMU emulated GPUs have no FreeBSD DRM driver, so headless is the only
# way to exercise the real compositor + shell render path in a VM.
set -u
RUN=/tmp/dinx-run
mkdir -p "$RUN"
chmod 700 "$RUN"
chown dinx:dinx "$RUN"
su -m dinx -c '
  export XDG_RUNTIME_DIR=/tmp/dinx-run
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  aqueous >/tmp/aqueous.log 2>&1 &
  sleep 4
  export WAYLAND_DISPLAY=wayland-0
  pearl >/tmp/pearl.log 2>&1 &
  sleep 6
  grim /tmp/proof.png
  echo GRIM=$?
'
echo HEADLESS_PROOF_DONE
