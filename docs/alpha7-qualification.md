# DINX hardware qualification (Alpha 7 report contract)

The Alpha 7 report utility and environment names are retained for compatibility.
This matrix is the manual hardware boundary for the current `v0.1.0-alpha.9`
release; it separates repository evidence from manual hardware testing after the ISO is generated.

## Build gate

The tag commit must pass the P0 workflow and produce a fresh ISO, checksum,
build metadata, attestations, QEMU evidence, and release assets. The required
contracts cover:

- ISO SquashFS payload and startup budgets;
- QEMU boot and graphical capture;
- disposable BIOS and UEFI installation;
- recovery TTY and first boot;
- Btrfs transaction with existing `@` and `@home` subvolumes;
- Windows side-by-side NTFS and manual partition layouts;
- package, theme, DinitUI, DINXPanel, gaming, BC250, and first-party app checks.
- real DinitUI user-daemon and GTK qualification;
- bounded Calamares startup smoke with the shipped configuration, in addition to transaction smokes;

## Installed-system operator checklist

Run this checklist against the exact ISO and record the release tag, build
metadata filename, machine role, firmware mode and GPU before marking a result
as `pass`.

1. Verify the ISO SHA-512 and build metadata, then boot the normal DINX session.
2. After a Calamares install, confirm the first boot reaches Pearl Greeter and then the Aqueous/Pearl session; `dinitctl status greetd NetworkManager` must report the expected services.
3. Open **DINX Display Setup**, arrange the outputs, close it, and confirm the
   `DINX wdisplays` profile exists in
   `~/.config/shikane/config.toml`; log out and back in to confirm it reapplies.
4. On a disposable NTFS volume, mount it through Pori or UDisks2, create and
   remove a test file, unmount it, and mount it again. Do not use a Windows
   volume left hibernated or with Fast Startup enabled.
5. Use Phyto to browse the mounted volume, File Roller to create and extract an
   archive, and GParted only against a disposable disk.
6. Verify `Ctrl+Alt+F2` or `Ctrl+Alt+F3` opens the recovery TTY, then return to
   the graphical session.
7. Exercise lock, idle lock, suspend/resume, physical brightness, audio,
   networking and Bluetooth on the target hardware.
8. For gaming claims, authenticate Steam, launch and exit one commercial game,
   test a controller and verify PipeWire game audio.

CI/QEMU evidence does not replace steps 3–8 on physical hardware. Record
`fail` or `blocked` instead of inferring success from package presence.

## Three-machine manual matrix

Use the same ISO and record the exact machine, firmware mode, GPU, kernel, and
resulting report path for each target.

### Desktop

- boot the live session and verify that it opens directly in Aqueous + Pearl; if the Pearl Greeter fallback appears, verify that it exposes only the forced `Aqueous + Pearl (DINX)` entry and record the path;
- verify Wayland, Aqueous, Pearl, audio, network and GPU acceleration;
- if NVIDIA support is claimed, install `nvidia-open-dkms` with matching headers, reboot, and verify render-node, Vulkan and Gamescope output;
- lock with `Super+L`;
- verify idle lock at 600 seconds;
- suspend, resume, unlock and verify the session remains usable;
- test physical brightness controls;
- select `DINX Gaming`, launch Steam, launch and exit one installed game;
- test controller input and PipeWire game audio;
- run `dinx-alpha7-hardware-report` before and after gaming.

### Laptop

Repeat the desktop matrix, adding:

- battery and charging state;
- lid close/open behavior;
- brightness down/up across the supported range;
- suspend/resume on battery and AC;
- Wi-Fi, Bluetooth controller and audio routing after resume.

### BC-250

Repeat the desktop matrix, adding:

- `lspci -nn` detection of `1002:13fe`;
- Cyan Skillfish governor status and safe non-BC250 fallback behavior;
- RADV/Vulkan diagnostics;
- BC250 Control Center GUI and CLI startup;
- telemetry, recovery controls and GPU behavior after suspend/resume;
- one gaming run with frame pacing/temperature/power observations.

## Hardware report

The ISO includes a read-only report utility:

```bash
dinx-alpha7-hardware-report
```

Reports default to `$XDG_STATE_HOME/dinx/alpha7/` or
`~/.local/state/dinx/alpha7/`. Set `DINX_ALPHA7_REPORT_DIR` to choose another
local directory. The utility does not install packages, change profiles, change
GPU settings, or contact the network.

For a release-qualified report, provide the immutable build context and record
each manual result only after running the corresponding test:

```bash
export DINX_ALPHA7_MACHINE_ROLE=desktop   # desktop, laptop or bc250
export DINX_ALPHA7_FIRMWARE_MODE=uefi    # bios or uefi
export DINX_ALPHA7_RELEASE_TAG=v0.1.0-alpha.9
export DINX_ALPHA7_BUILD_COMMIT=0123456789012345678901234567890123456789
export DINX_ALPHA7_PACKAGE_REPOSITORY_SNAPSHOT=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
for result in \
  REAL_DRM_SESSION STEAM_AUTHENTICATION COMMERCIAL_GAME_LAUNCH \
  CONTROLLER_INPUT PIPEWIRE_GAME_AUDIO SUSPEND_RESUME \
  PHYSICAL_BRIGHTNESS GPU_RECOVERY UPDATE_PATH; do
  export "DINX_ALPHA7_RESULT_${result}=pass"
done
dinx-alpha7-hardware-report
report_path=$(find "${DINX_ALPHA7_REPORT_DIR:-$HOME/.local/state/dinx/alpha7}" \
  -type f -name 'alpha7-hardware-*.txt' -print | sort | awk 'END { print }')
build_metadata_path="$HOME/Downloads/dinx-build-metadata.txt"
scripts/check_dinx_hardware_evidence.sh "$report_path" "$build_metadata_path"
```

The validator requires the role, firmware mode, release tag, build commit,
package snapshot and every result to be present and `pass`. When the downloaded
release build metadata is supplied, it also verifies the report commit and package
snapshot against that file. Use `fail` or `blocked` for unsuccessful tests; do not
mark an observation manually as passed. `filesystem_rollback=unsupported` is
retained in every report.

## Evidence boundary

CI and QEMU do not prove real DRM ownership, authenticated Steam, commercial
game launch, controller input, PipeWire game audio, suspend/resume, physical
brightness, GPU recovery, firmware behavior, or long-running hardware health.
Those claims remain open until the three-machine manual matrix passes.

P5 gaming remains a separate beta gate. The `v0.1.0-alpha.9` release is a
system alpha; this document does not claim that the gaming beta exit criterion
has passed.
