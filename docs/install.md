# DINX easy install

[English](install.md) · [Português (Brasil)](pt-BR/install.md)

## Current alpha status

The current DINX image is a **live validation ISO with an experimental disk installer**. Calamares installs from the ISO root filesystem without requiring a network connection; it creates the user, configures dinit and GRUB, and removes the live-only packages. This guide covers the safe download, verification, boot and experimental installation paths. It does not promise production hardware support, installed-ISO upgrades, filesystem rollback or data preservation.

The published release is the **Alpha 12 system alpha**, not a gaming beta: [v0.1.0-alpha.12](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12), published by tagged workflow [41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) from commit `56a814575e33bfae6215993972784f11b7dae215`. Its direct ISO is 1,836,830,720 bytes with SHA-512 `ac1dbd237e484f8d61aab5438185218b13d9e23824ce671440ff67ed275ce7073b90dbcc14bc8d8f7008b2422d66e2756f1b3a88a0d5c21d8c7bbc67c9d60bf9`. Beta 0.1 is a planned, undated system-qualification milestone; see the [roadmap](roadmap.md).

The earlier post-Alpha-10 main P0 run [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770) passed its build, QEMU, installation and recovery gates but did not change the tagged ISO. Alpha 12 was published later; the current shared qualifier tests default VGA and Virtio-VGA. QEMU 11.1.2/KVM with `vmware-svga` stalls in early udev when `vmwgfx` loads, so this emulator path is not a VirtualBox pass; direct VBox boot remains unqualified.

Pori is the dinit storage tool. Use it to inspect disks and create persistent mount services under `/etc/dinit.d`; use File Roller to open, create and extract archives, GParted to edit partitions outside the installer, and Calamares for the final partitioning and installation transaction.

Do not use the ISO on a machine containing data that you cannot restore. The live session and the installer are alpha software.

## Requirements

- x86_64 computer or virtual machine;
- UEFI firmware is recommended; legacy BIOS/MBR machines boot the same image through its hybrid MBR;
- a USB drive of at least 4 GB; writing the image erases the whole drive;
- at least 4 GB RAM recommended for hardware testing. The CI smoke test uses 2 GB, but that is not a supported hardware minimum;
- a second device or existing system from which to download and verify the image;
- a backup of every disk that could be selected accidentally.

The current alpha has no signed bootloader, no supported Secure Boot path and no final GPU/hardware compatibility matrix. A machine may boot successfully while still having unsupported graphics, Wi-Fi, audio or suspend behavior.

## 1. Obtain the ISO artifact

The published Alpha 12 system alpha has a direct ISO and matching checksum in its [tagged release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12). Use that release as the primary download. P0 workflow artifacts are temporary fallbacks retained for seven days and replaced by later runs.

### Tagged alpha release

1. Open the [DINX releases](https://github.com/rufl/DINX/releases).
2. Select the latest pre-release.
3. Download `dinx-<version>-x86_64.iso` and its matching `.iso.sha512`. Older releases without a direct ISO require every `dinx-<version>-x86_64.iso.part-*` file and `.iso.parts.json`.
4. For a split ISO, concatenate the parts in lexical order:

   ```bash
   cat dinx-<version>-x86_64.iso.part-* > dinx-<version>-x86_64.iso
   ```

5. Continue with checksum verification below.

The [release guide](release.md) documents the Windows QEMU launcher and ZTASH deployment path.

### Browser

1. Open the [P0 ISO workflow](https://github.com/rufl/DINX/actions/workflows/p0-iso.yml).
2. Open the newest run with a green success mark.
3. In **Artifacts**, download `dinx-p0-success-<commit>` from that successful run.
4. Extract the downloaded archive into a new directory.
5. Continue with the `.iso` and matching `.iso.sha512` files from the extracted directory.

### GitHub CLI

Install and authenticate GitHub CLI if it is not already available:

```bash
gh auth login
```

Download the newest successful artifact:

```bash
repo=rufl/DINX
run_id=$(gh run list \
  --repo "$repo" \
  --workflow p0-iso.yml \
  --status success \
  --limit 1 \
  --json databaseId \
  --jq '.[0].databaseId')
test -n "$run_id"
commit=$(gh run view "$run_id" --repo "$repo" --json headSha --jq '.headSha')
gh run download "$run_id" \
  --repo "$repo" \
  --name "dinx-p0-success-$commit" \
  --dir dinx-iso
```

Find the extracted image:

```bash
find dinx-iso -type f \( -name '*.iso' -o -name '*.sha512' \) -print
```

## 2. Verify the image before booting

Change into the directory containing both the ISO and its checksum. The checksum file must name the same ISO file:

```bash
cd dinx-iso/dinx
sha512sum -c artix-dinx-dinit-*-x86_64.iso.sha512
```

Expected result:

```text
artix-dinx-dinit-<date>-x86_64.iso: OK
```

If verification fails, stop. Delete the incomplete download and download the artifact again. Never write an image with a failed or missing checksum.

The checksum authenticates the downloaded bytes against the workflow output; it does not prove that the public workflow inputs are production-safe. Read the commit, workflow log and documented limitations before testing hardware.

## 3. Write a bootable USB

The target must be the **whole USB device**, such as `/dev/sdb`, not a partition such as `/dev/sdb1`. Selecting the wrong device destroys its data.

### Linux

Identify the USB by model, size and transport. Unmount its existing partitions, then write the verified ISO:

```bash
lsblk -p -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
sudo umount /dev/sdX1   # replace with the mounted USB partition(s)
sudo dd if=artix-dinx-dinit-<date>-x86_64.iso \
  of=/dev/sdX \
  bs=4M status=progress conv=fsync
sync
```

Replace both placeholders after checking `lsblk` again. Do not use an internal disk as `of=`.

### macOS

Find the USB disk, unmount it without ejecting it, write to the raw device and eject it:

```bash
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=artix-dinx-dinit-<date>-x86_64.iso \
  of=/dev/rdiskN \
  bs=4m
sync
diskutil eject /dev/diskN
```

Use the `rdiskN` that corresponds to the USB, never the internal disk.

### Windows

Use a trusted image writer such as Rufus. Select the verified ISO and the correct USB drive, choose GPT/UEFI when prompted, and use raw/DD mode if the writer asks. Confirm every erase prompt only after checking the drive size and model.

## 4. Boot the live system

1. Insert the USB.
2. Reboot and open the one-time boot menu (`F12`, `F11`, `Esc` or the vendor-specific key).
3. Select the UEFI entry for the USB, or the plain/legacy USB entry on BIOS-only machines (for example older notebooks such as the HP dm1 with an AMD E-350); the hybrid MBR boots the same GRUB menu.
4. If the firmware refuses the image, disable Secure Boot for this test; the current alpha does not provide a signed Secure Boot path.
5. The current main image starts directly in `River + KWM (DINX)`; no live username or password prompt is required. The published Alpha 12 predates this session stack and is not covered by this step.

The live ISO opens the disposable `dinx` account directly in `River + KWM (DINX)`. This is live-only; installed login and Calamares autologin remain disabled. Anyone who can boot the ISO already controls the live machine; never reuse the public `dinx` password elsewhere.

Once the desktop appears, the tested graphical state is River/KWM. Network, audio, GPU acceleration, suspend/resume and recovery TTY remain hardware-dependent validation areas.
River is the active compositor and KWM the active window manager. The static DINX theme is applied through the checked-in GTK/Qt bridges; the installed greeter is agreety under greetd, running as the `greeter` account with `command = "env XDG_CACHE_HOME=/var/cache/agreety agreety --cmd /usr/local/libexec/dinx-river-session"`, with no greeter JSON file and without X11 or UWSM.

KWM starts in a floating stacking layout by default: the packaged global window rule marks every managed client floating, preserves floating geometry and disables terminal swallowing, so windows behave like a conventional Windows/macOS desktop instead of tiling. Users may edit `~/.config/kwm/config.zon` to choose another layout; `dinx-river-session` seeds that file from the packaged `/etc/xdg/kwm/config.zon` only when it is absent, so their changes survive later boots. River and KWM negotiate `xdg-decoration`: server-side-decorated windows get the compositor's own decoration, and clients that keep their own decorations are not decorated twice. The fixed `:minimize,maximize,close` layout applies to client-side-decorated toolkits.
PCManFM is the default directory handler and file manager, and it renders the `~/Desktop` icons through `pcmanfm --desktop`. File Roller provides graphical actions to open, create and extract archives. GParted edits partitions outside the installation flow. Pori is the storage surface for inspecting disks and creating persistent mount services; it uses UDisks2 for discovery and dinit for service lifecycle. The base ISO includes DINX's `dinx-wdisplays` wrapper for interactive Wayland output configuration; closing it saves the current layout as the `DINX wdisplays` profile and reloads Shikane, which starts inside the River/KWM session and reapplies matching profiles. Dintor is the bundled Zig editor. River and KWM are the only selectable session components.

### Optional BC-250 support

The Alpha 12 generic ISO excludes the BC250 Control Center and Cyan Skillfish governor. Their pinned packages are available in the signed DINX repository; install them only after confirming PCI ID `1002:13fe`. First configure and locally trust the signed repository as documented in [`release.md`](release.md):

```bash
if lspci -n -d 1002:13fe | grep -Fq '1002:13fe'; then
  pkexec pacman -Syu --needed bc250-control-center cyan-skillfish-governor-smu-dinit
else
  printf 'PCI 1002:13fe not detected; BC-250 packages were not installed.\n' >&2
  exit 1
fi
```

The governor checks PCI `1002:13fe` before applying settings. The guard above prevents the install command from running on other hardware. Neither BC-250 package is preinstalled in the generic ISO.

## Secure package updates

DINX source now configures a signed rolling pacman repository at the GitHub
Release URL `https://github.com/rufl/DINX/releases/download/dinx-packages-latest`.
Every Monday at 04:17 UTC, the updater checks 13 release-based upstream source
pins and opens one reviewed pull request. Deetty's private commit and the
ZLS/Zig 0.16 coupled pins remain manual. Merged package changes use a separate
signed package-only workflow; they do not trigger P0 ISO assembly. The workflows
are configured but are not yet confirmed green or published.

Once `dinx-keyring` is available, install it and update through pacman and Octopi:

```bash
pkexec pacman -Syu --needed dinx-keyring
checkupdates
paru -Qu
```

`checkupdates` (from `pacman-contrib`) lists pending official-repository updates
and `paru -Qu` lists the AUR side; both are read-only. Apply updates interactively
in **Octopi**, launched from DINXPanel's `Package manager` button or from the dock,
or run `pkexec pacman -Syu` in the terminal. Octopi has no command-line interface.
DINX ships no sudo, so Octopi elevation goes through `pkexec` and polkit with
`lxqt-policykit-agent`. pacman requires valid signatures for the `[dinx]` repository.

For bootstrap when the rolling repository is published but `dinx-keyring` is
not yet available, follow the manual public-key verification and repository
setup in the [release guide](release.md). Verify the key SHA-256 and full
fingerprint `D8F294B7367BD0DAF626E4DCD411E36494CB9CEB` before local trust.
`dinx-keyring` configures `[dinx]` and `/etc/pacman.d/dinx-mirrorlist`; that
mirrorlist is editable for future mirrors.

## 5. Experimental persistent installation

From the live desktop:

1. Open the **Install DINX** desktop shortcut or choose **Install DINX** from the application launcher; the duplicate upstream Calamares entry is hidden. On the live DINX desktop, the package-owned shortcut is executable and approved before the session starts, so first launch requires no separate “Allow launching” step.
2. If neither shortcut is available, run `/usr/local/libexec/dinx-installer` from a terminal in the live desktop session; it preserves the Wayland/D-Bus session for polkit, checks prerequisites and displays authorization or startup errors.
3. Read **Install choices / Opções de instalação** before choosing partitions.
4. Choose the layout that matches your intent:
   - **Erase disk** creates the layout automatically and erases all data on the selected disk. Choose it only if intended; verify the disk model and size.
   - **Install alongside** keeps another system when Calamares offers the option.
   - **Replace a partition** erases the selected partition. **Manual partitioning** is for advanced users; it requires `/` and, in UEFI, a FAT32 EFI partition mounted at `/boot/efi`.
5. Swap is optional. The default is no swap; DINX installs and boots without a swap partition.
6. Review the target disk, firmware mode, mount points and planned changes on the summary page before confirming.
7. For advanced storage operations, open **Pori** from the application launcher. It discovers block devices through UDisks2 and persists user-selected mounts as dinit services under `/etc/dinit.d`; use **GParted** to edit partitions outside Calamares, **File Roller** to work with archives, `dinx-wdisplays` for interactive output setup and automatic Shikane profile persistence.
8. Keep the ISO/USB connected until the installer finishes. The first profile supports ext4 and btrfs; the installer copies its root filesystem offline.

The current DINX root filesystem occupies about 7 GiB installed. For VirtualBox, use a virtual disk of at least 16 GiB and leave free storage on the host for the virtual disk file. A small target or a full host can make Calamares fail while copying the root filesystem; rsync exit code 11 means a file-I/O error, not one specific cause.
Calamares and GParted can erase, format or resize data. Pori mount actions do not format disks, but verify the device, filesystem and mount target before confirming any privileged action. The final confirmation is not a safety net for selecting the wrong disk. Back up the machine and verify the model, size and serial information of the target device.
The Alpha 12 Calamares qualification covers a Windows-style GPT layout: an existing FAT32 ESP containing `EFI/Microsoft`, an NTFS Windows partition and DINX root space created after it. The smoke preserves the Windows partition and Microsoft boot path while writing DINX fstab and GRUB data for both a side-by-side outcome and an explicit manual layout. The live ISO and installed base use the kernel `ntfs3` driver for NTFS read/write; legacy `ntfs-3g` is optional after installation for compatibility and repair tools. The profile includes `os-prober`, enables GRUB's Windows detection and uses a separate `DINX` EFI directory. An existing ESP of at least 64 MiB is accepted because DINX keeps `/boot` on the root filesystem; a new ESP is recommended at 1 GiB. If the existing ESP is smaller or full, create a new FAT32 ESP in free space through the manual layout instead of formatting the Microsoft ESP. Do not format the existing ESP or Windows/MSR/recovery partitions. Boot DINX in the same UEFI mode as Windows, fully shut Windows down, disable Fast Startup/hibernation, suspend BitLocker with its recovery key available, and leave a verified backup before attempting a resize.
### First boot and recovery TTY

The CI installation contract boots the copied root filesystem from disposable BIOS and UEFI disks and enables `getty@tty2` and `getty@tty3` for recovery. These are QEMU disk smokes, not physical hardware qualification. On a real installation, press `Ctrl+Alt+F2` or `Ctrl+Alt+F3` at the installed system's greeter to open a TTY and log in with the user created during installation. Useful recovery commands:

```bash
dinitctl status greetd
dinitctl restart greetd
```

Deetty is the sole terminal emulator in the live ISO and fresh installation. The live and installed sessions set `$TERMINAL` to `deetty`; Nano remains available as a recovery editor. agreety is the greetd login surface, not a user-session configuration.

To record the system state without changing it, run:

```bash
dinx-doctor
```

The report uses the `dinx-doctor/v1` schema and marks unavailable capabilities as `missing` or `unknown`. To include a read-only list of user dinit services, run `DINX_DOCTOR_QUERY_DINIT=1 dinx-doctor`; to inspect the last 100 lines of session/component logs, run `dinx-doctor --logs`. Core dumps are opt-in via `DINX_ENABLE_CORE_DUMPS=1` before session launch and limited to 64 MiB per process. Do not treat the report as proof of hardware compatibility: physical brightness, suspend, GPU, audio, shared NTFS and volume mounting still require testing on the machine.



## 6. What this alpha can and cannot do

### Supported by the current smoke evidence

- x86_64 boot path in QEMU;
- agreety login surface and greetd configuration;
- graphical login into the River/KWM session;
- River 0.5 startup through the DINX session supervisor, including required KWM startup and KWM-managed KWIM input;
- presence of the expected dinit, network, PipeWire and portal payloads in the ISO;
- Windows-style GPT side-by-side and manual-layout transaction smoke: existing FAT32 ESP/Microsoft boot files and NTFS partition remain intact while DINX root, fstab and GRUB data are added;
- presence of the Calamares offline-install configuration, Pori, PCManFM and the kernel `ntfs3` storage path;

### Not production-supported yet

- The persistent installer is experimental. CI qualifies ephemeral BIOS and UEFI disks; real UEFI/BIOS hardware still requires a hardware report and destructive-device review.
- There is no installed-ISO upgrade or filesystem rollback procedure.
- The current image is not a production desktop or gaming release.
- Do not repartition or format an internal disk based only on this guide.

For production installation, wait for a release with physical hardware support,
filesystem recovery and an installed-ISO upgrade procedure. Published alpha releases
may expose a signed DINX pacman repository and package transaction path, but that
does not make the installer or filesystem recovery production-ready. The selected
installer path and remaining gates are tracked in the [architecture decision](architecture.md).

## Troubleshooting

### The USB does not appear

Verify that the checksum passed, the image was written to the whole device, the firmware is in UEFI mode and the USB is visible in `lsblk`/`diskutil`. Try another port or drive.

### The boot stalls with `No irq handler for vector`

Old legacy-BIOS chipsets (AMD E-350 "Zacate" and similar pre-2012 notebooks, such as the HP dm1) can stop early at `do_IRQ: 1.55 No irq handler for vector`. The GRUB menu itself booted through the hybrid MBR; the kernel needs the legacy interrupt workaround. Reboot and choose `Start DINX Linux (compatibility)`, which adds `noapic irqpoll`. If a black screen follows, see below. The text-mode recovery TTY (`Ctrl+Alt+F2`/`F3`) remains available if the frame buffer still fails.

### Black screen even after choosing `Start DINX Linux (compatibility)`

When the screen stays black after `noapic irqpoll` fixes the interrupt stall, the GPU modeset or the Plymouth splash is the remaining suspect (common on pre-2012 integrated graphics such as the Radeon HD 6310 in the HP dm1). Boot order:

1. `Start DINX Linux (verbose boot)` — prints the full kernel console instead of a splash, showing exactly where boot stops. Note the last lines.
2. `Start DINX Linux (safe graphics)` — adds `nomodeset plymouth.enable=0` and runs the session in text mode, bypassing the modeset hang.
3. If (2) works, keep it: after installing, set the same parameters permanently with `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash noapic irqpoll nomodeset plymouth.enable=0"` in `/etc/default/grub`, then `pkexec grub-mkconfig -o /boot/grub/grub.cfg`.

### The screen is blank

`dinx-graphics-profile` selects a graphics profile from each accessible DRM render node's own sysfs driver, not DRM card order, and `dinx-river-session` applies it through `dinx_apply_graphics_environment`. QEMU `virtio_gpu`/virgl selects `virtual-gl` (`WLR_RENDERER=gles2`) when its render node is readable and writable. VirtualBox VMSVGA (`vmwgfx`) and legacy `vboxvideo` select `cpu` (`WLR_RENDERER=pixman`) when an accessible render node identifies them, because VirtualBox's llvmpipe Vulkan device can fail DRM-device matching. Systems without an accessible render node, including QEMU default VGA with `bochs-drm`, select `cpu` (`WLR_RENDERER=pixman`); QXL and other 2D render nodes (`qxl`, `bochs`, `simpledrm`, `cirrus`) also select `cpu`. Any other driver keeps the `hardware` profile with no compositor override. `GSK_RENDERER` remains unset so GTK4 chooses its renderer automatically.

The supplied VirtualBox 7.2.22/Windows 11 log reports VT-x unavailable and Hyper-V NEM “Snail execution mode”; this is a slower execution path, not a guest graphics result. It does not prove whether the desktop appeared or why the VM stopped, and lists an Alpha 12 ISO plus a VDI named Alpha 0.10 without a verified ISO checksum or confirmed boot source. Treat it as unqualified; repeat with a fresh VM, exact ISO SHA-512 and no stale VDI attached during live boot.


### Graphics, drivers and media

DINX ships Mesa/RADV for hardware, Lavapipe for CPU Vulkan applications, Vulkan diagnostics, FFmpeg and Haruna (Qt/QML on libmpv) for the supported open-source media path. If other hardware acceleration or a proprietary GPU driver is missing, open **DINXPanel → GPU drivers**, run detection, review the fixed Artix package plan, and reboot when it reports that a kernel or driver change requires it. DINX does not silently install proprietary drivers or claim unsupported hardware is working. Attach `dinx-alpha7-hardware-report` output when reporting blank video, rendering fallback or game-launch failures.

For QEMU virgl, use a host QEMU build with GTK/OpenGL and virgl support, then request `virtio-vga-gl`, for example:

```sh
DINX_QEMU_DISPLAY=gtk,gl=on \
DINX_QEMU_VIDEO_DEVICE=virtio-vga-gl \
scripts/smoke-iso.sh /path/to/dinx.iso
```

For VirtualBox, qualify the exact SHA-512-verified rebuilt ISO in a fresh disposable VM. Use VMSVGA and test 3D acceleration disabled and enabled as separate cases. The current source selects the `vulkan` profile with `WLR_RENDERER=vulkan` for `vmwgfx`/`vboxvideo` and no-render-node systems; this differs from Alpha 12's published ISO. Record firmware and VM settings, confirm live boot reaches the River/KWM desktop, and save the VBox log and screen captures. Do not attach an older system VDI during the live-media test. For installer testing, use a new disposable virtual disk, eject the ISO after installation, then boot that disk and record the installed-session result. QEMU Virtio-VGA is a separate graphics smoke, not a VirtualBox pass. Hyper-V/NEM can make VirtualBox very slow; do not disable Memory Integrity or other host security protections to improve benchmark speed.

For real hardware, use the device matrix and report procedure in [DINX hardware qualification](alpha7-qualification.md). Verify the exact ISO checksum and record machine role, firmware, GPU and each observed result; use a disposable external disk for installation tests. CI/QEMU and VirtualBox evidence do not substitute for the physical display, input, audio, networking, suspend/resume, brightness and GPU checks.

DINX also ships `fwupdmgr`
for explicit firmware metadata and update discovery, Flatpak for user-selected
application sources, and PaintFE as the image editor, alongside Krita, Inkscape,
Pixelorama and Patchy. PaintFE is a checksum-pinned upstream AppImage repacked
into a pre-extracted `/opt/paintfe/` tree, so it needs no FUSE. Audionaut, the
multitrack audio editor and recorder, ships as a single AppImage run with
`--appimage-extract-and-run`, and Blender is the 3D creation suite. Swayimg
remains the default image viewer.

### Optional gaming stack

The Alpha 12 generic ISO excludes Gamescope, Steam, GameMode, MangoHud, Steam device rules and 32-bit gaming libraries. The base retains 64-bit RADV and Vulkan diagnostics; users can opt into the gaming stack after installation:

1. In `/etc/pacman.conf`, add the official Artix repository only if `[lib32]` is not already defined:

   ```ini
   [lib32]
   Include = /etc/pacman.d/mirrorlist
   ```

2. Install the optional gaming packages:

   ```bash
   pkexec pacman -Syu --needed \
     gamescope gamemode mangohud steam steam-devices \
     lib32-gamemode lib32-mesa lib32-vulkan-radeon lib32-vulkan-mesa-layers
   ```

No Arch repository is needed. The DINX Gaming entry remains hidden from the greeter; its launcher reports missing Gamescope or Steam before changing the Dinit profile. Real DRM gaming, authenticated Steam, commercial games, controller input and game audio remain unqualified.

Flatpak is installed without preinstalled Flatpak applications. Adding a remote
and installing an app remain explicit user actions; DINX does not silently
install application remotes or apps.

For optional printing after installation, open **DINXPanel → Optional packages
→ Install CUPS**. The action downloads the signed `cups-dinit` package from
the configured Artix repository; its dependency downloads CUPS and the
package provides the `cupsd` dinit service. Use DinitUI to enable or start
`cupsd` when printing is needed. CUPS is intentionally not part of the
offline ISO payload.

### The live session does not open

The expected path is direct autologin into `dinx`/`River + KWM (DINX)`. If the agreety login screen appears instead of the live autologin, it must offer only `River + KWM (DINX)`; capture the workflow commit and hardware details if the session does not start. Do not try random credentials.

### The checksum fails

Do not boot or write the file. Remove the partial artifact and download the ISO and `.sha512` file from the same workflow run again.

## Reporting hardware results

Include these details in an issue or hardware report:

```bash
uname -a
lspci -nnk
lsusb
```

Also include the DINX workflow commit, firmware mode (UEFI/legacy), GPU, Wi-Fi/audio hardware, whether the checksum passed, and the exact failure stage. Remove serial numbers, usernames, network addresses and private logs before publishing.
