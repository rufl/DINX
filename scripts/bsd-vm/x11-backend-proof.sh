#!/bin/sh
# Validate the GPU-less desktop path that VirtualBox needs.
#
# There is no DRM driver for virtual GPUs on FreeBSD 15.1 (vboxvideo/vmwgfx
# were removed from drm-kmod), so no wlroots backend can scan out directly.
# Instead: run Xorg on a plain framebuffer driver (scfb/vesa, no KMS needed)
# and let wlroots use its x11 backend, which renders into an X11 window. The
# hypervisor console then shows the compositor.
#
# Same shape as VirtualBox: Xorg drives the virtual display through a
# framebuffer and Aqueous composites into it via x11.
set -u
R=/home/dinx/.run
mkdir -p "$R" /tmp/.X11-unix /usr/local/etc/X11/xorg.conf.d
chmod 700 "$R"; chmod 1777 /tmp/.X11-unix
chown dinx:dinx "$R"
rm -f "$R"/wayland-* "$R"/wl-* /tmp/aq-init.out /tmp/aq-init-x11.out
rm -rf "$R/aqueous"
rm -f /root/build/x11proof.out

# --- Xorg on the framebuffer driver: no DRI, no KMS ------------------------
cat > /usr/local/etc/X11/xorg.conf.dinx <<'XCONF'
Section "Device"
    Identifier  "fbdev"
    Driver      "scfb"
EndSection
Section "Monitor"
    Identifier  "Monitor0"
EndSection
Section "Screen"
    Identifier  "Screen0"
    Device      "fbdev"
    Monitor     "Monitor0"
    DefaultDepth 24
    SubSection "Display"
        Depth   24
        Modes   "1280x720"
    EndSubSection
EndSection
XCONF

# --- init child: Pearl keeps Aqueous alive, grim captures the output --------
cat > /tmp/aq-init.sh <<'INIT'
#!/bin/sh
{
  export XDG_CURRENT_DESKTOP=Aqueous
  echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY DISPLAY=${DISPLAY:-none}"
  pearl >/tmp/pearl.log 2>&1 &
  P=$!
  sleep 8
  if kill -0 $P 2>/dev/null; then echo "PEARL_ALIVE=yes"; else echo "PEARL_ALIVE=no"; fi
  tail -2 /tmp/pearl.log
  perl -e 'alarm 12; exec @ARGV' grim /tmp/dinx-x11.png >/tmp/grim.out 2>&1
  echo "GRIM_RC=$? $(head -1 /tmp/grim.out)"
  ls -la /tmp/dinx-x11.png 2>&1 | cut -c1-60
  echo "X11_INIT_DONE"
} > /tmp/aq-init-x11.out 2>&1
sleep 2
INIT
chmod 755 /tmp/aq-init.sh

# --- Xorg, then Aqueous on the x11 backend ---------------------------------
Xorg -config /usr/local/etc/X11/xorg.conf.dinx -noreset :0 vt2 >/tmp/xorg.log 2>&1 &
sleep 8

su -m dinx -c '
  export HOME=/home/dinx XDG_RUNTIME_DIR=/home/dinx/.run
  export PATH=/usr/local/bin:/usr/local/sbin:$PATH
  export DISPLAY=:0 WLR_BACKENDS=x11
  umask 077
  mkdir -p "$XDG_RUNTIME_DIR/aqueous"; chmod 700 "$XDG_RUNTIME_DIR/aqueous"
  aqueous -c /tmp/aq-init.sh >/tmp/aq-x11.log 2>&1 &
' </dev/null

sleep 30
{
  echo "=== xdpyinfo ==="
  DISPLAY=:0 xdpyinfo 2>&1 | grep -E "version number|dimensions|depth of root" | head -4
  echo "=== xorg.log errors ==="
  grep -iE "\(EE\)|error|scfb|no device" /tmp/xorg.log | head -6
  echo "=== init output ==="
  cat /tmp/aq-init-x11.out 2>&1
  echo "=== aqueous x11 log tail ==="
  tail -10 /tmp/aq-x11.log
} > /root/build/x11proof.out 2>&1

pkill -f "aqueous -c" 2>/dev/null
sleep 2
pkill Xorg 2>/dev/null
sh /root/build/push.sh /root/build/x11proof.out
echo X11_PROOF_DONE
