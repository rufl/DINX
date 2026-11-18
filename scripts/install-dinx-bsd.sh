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
pw useradd dinx -m -s /bin/sh -G video -c 'DINX Desktop' 2>/dev/null \
  || log 'user dinx already exists'
pw groupmod video -m dinx 2>/dev/null || true
pw useradd greeter -m -s /bin/sh -c 'DINX Greeter' 2>/dev/null \
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
  # Every shared library our native packages link against, resolved by
  # scripts/bsd-vm/check-shlibs.py against the pkg database (each dinx-*.pkg
  # declares shlibs_required but no deps, so these must be installed first or
  # `pkg add` fails with "Missing shlib"). Plus the runtime pieces that are not
  # shlib deps: XKB data, the Mesa Vulkan software driver, Xwayland, wayvnc for
  # headless/VNC sessions, audio and jq. The Adwaita icon theme is mandatory,
  # not cosmetic: GTK4 resolves its fallback icons through it, and without it
  # every GtkImage gets baseline INT32_MIN, which gdkshm turns into an invalid
  # Cairo image surface -> SIGSEGV inside the Pearl shell right after
  # `event=ready`.
  for p in \
    seatd \
    wayland libxkbcommon xkeyboard-config \
    libxcb xcb-util-errors xcb-util-renderutil xcb-util-wm \
    libdrm libdisplay-info libliftoff mesa-libs mesa-dri \
    vulkan-loader \
    libinput libevdev libudev-devd \
    pixman png cairo gdk-pixbuf2 glib gtk4 gtk4-layer-shell \
    lcms2 libarchive libxml2 libsecret polkit \
    curl cups \
    pulseaudio pipewire wireplumber \
    adwaita-icon-theme \
    xwayland wayvnc basu jq; do
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
  pkg install -y -r dinx dinx-compat dinx-wlroots dinx-greetd \
    dinx-aqueous dinx-pearl \
    || log 'WARNING: custom DINX package install failed'
  for optional_pkg in dome deetty dinted; do
    pkg install -y -r dinx "$optional_pkg" \
      || log "NOTE: optional package $optional_pkg not available"
  done
  # river session stack. river is the compositor (official catalogue, verified
  # river-0.4.8 / x11-wm/river); kwm is our patched port, kwim the input manager
  # (separate upstream), river-shifttags the tag CLI the shell shells out to.
  # All optional -- the default session stays Aqueous+Pearl.
  #
  # The catalogue packages carry runtime deps the local dinx packages do not
  # declare, so install them explicitly; each was observed to be required:
  #   dbus          -- dinx-river-session wraps river in dbus-run-session; the
  #                    shell aborts with "Cannot autolaunch D-Bus" without it
  #   fcft          -- kwm's bar links libfcft (build.zig linkSystemLibrary)
  #   terminus-font -- kwm died with fcft "failed to match font" -> error.NoFont
  #                    -> "create output failed" until a font exists; the
  #                    package names I first tried (dejavufonts, fc-fontconfig)
  #                    do not exist in this catalogue
  #   fontconfig    -- resolves the fcft font pattern above
  if pkg install -y river dbus fcft terminus-font fontconfig >/dev/null 2>&1 \
     && pkg install -y -r dinx dinx-kwm dinx-kwim dinx-river-shifttags >/dev/null 2>&1; then
    log 'river session stack installed (select with: dinx-session-set river)'
  else
    log 'NOTE: river session stack incomplete or unavailable'
  fi
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

# Compile the GSettings schemas. FreeBSD has no package trigger for this, and a
# GTK shell aborts at startup without its compiled schema: morghulis dies with
# "Settings schema 'com.arkye.morghulis' is not installed" (verified on 15.1).
# meson installs the .xml into $PREFIX/share/glib-2.0/schemas; only the binary
# gschemas.compiled cache is missing.
if command -v glib-compile-schemas >/dev/null 2>&1 \
   && [ -d /usr/local/share/glib-2.0/schemas ]; then
  glib-compile-schemas /usr/local/share/glib-2.0/schemas >/dev/null 2>&1 \
    && log 'compiled GSettings schemas' \
    || log 'WARNING: glib-compile-schemas failed'
fi
# Same reasoning for the desktop database: .desktop entries are not indexed
# until it is rebuilt, so launchers/app-lists come up empty otherwise.
if command -v update-desktop-database >/dev/null 2>&1 \
   && [ -d /usr/local/share/applications ]; then
  update-desktop-database /usr/local/share/applications >/dev/null 2>&1 || true
fi

sysrc seatd_enable=YES >/dev/null
sysrc dinx_session_enable=YES >/dev/null
sysrc vboxguest_enable=YES >/dev/null 2>&1 || log 'WARNING: vboxguest load failed'
sysrc vboxservice_enable=YES >/dev/null 2>&1 || log 'WARNING: vboxservice enable failed'
if [ -f /var/db/dinx-bsd/first-run-done ]; then
  service dinx_session start >/dev/null 2>&1 \
    || log 'WARNING: session start failed'
else
  log 'desktop session deferred until first-run wizard completes'
fi

if [ "$pkg_ready" = 1 ]; then
  touch "$done_flag"
  log 'first-boot desktop setup finished'
else
  log 'first-boot desktop setup deferred; will retry on next boot'
fi
exit 0
