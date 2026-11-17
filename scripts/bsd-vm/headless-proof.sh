#!/bin/sh
# Headless graphical proof: Aqueous (wlroots headless backend) spawns Pearl
# through its session init (which exports XDG_CURRENT_DESKTOP=Aqueous), then
# grim captures the compositor output via wlr-screencopy. Run as root in the
# FreeBSD VM. QEMU emulated GPUs have no FreeBSD DRM driver, so headless is
# the only way to exercise the real compositor + shell render path in a VM.
set -u
RUN=/home/dinx/.run
mkdir -p "$RUN"
chmod 700 "$RUN"
chown dinx:dinx "$RUN"
mkdir -p /home/dinx/.config/aqueous
printf '#!/bin/sh\nexec pearl >/tmp/pearl.log 2>&1\n' > /home/dinx/.config/aqueous/init
chmod 755 /home/dinx/.config/aqueous/init
chown -R dinx:dinx /home/dinx/.config
su -m dinx -c '
  export XDG_RUNTIME_DIR=/home/dinx/.run
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  export HOME=/home/dinx
  aqueous >/tmp/aqueous.log 2>&1 &
  sleep 8
  export WAYLAND_DISPLAY=wayland-1
  grim /tmp/proof.png
  echo GRIM=$?
'
echo HEADLESS_PROOF_DONE
