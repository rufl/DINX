# DINX easy install

[English](install.md) · [Português (Brasil)](pt-BR/install.md)

## Current alpha status

The current DINX image is a **live validation ISO with an experimental disk installer**. Calamares installs from the ISO root filesystem without requiring a network connection; it creates the user, configures dinit and GRUB, and removes the live-only packages. This guide covers the safe download, verification, boot and experimental installation paths. It does not promise production hardware support, installed-ISO upgrades, filesystem rollback or data preservation.

The published release is the **Alpha 10 system alpha**, not a gaming beta: [v0.1.0-alpha.10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10), published by tagged workflow [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) from commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e`. Its direct ISO is 1,862,772,736 bytes with SHA-512 `5f49a65eac1481c01555a8f44b049c9a06e75ec7270ac3cdef97cc5e0b051d4b3c48a200542a36ec1832700accbc5509e3c314726c2f747530095eba4112219a`. Beta 0.1 is a planned, undated system-qualification milestone; see the [roadmap](roadmap.md).
The earlier livefs payload and first-boot marker gaps are fixed. Post-release main P0 run [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770) on commit `bf773500965c843e014e3bc3ef8fea685e14b91b` passed the full build, graphical, BIOS/UEFI persistent-install and recovery-TTY gates. This separate main validation did not change the tagged Alpha 10 release artifact.

Pori is the dinit storage tool. Use it to inspect disks and create persistent mount services under `/etc/dinit.d`; use File Roller to open, create and extract archives, GParted to edit partitions outside the installer, and Calamares for the final partitioning and installation transaction.

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

The published Alpha 10 system alpha has a direct ISO and matching checksum in its [tagged release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10). Use that release as the primary download. P0 workflow artifacts are temporary fallbacks retained for seven days and replaced by later runs.

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
5. The published Alpha 10 image starts directly in `Aqueous + Pearl (DINX)`; no live username or password prompt is required.

The live ISO opens the disposable `dinx` account directly in `Aqueous + Pearl (DINX)`. This is live-only; installed login and Calamares autologin remain disabled. Anyone who can boot the ISO already controls the live machine; never reuse the public `dinx` password elsewhere.

Once the desktop appears, the tested graphical state is Aqueous/Pearl. Network, audio, GPU acceleration, suspend/resume and recovery TTY remain hardware-dependent validation areas.
Pearl is the active shell. The static DINX theme is applied through the checked-in GTK/Qt bridges; Pearl Greeter reads `/etc/pearl/greeter.json`, uses the GTK DINX theme and forces the Aqueous/Pearl entry without X11 or UWSM.
Phyto is the default directory handler and file manager. File Roller provides graphical actions to open, create and extract archives. GParted edits partitions outside the installation flow. Pori is the storage surface for inspecting disks and creating persistent mount services; it uses UDisks2 for discovery and dinit for service lifecycle. The base ISO includes DINX's `dinx-wdisplays` wrapper for interactive Wayland output configuration; closing it saves the current layout as the `DINX wdisplays` profile and reloads Shikane, which starts inside Aqueous/Pearl and reapplies matching profiles. `Dome`, `Seafoam Settings` and `zls` are bundled in the signed base ISO. Dome provides dinit-safe resource/process monitoring without systemd integration; Seafoam Settings groups the documented display/session configuration entry points; Nocted uses the bundled ZLS for Zig projects.
The base ZLS runtime is compact by design: completion and navigation use the bundled matching `lib/std` tree through `/usr/lib/zls/zig-env`; a full Zig compiler is optional and is not part of the ISO payload.

### Optional BC-250 support

The Alpha 10 generic ISO excludes the BC250 Control Center and Cyan Skillfish governor. Their pinned packages are available in the signed DINX repository; install them only after confirming PCI ID `1002:13fe`. First configure and locally trust the signed repository as documented in [`release.md`](release.md):

```bash
if lspci -n -d 1002:13fe | grep -Fq '1002:13fe'; then
  sudo pacman -Syu --needed bc250-control-center cyan-skillfish-governor-smu-dinit
else
  printf 'PCI 1002:13fe not detected; BC-250 packages were not installed.\n' >&2
  exit 1
fi
```

The governor checks PCI `1002:13fe` before applying settings. The guard above prevents the install command from running on other hardware. Neither BC-250 package is preinstalled in the generic ISO.

## 5. Experimental persistent installation

From the live desktop:

1. Open the application launcher and choose **Instalar DINX**.
2. If the launcher entry is unavailable, run `pkexec calamares` from a terminal.
3. Read **Install choices / Opções de instalação** before choosing partitions.
4. Choose the layout that matches your intent:
   - **Erase disk** creates the layout automatically and erases all data on the selected disk. Choose it only if intended; verify the disk model and size.
   - **Install alongside** keeps another system when Calamares offers the option.
   - **Replace a partition** erases the selected partition. **Manual partitioning** is for advanced users; it requires `/` and, in UEFI, a FAT32 EFI partition mounted at `/boot/efi`.
5. Swap is optional. The default is no swap; DINX installs and boots without a swap partition.
6. Review the target disk, firmware mode, mount points and planned changes on the summary page before confirming.
7. For advanced storage operations, open **Pori** from the Pearl launcher. It discovers block devices through UDisks2 and persists user-selected mounts as dinit services under `/etc/dinit.d`; use **GParted** to edit partitions outside Calamares, **File Roller** to work with archives, `dinx-wdisplays` for interactive output setup and automatic Shikane profile persistence.
8. Keep the ISO/USB connected until the installer finishes. The first profile supports ext4 and btrfs; the installer copies its root filesystem offline.

Calamares and GParted can erase, format or resize data. Pori mount actions do not format disks, but verify the device, filesystem and mount target before confirming any privileged action. The final confirmation is not a safety net for selecting the wrong disk. Back up the machine and verify the model, size and serial information of the target device.
The Alpha 10 Calamares qualification covers a Windows-style GPT layout: an existing FAT32 ESP containing `EFI/Microsoft`, an NTFS Windows partition and DINX root space created after it. The smoke preserves the Windows partition and Microsoft boot path while writing DINX fstab and GRUB data for both a side-by-side outcome and an explicit manual layout. The live ISO and installed base use the kernel `ntfs3` driver for NTFS read/write; legacy `ntfs-3g` is optional after installation for compatibility and repair tools. The profile includes `os-prober`, enables GRUB's Windows detection and uses a separate `DINX` EFI directory. An existing ESP of at least 64 MiB is accepted because DINX keeps `/boot` on the root filesystem; a new ESP is recommended at 1 GiB. If the existing ESP is smaller or full, create a new FAT32 ESP in free space through the manual layout instead of formatting the Microsoft ESP. Do not format the existing ESP or Windows/MSR/recovery partitions. Boot DINX in the same UEFI mode as Windows, fully shut Windows down, disable Fast Startup/hibernation, suspend BitLocker with its recovery key available, and leave a verified backup before attempting a resize.
### First boot and recovery TTY

The CI installation contract boots the copied root filesystem from disposable BIOS and UEFI disks and enables `getty@tty2` and `getty@tty3` for recovery. These are QEMU disk smokes, not physical hardware qualification. On a real installation, press `Ctrl+Alt+F2` or `Ctrl+Alt+F3` at the installed system's greeter to open a TTY and log in with the user created during installation. Useful recovery commands:

```bash
dinitctl status greetd
dinitctl restart greetd
```

If the graphical session is unavailable, use the independent Wayland fallback:

```bash
DINX_TERMINAL_FALLBACK=1 dinx-terminal
```

`$TERMINAL` points to `dinx-terminal`, which prefers NOCTTY and falls back to `foot` when NOCTTY is not installed. The only user compositor session is Aqueous/Pearl; the dedicated Pearl Greeter host is a greetd login surface, not a user-session configuration.
To record the system state without changing it, run:

```bash
dinx-doctor
```

The report uses the `dinx-doctor/v1` schema and marks unavailable capabilities as `missing` or `unknown`. To include a read-only list of user dinit services, run `DINX_DOCTOR_QUERY_DINIT=1 dinx-doctor`. Do not treat the report as proof of hardware compatibility: physical brightness, suspend, GPU, audio, shared NTFS and volume mounting still require testing on the machine.



## 6. What this alpha can and cannot do

### Supported by the current smoke evidence

- x86_64 boot path in QEMU;
- Pearl Greeter payload and greetd configuration;
- graphical login into the Aqueous/Pearl session;
- Pearl startup;
- presence of the expected dinit, network, PipeWire and portal payloads in the ISO;
- Windows-style GPT side-by-side and manual-layout transaction smoke: existing FAT32 ESP/Microsoft boot files and NTFS partition remain intact while DINX root, fstab and GRUB data are added;
- presence of the Calamares offline-install configuration, Pori, Phyto and the kernel `ntfs3` storage path;

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

### The screen is blank

DINX includes Mesa Lavapipe (`vulkan-swrast`) for Vulkan applications. For the Aqueous/Pearl session in QEMU and on systems without a DRM render node, the wrapper uses `aqueous-cpu`, built without Vulkan effects, with Pixman and Cairo rendering. It also detects Virtio GPUs (`0x1af4`) when they expose a render node, avoiding the llvmpipe presentation failure. This slower path omits compositor Vulkan effects such as blur and rounded corners; other systems with a render node use the full compositor and retain normal driver selection. Hardware graphics support is not yet fully qualified. Record the GPU model, firmware mode and kernel/guest behavior before filing a report.

### Graphics, drivers and media

DINX ships Mesa/RADV for hardware, Lavapipe for CPU Vulkan applications, Vulkan diagnostics, FFmpeg and VLC for the supported open-source media path. The Aqueous/Pearl session uses Pixman/Cairo on Virtio GPUs and systems without a DRM render node; it does not select Lavapipe to render the desktop. If hardware acceleration or a proprietary GPU driver is missing, open **DINXPanel → GPU drivers**, run detection, review the fixed Artix package plan, and reboot when it reports that a kernel or driver change requires it. DINX does not silently install proprietary drivers or claim unsupported hardware is working. Attach `dinx-alpha7-hardware-report` output when reporting blank video, rendering fallback or game-launch failures.

DINX also ships SANE's `scanimage` backend for scanner access, `fwupdmgr`
for explicit firmware metadata and update discovery, Flatpak for user-selected
application sources, and KolourPaint as the simple Qt image editor. Swayimg
remains the default image viewer; KolourPaint is available from the launcher
and does not replace that viewer default.

### Optional gaming stack

The Alpha 10 generic ISO excludes Gamescope, Steam, GameMode, MangoHud, Steam device rules and 32-bit gaming libraries. The base retains 64-bit RADV and Vulkan diagnostics; users can opt into the gaming stack after installation:

1. In `/etc/pacman.conf`, add the official Artix repository only if `[lib32]` is not already defined:

   ```ini
   [lib32]
   Include = /etc/pacman.d/mirrorlist
   ```

2. Install the optional gaming packages:

   ```bash
   sudo pacman -Syu --needed \
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

The expected path is direct autologin into `dinx`/`Aqueous + Pearl (DINX)`. If Pearl Greeter appears, it should already show only the forced `Aqueous + Pearl (DINX)` entry; capture the workflow commit and hardware details if the session does not start. Do not try random credentials.

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
