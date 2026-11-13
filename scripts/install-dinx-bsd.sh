#!/bin/sh
# DINX-BSD first-boot desktop setup. Runs on the installed FreeBSD target via
# rc.d/dinx_firstboot (after NETWORKING), never inside the installer chroot.
# POSIX sh only: the base system has no bash.
set -u

log() { printf 'install-dinx-bsd: %s\n' "$*"; }

[ "$(uname)" = "FreeBSD" ] || { log 'must run on a FreeBSD target'; exit 1; }
[ "$(id -u)" = 0 ] || { log 'requires root'; exit 1; }

share=/usr/local/share/dinx-bsd/distro/bsd
done_flag=/var/db/dinx-bsd/desktop-setup-done
[ -f "$done_flag" ] && exit 0
mkdir -p /var/db/dinx-bsd

# Session accounts used by greetd (greeter) and the desktop session (dinx).
pw useradd dinx -m -s /bin/sh -c 'DINX Desktop' 2>/dev/null \
  || log 'user dinx already exists'
pw useradd greeter -s /bin/sh -c 'DINX Greeter' 2>/dev/null \
  || log 'user greeter already exists'

# Local DINX repository definition (UCL, target paths only).
mkdir -p /usr/local/etc/pkg/repos
if [ -f "$share/config/pkg-repos/dinx.conf" ]; then
  install -m 0644 "$share/config/pkg-repos/dinx.conf" \
    /usr/local/etc/pkg/repos/dinx.conf
fi

# Real upstream FreeBSD packages for the graphical stack. dhclient writes
# resolv.conf asynchronously, so wait for DNS and retry the catalogue update.
pkg_ready=0
i=0
while [ "$i" -lt 24 ]; do
  if [ ! -s /etc/resolv.conf ]; then
    # dhcpcd when present; 15.1 still ships dhclient, handled below.
    if command -v dhcpcd >/dev/null 2>&1; then
      iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
      if [ -z "$iface" ]; then
        iface=$(ifconfig -l | tr ' ' '\n' | grep -v '^lo' | head -1)
      fi
      [ -n "$iface" ] && dhcpcd -q "$iface" >/dev/null 2>&1
    fi
    # dhclient (14.x) may be mid-renewal; recover DNS from its lease file.
    for lease in /var/db/dhclient.leases.*; do
      [ -f "$lease" ] || continue
      awk '/option domain-name-servers/ {
             gsub(/;/, "", $3); n = split($3, s, ",");
             for (j = 1; j <= n; j++) print "nameserver " s[j]
           }' "$lease" > /etc/resolv.conf
      [ -s /etc/resolv.conf ] && break
    done
  fi
  if [ -s /etc/resolv.conf ] && route -n get default >/dev/null 2>&1 \
     && ASSUME_ALWAYS_YES=yes pkg bootstrap >/dev/null 2>&1 \
     && pkg update -f >/dev/null 2>&1; then
    pkg_ready=1
    break
  fi
  i=$((i + 1))
  sleep 5
done
if [ "$pkg_ready" = 1 ]; then
  for p in seatd pipewire wireplumber wayland wlroots020 mesa-dri \
           libxkbcommon xkeyboard-config jq; do
    if pkg install -y "$p" >/dev/null 2>&1; then
      log "installed $p"
    else
      log "WARNING: failed to install $p"
    fi
  done
fi

# Custom DINX packages only when a real local repository catalog exists.
if [ -f "$share/ports/pkg/repo/packagesite.txz" ] || [ -f "$share/ports/pkg/repo/packagesite.pkg" ]; then
  sed -i '' 's/enabled: no/enabled: yes/' /usr/local/etc/pkg/repos/dinx.conf
  pkg install -y -r dinx dinx-wlroots dinx-greetd dinx-aqueous dinx-pearl \
    || log 'WARNING: custom DINX package install failed'
  pkg install -y -r dinx noctalia \
    || log 'NOTE: noctalia alternative shell not available'
else
  log 'local DINX repo has no catalog; custom ports pending native build'
fi

# Gaming / Linux compatibility stack (HyprBSD-style, guarded).
if [ "$pkg_ready" = 1 ]; then
  gpu=$(pciconf -lv 2>/dev/null | grep -A3 'class=0x03' \
        | grep -i vendor | head -1)
  kld=""
  case "$gpu" in
    *NVIDIA*)
      kld="nvidia-modeset"
      pkg install -y nvidia-driver >/dev/null 2>&1 \
        || log 'WARNING: failed to install nvidia-driver'
      ;;
    *Intel*) kld="i915kms" ;;
    *AMD*|*ATI*) kld="amdgpu" ;;
  esac
  for p in drm-kmod mesa-dri vulkan-loader vulkan-tools wine-proton \
           libc6-shim linux-steam-utils linux-rl9-dbus-libs linux-rl9-devtools \
           linux-rl9-nss ca_root_nss ruby; do
    if pkg install -y "$p" >/dev/null 2>&1; then
      log "installed $p"
    else
      log "WARNING: failed to install $p"
    fi
  done
  # LSU needs these; the Linux compat sysctl must live in sysctl.conf so it
  # applies however linux support gets loaded (HyprBSD NVIDIA restart bug).
  for s in 'compat.linux.use_real_ifnames=1' 'security.bsd.unprivileged_chroot=1' \
           'vfs.usermount=1' 'kern.ipc.shmmax=2147483648' 'kern.ipc.shmall=524288'; do
    grep -q "^${s%%=*}" /etc/sysctl.conf 2>/dev/null \
      || printf '%s\n' "$s" >> /etc/sysctl.conf
  done
  sysrc kld_list+="nullfs${kld:+ $kld}" >/dev/null
  sysrc linux_enable=YES >/dev/null
  service linux start >/dev/null 2>&1 || log 'WARNING: linux start failed'
  pw useradd games -m -s /bin/sh -c 'DINX Games' 2>/dev/null \
    || log 'user games already exists'
  if [ "$(uname -U)" -lt 1500000 ] && [ -x /usr/local/wine-proton/bin/pkg32.sh ]; then
    /usr/local/wine-proton/bin/pkg32.sh install wine-proton mesa-dri \
      >/dev/null 2>&1 || log 'WARNING: 32-bit wine-proton setup failed'
  fi
fi

sysrc seatd_enable=YES >/dev/null
sysrc dinx_greetd_enable=YES >/dev/null
service seatd start >/dev/null 2>&1 || log 'WARNING: seatd start failed'
service dinx_greetd start >/dev/null 2>&1 || log 'WARNING: greetd start failed'

if [ "$pkg_ready" = 1 ]; then
  touch "$done_flag"
  log 'first-boot desktop setup finished'
else
  log 'first-boot desktop setup deferred; will retry on next boot'
fi
exit 0
