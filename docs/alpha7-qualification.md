# DINX Alpha 7 qualification

Alpha 7 is the next DINX OS validation snapshot after `v0.1.0-alpha.6`.
This document separates what the repository can prove from what requires manual
hardware testing after the ISO is generated.

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

## Three-machine manual matrix

Use the same ISO and record the exact machine, firmware mode, GPU, kernel, and
resulting report path for each target.

### Desktop

- boot live session and select the normal DINX session in ReGreet;
- verify Wayland, MangoWC, Noctalia, audio, network and GPU acceleration;
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

## Evidence boundary

CI and QEMU do not prove real DRM ownership, authenticated Steam, commercial
game launch, controller input, PipeWire game audio, suspend/resume, physical
brightness, GPU recovery, firmware behavior, or long-running hardware health.
Those claims remain open until the three-machine manual matrix passes.

P5 gaming remains a separate beta gate. Alpha 7 may ship as a system alpha
without claiming that the gaming beta exit criterion has passed.
