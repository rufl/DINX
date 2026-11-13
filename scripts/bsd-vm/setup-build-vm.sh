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

# Runtime setup for the graphical session (mirrors the ISO overlay).
pkg install -y jq >/dev/null 2>&1
mkdir -p /usr/local/etc/greetd /etc/pam.d
printf 'auth\t\trequired\tpam_unix.so\naccount\t\trequired\tpam_permit.so\nsession\t\trequired\tpam_permit.so\npassword\trequired\tpam_permit.so\n' > /etc/pam.d/greetd
printf '[terminal]\nvt = 1\n\n[initial_session]\ncommand = "/usr/local/bin/dinx-session-select"\nuser = "dinx"\n\n[default_session]\ncommand = "agreety --cmd /usr/local/bin/dinx-session-select"\nuser = "greeter"\n' > /usr/local/etc/greetd/config.toml
[ -e /run ] || ln -s /var/run /run
mkdir -p /proc
mount -t linprocfs linprocfs /proc 2>/dev/null || true
id dinx >/dev/null 2>&1 || pw useradd dinx -m -s /bin/sh -G video -c 'DINX Desktop'
mkdir -p /home/dinx; chown dinx:dinx /home/dinx
echo "== runtime setup done"
