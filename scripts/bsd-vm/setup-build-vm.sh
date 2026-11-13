#!/bin/sh
# One-shot build-VM setup: deps, Zig toolchain, sources, native build+package.
# Run INSIDE the FreeBSD build VM as root: sh setup-build-vm.sh
set -u
LOG=/root/setup-build-vm.log
: > "$LOG"
exec >>"$LOG" 2>&1


# The detached firstboot holds the pkg lock on first boot; wait for it.
i=0
while [ ! -f /var/db/dinx-bsd/desktop-setup-done ] && [ $i -lt 120 ]; do
  sleep 5
  i=$((i + 1))
done
pkg install -y wlroots020 wayland-protocols libxkbcommon pixman libinput \
  seatd gtk4 gtk4-layer-shell meson ninja pkgconf git-lite rust \
  gobject-introspection mesa-dri pulseaudio python3
echo "== deps exit=$?"

mkdir -p /root/build
cd /root/build || exit 1
if [ ! -d zig-x86_64-freebsd-0.17.0 ]; then
  fetch -o zig.tar.xz https://ziglang.org/download/0.17.0/zig-x86_64-freebsd-0.17.0.tar.xz
  tar -xf zig.tar.xz
fi
[ -d Aqueous ] || git clone --depth 1 https://github.com/Seafoam-Labs/Aqueous.git
[ -d pearl ] || git clone --depth 1 https://github.com/Seafoam-Labs/pearl.git
echo "== sources ready"

sh /root/build/build-native.sh
echo "== SETUP_BUILD_DONE"
