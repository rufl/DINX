#!/bin/sh
# Verify every package name listed in install-dinx-bsd.sh actually exists in the
# FreeBSD package catalogue, so firstboot does not log spurious failures.
set -u
NAMES="seatd wayland libxkbcommon xkeyboard-config libxcb xcb-util-errors \
xcb-util-renderutil xcb-util-wm libdrm libdisplay-info libliftoff mesa-libs \
mesa-dri vulkan-loader libinput libevdev libudev-devd pixman png cairo \
gdk-pixbuf2 glib gtk4 gtk4-layer-shell lcms2 libarchive libxml2 libsecret \
polkit curl cups pulseaudio pipewire wireplumber xwayland wayvnc basu jq"
BAD=0
for p in $NAMES; do
  if pkg rquery '%n' "$p" >/dev/null 2>&1; then
    printf 'OK   %s\n' "$p"
  else
    printf 'BAD  %s\n' "$p"
    BAD=$((BAD + 1))
  fi
done
echo "bad=$BAD"
