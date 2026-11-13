# DINX-BSD Build and Installation Guide

The builder produces a bootable amd64 live/installer ISO based on the
checksum-pinned FreeBSD 15.1-RELEASE `disc1` image. The ISO boots a live
desktop with a first-run wizard and offers permanent installation via
`dinx-installer`, plus a verified DINX-BSD base overlay.

This milestone proves ISO creation, BIOS/UEFI boot metadata, unattended
installation, and first boot. It does not claim that the custom desktop ports
or the DINX package repository are ready.

## Host requirements

Supported build host: Linux x86_64.

Required commands:

- `curl`, `sha256sum`
- `bsdtar`
- `xorriso`
- `python3`
- `qemu-system-x86_64`, `qemu-img` for full qualification

On Ubuntu:

```bash
sudo apt-get install libarchive-tools qemu-system-x86 qemu-utils xorriso
```

## Build

Create and statically verify the ISO:

```bash
./scripts/build-bsd-iso.sh
```

Build the ISO, install it to a disposable QCOW2 disk, reboot that installation,
and wait for the DINX-BSD first-boot marker:

```bash
./scripts/build-bsd.sh
```

KVM is selected when `/dev/kvm` is accessible; otherwise qualification uses
QEMU TCG. Override with `DINX_BSD_QEMU_ACCEL=kvm` or
`DINX_BSD_QEMU_ACCEL=tcg`.

## Artifacts

The builder writes:

- `dist/bsd-iso/DINX-BSD-15.1-RELEASE-amd64.iso`
- `dist/bsd-iso/DINX-BSD-15.1-RELEASE-amd64.iso.sha256`
- `dist/bsd-iso/build-metadata.txt`
- `dist/bsd-iso/dinx-bsd-install.qemu.log` after full qualification

The upstream source is
`FreeBSD-15.1-RELEASE-amd64-disc1.iso`, pinned to SHA-256
`fa27646f05a1440fd26ffbb85e06a50bc86e128242a4e9cb7bb3ea76e1aa5fd9`.
Downloads are cached under `dist/bsd-cache/` and revalidated before reuse.
Set `DINX_BSD_SOURCE_ISO` to use an existing local copy with the same digest.

## Installer behavior

**Warning:** booting the generated ISO performs an unattended installation and
erases the only detected target disk.

The installer:

1. Uses FreeBSD's scripted default partition layout: MBR on BIOS boots, GPT
   on UEFI boots (`PARTITIONS=DEFAULT`; FreeBSD's loader, not GRUB).
2. Verifies and extracts `kernel.txz`, `base.txz`, and the DINX-BSD overlay.
3. Installs the BSD manifests, rc.d units, dinit unit definitions, OctaPkg
   configuration, source port recipes, and `/etc/dinx-release`.
4. Enables serial/video multiconsole boot and DHCP.
5. Reboots into the installed system; `rc.d/dinx_marker` emits the
   qualification marker consumed by the QEMU validator.
6. `rc.d/dinx_firstboot` runs once, detached via `daemon(8)` so it never
   blocks boot: it provisions the `dinx`
   and `greeter` accounts, installs the upstream graphical stack via `pkg`
   (seatd, PipeWire, WirePlumber, Wayland, wlroots020, mesa-dri), and enables
   `seatd` and `dinx_greetd`. The local `dinx` repository ships disabled and
   is enabled only when a real catalog exists; greetd and the custom
   Aqueous/Pearl packages come from that repository (greetd is built from
   source, absent from FreeBSD ports).

The root account remains locked. Sessions are compositor+shell:
`dinx-pearl-session` / `dinx-noctalia-session` start PipeWire/WirePlumber,
launch Aqueous and run the shell; they exit with an explicit error when a
component is missing instead of falling back to another desktop.

## Local port compilation

`./scripts/build-bsd-ports-local.sh` builds the custom ports from the local
source trees with Zig (`-Dtarget=x86_64-freebsd`). It emits real `.pkg` files
only on a FreeBSD host with `pkg(8)`, using `pkg create` and `pkg repo`; on
other hosts, or when a build fails, it writes staging trees and build logs
under `dist/bsd/ports/pkg/` and exits non-zero. It never fabricates package
archives, and packages are unsigned until a signing pipeline exists.

## Session management base (KaOS comparison)

KaOS 2026.09 ships `dinit > turnstile > seatd` with the Niri compositor and
the Noctalia shell. DINX-BSD keeps Aqueous + Pearl (Noctalia is an optional
alternative shell) and maps the same roles onto FreeBSD:

| Role | KaOS | DINX-BSD |
|------|------|----------|
| init/system services | dinit | rc(8); dinit units shipped as reference |
| seat/DRM/input | seatd | seatd (same) |
| session/login tracker, per-user services, XDG_RUNTIME_DIR | turnstile | greetd (utmp) + session wrappers (`/usr/local/libexec/dinx/session-common`); turnstile is Linux-only (cgroups/pidfd) and not in FreeBSD ports |
| compositor | Niri | Aqueous (wlroots020) |
| shell | Noctalia | Pearl; Noctalia alternative via `dinx-session-set noctalia` |

Sessions are `compositor + shell`: `dinx-pearl-session` and
`dinx-noctalia-session` start PipeWire/WirePlumber session-scoped, launch
Aqueous, wait for the Wayland socket, then run the shell; children are killed
when the session exits. `dinx-session-select` (used by greetd) reads
`~/.config/dinx/session`, then `/var/db/dinx-bsd/session` (default `pearl`).
`wayland-sessions` desktop entries are installed for greeters that list
sessions. Without a logind provider on FreeBSD, logind-dependent shell
features degrade; nothing emulates logind.


## Gaming and Linux compatibility (HyprBSD comparison)

HyprBSD (FreeBSD 15.1 + Hyprland) ships Steam through `games/linux-steam-utils`
(LSU) and Windows games through a hybrid Proton: FreeBSD `emulators/wine-proton`
binaries substituted into Proton, with the remaining Linux binaries run through
`emulators/libc6-shim` (no Linuxulator). DINX-BSD adopts the same stack:

- LSU sysctls are written to `/etc/sysctl.conf` at first boot
  (`compat.linux.use_real_ifnames`, `security.bsd.unprivileged_chroot`,
  `vfs.usermount`, shm limits) so they apply however Linux support loads;
  `nullfs` plus the detected GPU kmod (`amdgpu`, `i915kms`, `nvidia-modeset`)
  are added to `kld_list`, and `linux_enable=YES` with the rl9 base.
- A dedicated non-wheel `games` account is provisioned; Steam/LSU should run
  as that user (LSU uses unprivileged chroots; pressure-vessel does not work).
- `dinx-wine-proton` initializes the Wine prefix before exec'ing the
  wine-proton binaries; on 14.x the 32-bit side is installed via
  `pkg32.sh install wine-proton mesa-dri`.
- `mangohud` is included. Vulkan drivers (RADV/ANV) ship inside `mesa-dri`;
  there are no separate mesa-vulkan-* packages. `dxvk` and `gamemode` are not
  in FreeBSD ports and are therefore not installed; D3D->Vulkan translation
  is limited to what wine-proton provides.

Limits on FreeBSD 15.1, stated plainly: kernel anti-cheat (EAC/BattlEye) and
DX12/VKD3D remain unreliable; Proton fsync/seccomp features do not work.
timerfd exists on 15, so libc6-shim's CUDA/NVENC/NVDEC path works with a shim
build that includes timerfd support (older FreeBSD shim packages had an
aborting stub; HyprBSD carried the patch until upstream landed it).
The WoW64-only wine-proton path needs the patch from FreeBSD bug 288475;
`dinx-wine-proton` sets PROTON_USE_WOW64=1 on 15+.

## Live system, first-run wizard, persistence

The ISO boots a **live desktop** (NomadBSD/helloSystem model), not an
auto-installer: `/etc/rc.local` is remastered to `rc.local.live`, which marks
the system live (`/etc/dinx-live`), creates the `dinx` live account, installs
the autologin greetd config, and enables the rc chain. The disc1 root is
read-only cd9660, so `rc.local.live` makes `/etc`, `/var`, `/usr/local` and
`/home` writable with malloc memory disks, extracts the DINX overlay into
the live root, and starts the marker/persistence/wizard services for this
boot. Changes are ephemeral unless persistence is enabled. Package
installation (firstboot) runs on the installed system, not on the live md
layers; an offline live image with creative apps preinstalled requires a
FreeBSD-side remaster and is future work.

- **First-run wizard** (`dinx-first-run`, rc.d `dinx_first_run`, detached on
  the video console): macOS-style flow, language first, then keyboard, time
  zone, hostname, account+password, session (Pearl/Noctalia). It writes
  `/usr/local/etc/dinx/locale.conf` and `keyboard.conf` (exported by the
  session wrappers), sets `/etc/localtime`, hostname and the session default,
  then starts greetd. Runs on live and on installed first boot. TUI via
  base `bsddialog`; a graphical wizard replaces it once Pearl/Qt lands.
- **Persistence** (`dinx-live-persist`, NomadBSD-style): the wizard offers to
  create a `DINX-DATA` UFS partition in the boot USB's free space;
  rc.d `dinx_live_persist` remounts it at every boot and nullfs-mounts
  `/home`, `/usr/local/etc/dinx`, `/var/db/dinx-bsd` over it.
- **Permanent install**: `dinx-installer` (root) runs
  `bsdinstall script /etc/installerconfig` and reboots; the installed system
  runs the same wizard and first-boot setup. The QEMU gate exercises the full
  live -> install -> installed-boot path.
- Creative apps are installed by firstboot from the network when available;
  an offline live image with all creative apps preinstalled requires a
  FreeBSD-side remaster (pkg root into the live image) and is not yet built.


## Configuration

- `DINX_BSD_OUTPUT_DIR`: artifact directory.
- `DINX_BSD_CACHE_DIR`: verified source-image cache.
- `DINX_BSD_QEMU_TIMEOUT`: installation timeout in seconds.
- `DINX_BSD_QEMU_ACCEL`: `auto`, `kvm`, or `tcg`.
- `SOURCE_DATE_EPOCH`: timestamp used for generated overlay entries.

`.github/workflows/bsd-iso.yml` runs the full QEMU installation gate and uploads
the ISO, checksum, metadata, and serial log. Build or installation failures are
fatal; the workflow does not convert them into success.
