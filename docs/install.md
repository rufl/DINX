# DINX easy install

[English](install.md) · [Português (Brasil)](pt-BR/install.md)

## Current alpha status

The current DINX image is a **live validation ISO**, not a supported disk installer. This guide covers the safe path to download, verify, write and boot the live system. It does not promise persistent installation, upgrades or data preservation.

Do not use the ISO on a machine containing data that you cannot restore. The live session is disposable and changes are lost on reboot.

## Requirements

- x86_64 computer or virtual machine;
- UEFI firmware is recommended;
- a USB drive of at least 4 GB; writing the image erases the whole drive;
- at least 4 GB RAM recommended for hardware testing. The CI smoke test uses 2 GB, but that is not a supported hardware minimum;
- a second device or existing system from which to download and verify the image;
- a backup of every disk that could be selected accidentally.

The current alpha has no signed bootloader, no supported Secure Boot path and no final GPU/hardware compatibility matrix. A machine may boot successfully while still having unsupported graphics, Wi-Fi, audio or suspend behavior.

## 1. Obtain the ISO artifact

There is not yet a stable release download. The public workflow artifact is retained for seven days and is replaced by later runs.

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

## 5. What this alpha can and cannot do

### Supported by the current smoke evidence

- x86_64 boot path in QEMU;
- ReGreet rendering;
- graphical login into the MangoWM session;
- Noctalia startup;
- presence of the expected dinit, network, PipeWire and portal payloads in the ISO.

### Not a supported installation yet

- There is no supported disk installer in this image.
- There is no persistence across reboot.
- There is no upgrade or rollback procedure.
- The current image is not a production desktop or gaming release.
- Do not repartition or format an internal disk based only on this guide.

For persistent installation, wait for a documented installer path and a release with package signing, hardware support, recovery and upgrade procedures. The open item is tracked in the [roadmap](roadmap.md).

## Troubleshooting

### The USB does not appear

Verify that the checksum passed, the image was written to the whole device, the firmware is in UEFI mode and the USB is visible in `lsblk`/`diskutil`. Try another port or drive.

### The screen is blank

The software-rendering fallback is designed for the headless QEMU path. Hardware graphics support is not yet fully qualified. Record the GPU model, firmware mode and kernel/guest behavior before filing a report.

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
