# P0 build status

[English](p0-build.md) · [Português (Brasil)](pt-BR/p0-build.md)

## Selected implementation

DINX uses Artix's current `artools`/`buildiso` flow with a repository-local `profile.yaml` under `distro/iso/iso-profiles/dinx`. This keeps dinit service package selection in the Artix-supported path and avoids inventing a second ISO builder.

The entry points are:

- `scripts/check-iso-host.sh` — prerequisite probe;
- `scripts/build-iso.sh` — root-aware build wrapper;
- `scripts/prepare_first_party_apps.sh` — deterministic archive generator for the pinned NOCTTY/NoctEd source;
- `scripts/check_first_party_apps.sh` — first-party source, package and profile contract check;
- `scripts/check_firefox.sh`, `scripts/check_swayimg.sh`, `scripts/check_package_managers.sh`, `scripts/check_firewall_tools.sh`, `scripts/check_cyan_skillfish.sh` and `scripts/check_bc250_control_center.sh` — Firefox, pinned application, Artix package-management, firewall, hardware and BC250 Control Center contracts;
- `scripts/check_dinx_theme.sh` — DINX palette, application-template and greeter/installer/GRUB bridge contract;
- `scripts/check_dinitui.sh` — DinitUI package, action and privilege-boundary contract;
- `scripts/check_gaming.sh` — standalone Gamescope/Steam session, 32-bit graphics and ISO payload contract;
- `scripts/gaming_p5_qualification.sh` — fixture session return and real headless Gamescope launch/exit qualification;
- `scripts/noctty_p2_qualification.sh` — deterministic ReleaseSafe P2 matrix for allocator/fairness, PTY/session continuity, ncurses and system TUIs;
- `scripts/nocted_p3_qualification.sh` — deterministic P3 matrix for Nocted core/index/workers/state/tasks, real `clangd`, native GTK/X11 dark/light smoke and Git status/diff;
- `scripts/smoke-iso.sh` — QEMU boot probe;
- `scripts/smoke-install.sh` — disposable-disk persistent-install and recovery-TTY smoke;
- `.github/workflows/p0-iso.yml` — remote build in an Artix container;
- `.github/workflows/release.yml` — tagged pre-release publication and Windows QEMU package assembly;
- `distro/packages/noctty/PKGBUILD` — native Zig package that installs NOCTTY and NoctEd;
- `distro/packages/noctty/qualification-compat.patch` — packaging patch that wires the pinned source's PTY qualification target to its existing compatibility module and adds the Nocted P3 Git/theme/package contract;
- `distro/packages/wlroots0.20/PKGBUILD` — wlroots 0.20.2 source build pinned for the current Mango/Scenefx ABI;
- `distro/packages/dinitui/PKGBUILD` — native Zig 0.17 GTK4/libadwaita Dinit frontend;
- `distro/iso/iso-profiles/dinx/profile.yaml` — foundation package and service profile.

## Remote build

The `P0 ISO foundation` workflow runs manually or when profile/build files change. It:

1. checks out DINX;
2. verifies the committed NOCTTY/NoctEd source archive against `distro/packages/noctty/source.env` and validates the package/profile contract;
3. installs QEMU and ISO inspection tools on the Ubuntu runner;
4. runs Artix in a privileged container;
5. installs `artools`, `iso-profiles`, Rust, gettext, go-md2man, Zig 0.17.0, `clang`/`clangd`, Xvfb, VTE 2.91 (`vte3`) for the headless Noctty smoke binary, Ghostty's `libghostty-vt.so` runtime, and the pinned MangoWM/Scenefx build dependencies;
6. builds the pinned Artix package payload for topgrade, paru and Shelly, the BC250 Control Center v1.21.1 source release, the Cyan Skillfish governor and its dinit integration; then builds the native `noctty` package, which contains both NOCTTY and NoctEd, wlroots 0.20.2, MangoWM and Scenefx from the temporary local pacman repository, and executes the pinned source's headless PTY/VT/terminal-session smoke markers, the allocator-accounted terminal-session qualification (four normal and one forced cycle), the protocol/Unicode compatibility qualification, `scripts/noctty_p2_qualification.sh` and `scripts/nocted_p3_qualification.sh` in ReleaseSafe. The P3 matrix proves the native editor path in both packaged schemes, a real `clangd` symbol response, and bounded Git status/diff markers. That matrix uses actual tmux plus a deterministic Zellij shim, real Nano/Less/Dialog and top/watch/whiptail/fzf/SQLite/Glances/Bash/man/local SFTP checks, and the Nocted project/editor qualification;
7. runs the prerequisite probe;
8. builds the ISO with `buildiso`;
9. validates the root and live-session SquashFS payloads;
10. generates a SHA-512 checksum;
11. keeps QEMU running for a configurable boot window and captures its VGA surface;
12. boots a disposable BIOS disk produced from the same offline rootfs/Calamares package-removal contract, generates initramfs and GRUB, then checks a dinit first-boot marker and recovery-TTY service;
13. creates GitHub artifact attestations for the ISO and checksum;
14. publishes the ISO, checksum, QEMU logs and PPM captures as a temporary workflow artifact.

DinitUI is built from `distro/packages/dinitui` with Zig 0.17.0 against GTK4/libadwaita, added to the temporary pacman repository, and installed through the DINX profile. `scripts/check_dinitui.sh` validates the package metadata, desktop entry, complete dinitctl action catalog, argv-only execution and restricted `pkexec` fallback before the container build.
`scripts/dinitui_dinit_qualification.sh` drives a temporary real Dinit user daemon, validates `list`/`status`/`stop`, and runs the production DinitUI GTK smoke against that socket. It requires Dinit binaries and `xvfb-run`; it is intentionally separate from the privileged ISO container gate.
The gaming profile adds `gamescope`, `steam`, `steam-devices`, `lib32-mesa`, `lib32-vulkan-radeon` and `lib32-vulkan-mesa-layers`. The standalone `dinx-gaming` launcher is exposed as a Wayland session and uses the native Gamescope DRM backend; Steam's 32-bit dependencies are pulled through the package metadata. `scripts/check_gaming.sh` runs before the container build, while `scripts/gaming_p5_qualification.sh` is the local/runtime gate. Its fixture path does not authenticate Steam or claim a commercial game, controller/audio hardware, DRM output or suspend/resume.
### Local P4/P5 qualification

The local gates currently pass the DinitUI package contract, a real temporary user-Dinit daemon plus GTK smoke, and the gaming session fixture plus headless Gamescope launch/exit. These results do not replace the remote ISO workflow: ISO generation, QEMU boot, ISO payload inspection and persistent-install evidence remain release-gate outputs.

The payload check proves that MangoWM, Scenefx, Noctalia, ReGreet, greetd, the Mango session, the standalone gaming launcher/session, Gamescope, Steam, the 32-bit graphics payload, dinit service files, NOCTTY/NoctEd, `clangd`, both Nocted editor schemes, Nano, File Roller and the Thunar/GVFS stack reached the ISO. The removable-media contract includes UDisks2, `gvfs-mtp`, `gvfs-smb`, `gvfs-gphoto2`, `thunar-archive-plugin`, File Roller and Tumbler. It also asserts the standalone PolicyKit agent, rejects the systemd init package metadata/runtime while allowing compatibility libraries required by Gamescope/Steam, and rejects full Xfce/LXQt sessions. The QEMU smoke test still proves only process-level boot acceptance; it does not prove graphical login, networking, MTP, SMB, camera access or audio inside the guest.
The payload check also proves Firefox, its desktop entry, the default HTML/XHTML/HTTP/HTTPS handlers and `/etc/firefox/policies/policies.json`. That policy removes sponsored browser surfaces, Pocket/Stories, Firefox Studies and telemetry, browser recommendations, AI assistant/link-preview/tab-group surfaces and built-in IP Protection without disabling normal browser updates or user-initiated Firefox Accounts.
The same contract proves the expanded desktop payload: btop/nvtop/inxi, PCI/USB diagnostics, Git/curl/less/jq/rsync, Zathura with MuPDF, Swayimg, VLC with its Qt GUI/CLI split, Strawberry, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor` and `wl-clipboard`. It also verifies the Mango floating default, the top `main` bar, the bottom Noctalia dock, the Noctalia screenshot/clipboard widgets and the VLC/Strawberry MIME handlers. Noctalia remains the primary screenshot path; transitive Artix package dependencies may also provide `grim`/`slurp`.
The package-management contract also proves `topgrade`, `paru`, and Shelly. Topgrade uses a pinned upstream release binary with DINX's Artix pacman configuration; paru is built from its pinned source release against Artix ALPM; Shelly delegates to Artix's `pacman` configuration. Their package metadata contains no `systemd` dependency or unit, no Arch repository is added, and all AUR recipes remain subject to explicit user review. They remain user-invoked; the ISO does not auto-run package upgrades.
The hardware contract proves AMDGPU firmware, Mesa RADV, Vulkan diagnostics and the pinned Cyan Skillfish SMU governor. A dinit service is linked for both the live and installed profiles, detects PCI `1002:13fe` (BC-250), then starts the governor with a conservative 1000-1850 MHz range; on other hardware it exits without changing anything. Use an Artix kernel with current BC-250 fixes (6.17.11 or newer). No systemd service is installed.
The BC250 Control Center package is pinned to the upstream v1.21.1 MIT source release. It installs the GUI, CLI, polkit policy and headless daemon with Python 3.12+ / PyQt6 runtime dependencies. DINX removes the upstream systemd user unit and Cyan systemd drop-in; Mango starts `bc250-control-centerd` in the logged-in user session through `exec_once`, so the package adds no systemd service or dinit root service. The upstream dinit detection remains read-only for service persistence, while live BC-250 telemetry and the graphical controls remain available subject to their polkit and hardware prerequisites.
The same ISO contract proves UFW, Gufw, Qps, OpenSnitch and the `ufw`/`opensnitchd` dinit service files. It asserts the safe default (`ENABLED=no` and no boot links for either firewall service), so network policy changes require explicit user configuration.
The workflow also captures the QEMU VGA surface as a PPM artifact through the monitor. That capture is visual evidence to inspect; it does not automatically prove successful greeter interaction, user-session health, networking or audio.

Tagged releases reuse the same build artifact through `.github/workflows/release.yml`. The release job publishes either the ISO or ordered sub-2 GiB ISO parts, the full SHA-512, the Linux QEMU evidence and a small Windows launcher package. The launcher downloads the metadata-pinned HTTPS URL and, when required, each ordered part, verifies the parts and full SHA-512, then runs `scripts/smoke-iso.ps1` with QEMU on Windows. Its ZTASH metadata targets the registered `ddjarin` receiver without embedding credentials.

The live overlay also replaces the generic `root-ro` dinit service with a no-op: the live root is an overlay and cannot be remounted read-only. This is an ISO-only live-session adjustment, not an installed-system policy.

The Mango wrapper enables `WLR_RENDERER_ALLOW_SOFTWARE=1` only when `/dev/dri/renderD*` is absent, so the headless QEMU path does not mask a real DRM render node.

The profile owns the DINX visual contract at `root-overlay/etc/skel/.config/noctalia/palettes/DINX.json`. `scripts/check_dinx_theme.sh` validates both palette variants, Noctalia templates, GTK/Qt/Mango adapters, ReGreet, Calamares and GRUB before `buildiso`; `scripts/check-iso-content.sh` verifies the same files inside the root SquashFS image.
The profile also owns the Artix GRUB theme configuration at `root-overlay/usr/share/grub/themes/artix/theme.txt`. It keeps the upstream logo, icons and font assets, uses the DINX surface/text/primary colors, and omits the opaque `menu_pixmap_style` and `selected_item_pixmap_style` textures that produced a black panel on the graphical kernel-selection screen.
For a local graphical capture, set `DINX_QEMU_BOOT_KEYS=down,down,ret`, `DINX_QEMU_SCREENSHOT` and optionally `DINX_QEMU_SCREENSHOT_DELAY` before running `scripts/smoke-iso.sh`; the workflow uses the same boot keys, a 60-second delay and uploads the PPM with the ISO artifact.

The workflow also captures `dinx-boot-screen.ppm` three seconds after QEMU opens and before sending the boot-menu keys. This provides direct visual regression evidence for the GRUB kernel-selection screen.

The profile also embeds an experimental offline Calamares path with DINX branding, dinit service modules and a standalone KDE Partition Manager. The content check asserts the installer configuration, DINX palette/template defaults, ReGreet, Noctalia, Mango and recovery payloads. `scripts/smoke-install.sh` verifies the offline BIOS install, initramfs/GRUB generation, first boot and recovery TTY on an ephemeral disk; it is a CI contract smoke, not arbitrary hardware qualification.

For a second diagnostic capture after input, also set `DINX_QEMU_POST_SCREENSHOT`, optionally `DINX_QEMU_POST_SCREENSHOT_DELAY` and `DINX_QEMU_POST_KEYS`. This does not prove that the greeter accepted credentials.


## Latest observed successful run

Run [38830745529](https://github.com/rufl/DINX/actions/runs/38830745529) on commit `bc75f16` passed every P0 workflow step in 30m52s:

- ISO artifact: `artix-dinx-dinit-20261016-x86_64.iso`;
- the native package ran PTY/VT/session, allocator, protocol/Unicode, fairness, actual-tmux, deterministic-Zellij, ncurses, system-TUI and Vim/btop qualifications; the result was `noctty_p2_qualification ... assertions=true`;
- the integration contract passed terminal discovery, shell defaults, desktop entry, working-directory, Noctalia and package-runtime checks;
- system-TUI evidence covered top/watch/info/whiptail/fzf/SQLite/Glances/Bash/man/local SFTP; `info_surface=fixture_fallback` and `codex_surface=fixture` remain explicit boundaries;
- QEMU boot smoke, graphical payload verification, persistent-install/recovery-TTY smoke, SHA-512 generation, provenance attestation and artifact upload passed;
- uploaded artifact: `dinx-foundation-iso-bc75f163a8d85a207e2bdab5dd70cf1d3116d1b4`, 2,341,669,977 bytes, containing the ISO, checksum, QEMU log and VGA captures.

The run proves the package, ISO, VM boot, graphical payload, disposable BIOS persistent-install/recovery path and provenance contracts. It does not prove physical BC-250 tuning, authenticated Codex/network access or long-term hardware service health.

## Earlier observed successful run

Run [38471629482](https://github.com/rufl/DINX/actions/runs/38471629482) on commit `6224b58` passed all workflow steps in 6m02s:

- ISO artifact: `artix-dinx-dinit-20261013-x86_64.iso`;
- size: 1,497,237,504 bytes;
- SHA-512: `adcd6cba882b368725ffa02d33e8a2ae17c3be1b9ffaa17692dbd9eb895689bb0a686530f1012a11f6d262ef2d9ab859d27c2995393aa1ded4cd50d4af42433c`;
- QEMU smoke window: 90 seconds, passed;
- payload check: MangoWM, Scenefx, Noctalia, ReGreet, greetd and dinit payloads present;
- graphical capture: the initial frame showed the ReGreet user/session selector, and the post-input frame showed the MangoWM session with the Noctalia welcome screen;
- artifact: `dinx-foundation-iso-6224b5859de814b1d5fe7e2fae982e1c9c49918f`, retained for 7 days.

The generated serial log was empty. The two VGA captures provide evidence of greeter rendering and a successful graphical user-session transition; they do not prove networking, audio or long-term service health.

## Observed P1 persistent-install run

Run [38628961983](https://github.com/rufl/DINX/actions/runs/38628961983) on commit `f5d13faa6387d35ecac8c0e674f7e98bf7ff037a` passed the deterministic P1 workflow:

- persistent install smoke: passed on the disposable BIOS/IDE disk after copying the ISO rootfs, removing live-only packages, creating `dinx`/fstab, generating initramfs and BIOS GRUB, and booting through the installed GRUB path;
- first-boot marker: `/var/lib/dinx/install-smoke.booted` was verified after the 180-second QEMU boot window;
- recovery TTY: `getty@tty2` was enabled and verified in the installed target, and the recovery capture was produced;
- release gates: ISO payload verification, attestation and workflow artifact upload passed.

## Observed removable-media extension

Run [38700095287](https://github.com/rufl/DINX/actions/runs/38700095287) on commit `f2acffbf77e7242fbf16848b58dff8ef8aa63bab` passed with the removable-media stack plus File Roller and Nano. The payload check confirmed File Roller through the Thunar archive plugin and the Nano recovery editor, rejected installed systemd package metadata/runtime, and the persistent install smoke, attestation and artifact upload also passed.


## Observed development host

The development host is EndeavourOS x86_64. `pacman`, `xorriso` and `zig` are available. `buildiso`, `mkarchiso` and `qemu-system-x86_64` are not installed. QEMU user libraries and `/dev/kvm` are present, but that is not sufficient to run the local smoke test.

Therefore the P0 build must run in the remote workflow until the local dependencies are available.

## Acceptance sequence

1. `scripts/check-iso-host.sh` exits successfully in the Artix container.
2. `scripts/build-iso.sh -q` resolves the `dinx` profile with `dinit`.
3. A clean build produces one ISO and its build metadata.
4. The graphical payload check finds the compositor, shell, greeter, session, first-party apps, removable-media stack and dinit files.
5. A SHA-512 checksum is generated beside the ISO.
6. `scripts/smoke-iso.sh` keeps QEMU alive for the boot window.
7. The ISO boots to the foundation session and a recovery TTY.
8. Networking, PipeWire, D-Bus, portals and graphics are checked in the booted image.
9. Only after these pass do the desktop and first-party application packages become release inputs.
