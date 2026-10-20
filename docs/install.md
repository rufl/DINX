# DINX easy install

[English](install.md) · [Português (Brasil)](pt-BR/install.md)

## Current alpha status

The current DINX image is a **live validation ISO with an experimental disk installer**. Calamares installs from the ISO root filesystem without requiring a network connection; it creates the user, configures dinit and GRUB, and removes the live-only packages. This guide covers the safe download, verification, boot and experimental installation paths. It does not promise production hardware support, upgrades, rollback or data preservation.
The project is currently in **P5 — Gaming beta**. The latest successful P0 validation is [run 39292450368](https://github.com/rufl/DINX/actions/runs/39292450368), on commit `5def1fa`; it built and booted the ISO, validated the graphical payload, passed the Calamares supported-layout transaction smoke for BIOS, UEFI and existing Btrfs subvolumes, completed the disposable BIOS and UEFI persistent-install/first-boot/recovery-TTY smoke, verified build metadata and published an attested workflow artifact. The public prerelease is [v0.1.0-alpha.7](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.7), published from tag commit `2d75c88`. P4 DinitUI is release-qualified for the alpha gate; P5 still has real DRM, authenticated Steam/game, controller/audio and physical-hardware boundaries.

KDE Partition Manager is also available as a standalone graphical disk tool. Use it only to inspect or prepare a disk before opening Calamares, and verify the target device in both applications.

Do not use the ISO on a machine containing data that you cannot restore. The live session and the installer are alpha software.

## Requirements

- x86_64 computer or virtual machine;
- UEFI firmware is recommended;
- a USB drive of at least 4 GB; writing the image erases the whole drive;
- at least 4 GB RAM recommended for hardware testing. The CI smoke test uses 2 GB, but that is not a supported hardware minimum;
- a second device or existing system from which to download and verify the image;
- a backup of every disk that could be selected accidentally.

The current alpha has no signed bootloader, no supported Secure Boot path and no final GPU/hardware compatibility matrix. A machine may boot successfully while still having unsupported graphics, Wi-Fi, audio or suspend behavior.

## 1. Obtain the ISO artifact

There is no supported stable release yet. Tagged alpha releases publish a verified ISO and matching checksums; the workflow artifact remains available for seven days as a fallback.

### Tagged alpha release

1. Open the [DINX releases](https://github.com/rufl/DINX/releases).
2. Select the latest pre-release.
3. Download `dinx-<version>-x86_64.iso` and its matching `.iso.sha512`. If the direct ISO is absent, download every `dinx-<version>-x86_64.iso.part-*` file and `.iso.parts.json`.
4. For a split ISO, concatenate the parts in lexical order:

   ```bash
   cat dinx-<version>-x86_64.iso.part-* > dinx-<version>-x86_64.iso
   ```

5. Continue with checksum verification below.

The [release guide](release.md) documents the Windows QEMU launcher and ZTASH deployment path.

### Browser

1. Open the [P0 ISO workflow](https://github.com/rufl/DINX/actions/workflows/p0-iso.yml).
2. Open the newest run with a green success mark.
3. In **Artifacts**, download `dinx-foundation-iso-<commit>`.
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
  --name "dinx-foundation-iso-$commit" \
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
3. Select the UEFI entry for the USB.
4. If the firmware refuses the image, disable Secure Boot for this test; the current alpha does not provide a signed Secure Boot path.
5. Wait for the DINX greeter.

The tested live login is:

- **User:** `dinx`
- **Password:** `dinx`
- **Session:** `MangoWM (DINX)`

The password is intentionally public and disposable. Never reuse it on another system or network.

After login, the tested graphical state shows MangoWM with the Noctalia welcome screen. Network, audio, GPU acceleration, suspend/resume and recovery TTY remain hardware-dependent validation areas.
Noctalia starts with animations, panel translucency and Settings-window translucency disabled. These are user preferences, not locks: change them later in Noctalia Settings. Mango starts with two virtual desktops; edit `~/.config/mango/config.conf` and change `tag_num` if more are needed.

### BC250 Control Center

After entering MangoWM, open **BC250 Control Center** from the Noctalia launcher or dock. DINX starts `bc250-control-centerd` once in the logged-in user session, so the daemon does not require a systemd unit or a root dinit service. It provides BC-250 telemetry and the upstream polkit-gated controls when the hardware and permissions are available. On dinit, upstream service persistence is detection-only; that limitation does not block the GUI or live readings.

## 5. Experimental persistent installation

After logging into MangoWM:

1. Open the application launcher and choose **Instalar DINX**.
2. If the launcher entry is unavailable, run `pkexec calamares` from a terminal.
3. Choose automatic or manual partitioning and verify the target disk, firmware mode and mount points before continuing.
4. For advanced preparation, close Calamares, open **KDE Partition Manager**, make and apply the required changes, close it, then reopen Calamares.
5. Keep the ISO/USB connected until the installer finishes. The first profile supports ext4 and btrfs; the installer copies its root filesystem offline.

Both Calamares and KDE Partition Manager can erase or format data. The final confirmation is not a safety net for selecting the wrong disk. Back up the machine and verify the model, size and serial information of the target device.
The alpha.7 Calamares qualification also covers a Windows-style GPT layout: an existing FAT32 ESP containing `EFI/Microsoft`, an NTFS Windows partition and DINX root space created after it. The smoke preserves the Windows partition and Microsoft boot path while writing DINX fstab and GRUB data for both a side-by-side outcome and an explicit manual layout. The ISO includes `ntfs-3g` and `os-prober`, enables GRUB's Windows detection and uses a separate `DINX` EFI directory. An existing ESP of at least 64 MiB is accepted because DINX keeps `/boot` on the root filesystem; a new ESP is recommended at 1 GiB. If the existing ESP is smaller or full, create a new FAT32 ESP in free space through the manual layout instead of formatting the Microsoft ESP. Do not format the existing ESP or Windows/MSR/recovery partitions. Boot DINX in the same UEFI mode as Windows, fully shut Windows down, disable Fast Startup/hibernation, suspend BitLocker with its recovery key available, and leave a verified backup before attempting a resize.
### First boot and recovery TTY

The CI installation contract boots the copied root filesystem from disposable BIOS and UEFI disks and enables `getty@tty2` and `getty@tty3` for recovery. These are QEMU disk smokes, not physical hardware qualification. On a real installation, press `Ctrl+Alt+F2` or `Ctrl+Alt+F3` at the greeter to open a TTY and log in with the user created during installation. Useful recovery commands:

```bash
dinitctl status greetd
dinitctl restart greetd
```

If the graphical session is unavailable, use the independent Wayland fallback:

```bash
DINX_TERMINAL_FALLBACK=1 dinx-terminal
```

`Super+Enter` also launches `foot` directly in the Mango session. `$TERMINAL` points
to `dinx-terminal`, which prefers NOCTTY and falls back to `foot` when NOCTTY is not
installed.


## 6. What this alpha can and cannot do

### Supported by the current smoke evidence

- x86_64 boot path in QEMU;
- ReGreet rendering;
- graphical login into the MangoWM session;
- Noctalia startup;
- presence of the expected dinit, network, PipeWire and portal payloads in the ISO;
- Windows-style GPT side-by-side and manual-layout transaction smoke: existing FAT32 ESP/Microsoft boot files and NTFS partition remain intact while DINX root, fstab and GRUB data are added;
- presence of the Calamares offline-install configuration and standalone KDE Partition Manager.

### Not production-supported yet

- The persistent installer is experimental. CI qualifies ephemeral BIOS and UEFI disks; real UEFI/BIOS hardware still requires a hardware report and destructive-device review.
- There is no upgrade or rollback procedure.
- The current image is not a production desktop or gaming release.
- Do not repartition or format an internal disk based only on this guide.

For production installation, wait for a release with a pacman repository signing key,
hardware support, recovery and upgrade procedures. The selected installer path and
remaining gates are tracked in the [architecture decision](architecture.md).

## Troubleshooting

### The USB does not appear

Verify that the checksum passed, the image was written to the whole device, the firmware is in UEFI mode and the USB is visible in `lsblk`/`diskutil`. Try another port or drive.

### The screen is blank

The software-rendering fallback is designed for the headless QEMU path. Hardware graphics support is not yet fully qualified. Record the GPU model, firmware mode and kernel/guest behavior before filing a report.

### Graphics, drivers and media

DINX ships Mesa/RADV, Vulkan diagnostics, FFmpeg and VLC for the supported
open-source media path. If hardware acceleration or a proprietary GPU driver is
missing, open **DINXPanel → GPU drivers**, run detection, review the fixed Artix
package plan, and reboot when it reports that a kernel or driver change requires
it. DINX does not silently install proprietary drivers or claim unsupported
hardware is working. Attach `dinx-alpha7-hardware-report` output when reporting
blank video, rendering fallback or game-launch failures.

DINX also ships SANE's `scanimage` backend for scanner access, `fwupdmgr`
for explicit firmware metadata and update discovery, Flatpak for user-selected
application sources, and KolourPaint as the simple Qt image editor. Swayimg
remains the default image viewer; KolourPaint is available from the launcher
and does not replace that viewer default.

Flatpak is installed without preinstalled Flatpak applications. Adding a remote
and installing an app remain explicit user actions; DINX does not silently
install application remotes or apps.

For optional printing after installation, open **DINXPanel → Optional packages
→ Install CUPS**. The action downloads the signed `cups-dinit` package from
the configured Artix repository; its dependency downloads CUPS and the
package provides the `cupsd` dinit service. Use DinitUI to enable or start
`cupsd` when printing is needed. CUPS is intentionally not part of the
offline ISO payload.

### Login fails

Select user `dinx`, session `MangoWM (DINX)`, and enter the exact disposable password `dinx`. If the greeter still fails, retain the workflow commit and hardware details; do not try random credentials.

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
