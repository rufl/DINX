# P0 build status

[English](p0-build.md) · [Português (Brasil)](pt-BR/p0-build.md)

## Selected implementation

DINX uses Artix's current `artools`/`buildiso` flow with a repository-local `profile.yaml` under `distro/iso/iso-profiles/dinx`. This keeps dinit service package selection in the Artix-supported path and avoids inventing a second ISO builder.

The entry points are:

- `scripts/check-iso-host.sh` — prerequisite probe;
- `scripts/build-iso.sh` — root-aware build wrapper;
- `scripts/prepare_first_party_apps.sh` — deterministic archive generator for the pinned NOCTTY/NoctEd source;
- `scripts/check_first_party_apps.sh` — first-party source, package and profile contract check;
- `scripts/check_build_metadata.sh` — validates builder provenance, package snapshots, builder pacman-configuration hashes, source checksums and the emitted ISO digest, and can recompute the ISO byte count and SHA-512 against the downloaded artifact;
- `scripts/check_dinx_package_repository.sh` — verifies repository snapshot metadata, package/database signatures, key fingerprint and duplicate archive paths;
- `scripts/smoke_dinx_update.sh` — real signed pacman install/update/downgrade transaction against disposable roots;
- `scripts/check_dinx_release_preflight.sh` — stable-channel, persistent-key and GitHub release-asset preflight;
- `scripts/check_dinx_package_provenance.sh` — requires pinned source checksums or explicit local/staged package contracts for every DINX PKGBUILD;
- `scripts/check_dinx_feature_groups.sh` — validates the Mocaccino-inspired feature-group manifest against the Artix profile;
- `scripts/check_wizp_package.sh` — staged self-contained WIZP/CEF package, desktop entry, icon and text-file argument contract;
- `scripts/check_dinxpanel.sh` — DINXPanel control-center, fixed GPU bridge and safe kernel-installer contract;
- `scripts/check_gaming.sh` — standalone Gamescope/Steam session, 32-bit graphics and ISO payload contract;
- `scripts/check_alpha7_hardware_report.sh` and `scripts/check_dinx_hardware_evidence.sh` — the hardware-report schema retains the Alpha 7 name for compatibility; the checks cover BC250 detection, manual boundaries and release evidence;
- `docs/alpha7-qualification.md` — three-machine hardware evidence matrix and manual qualification boundary for the Alpha 9 system release;
- `scripts/check_dinx_budget.sh` and `scripts/measure_dinx_session.sh` — payload/startup/native-binary/boot-window/ISO ceilings and runtime RSS/CPU observation;
- `scripts/gaming_p5_qualification.sh` — fixture session return, signal-time process-group cleanup/profile restoration and real headless Gamescope launch/exit qualification;
- `scripts/noctty_p2_qualification.sh` — deterministic ReleaseSafe P2 matrix for allocator/fairness, PTY/session continuity, ncurses and system TUIs;
- `scripts/nocted_p3_qualification.sh` — deterministic P3 matrix for Nocted core/index/workers/state/tasks, real `clangd`, native GTK/X11 dark/light smoke and Git status/diff;
- `scripts/smoke-iso.sh` — QEMU boot probe;
- `scripts/smoke-install.sh` — disposable-disk persistent-install and recovery-TTY smoke;
- `scripts/dinitui_dinit_qualification.sh` — real temporary Dinit daemon, service lifecycle and GTK smoke;
- `scripts/smoke_calamares_startup.sh` — bounded Calamares startup smoke against the shipped configuration;
- `.github/workflows/p0-iso.yml` — remote build in an Artix container;
- `.github/workflows/release.yml` — tagged pre-release publication and Windows QEMU package assembly;
- `distro/packages/noctty/PKGBUILD` — native Zig package that installs NOCTTY and NoctEd;
- `distro/packages/noctty/qualification-compat.patch` — packaging patch that wires the pinned source's PTY qualification target to its existing compatibility module and adds the Nocted P3 Git/theme/package contract;
- `distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/labwc/rc.xml` — checked-in DINX labwc compositor/session configuration;
- `distro/packages/dinitui/PKGBUILD` — native Zig 0.17 GTK4/libadwaita Dinit frontend;
- `distro/packages/wizp/PKGBUILD` — package boundary for the exact self-contained WIZP Linux directory; it requires `WIZP_PACKAGE_DIR` instead of rebuilding an unpinned source tree.
- `distro/iso/iso-profiles/dinx/feature-groups.json` — foundation, desktop, gaming, hardware and optional package-group metadata; optional groups are outside the base ISO.

## Remote build

The `P0 ISO foundation` workflow runs manually or when profile/build files change. It:

1. checks out DINX;
2. verifies the committed NOCTTY/NoctEd source archive against `distro/packages/noctty/source.env` and validates the package/profile contract;
3. installs QEMU and ISO inspection tools on the Ubuntu runner;
4. runs Artix in a privileged container;
5. installs `artools`, `iso-profiles`, Rust, gettext, go-md2man, Zig 0.17.0, `clang`/`clangd`, Xvfb, VTE 2.91 (`vte3`) for the headless Noctty smoke binary, Ghostty's `libghostty-vt.so` runtime, the public Artix `labwc` package and its `wlroots0.20` dependency;
6. builds the pinned Artix package payload for topgrade, paru and Shelly, the BC250 Control Center v1.21.1 source release, the Cyan Skillfish governor and its dinit integration; then builds the native `noctty` package, which contains both NOCTTY and NoctEd, while labwc and its public `wlroots0.20` dependency are consumed from the configured Artix repositories, and executes the pinned source's headless PTY/VT/terminal-session smoke markers, the allocator-accounted terminal-session qualification (four normal and one forced cycle), the protocol/Unicode compatibility qualification, `scripts/noctty_p2_qualification.sh` and `scripts/nocted_p3_qualification.sh` in ReleaseSafe. The P3 matrix proves the native editor path in both packaged schemes, a real `clangd` symbol response, and bounded Git status/diff markers. That matrix uses actual tmux plus a deterministic Zellij shim, real Nano/Less/Dialog and top/watch/whiptail/fzf/SQLite/Glances/Bash/man/local SFTP checks, and the Nocted project/editor qualification;

7. runs the prerequisite probe;
8. builds the ISO with `buildiso`;
9. validates the root and live-session SquashFS payloads;
10. generates a SHA-512 checksum;
11. keeps QEMU running for a configurable boot window and captures its VGA surface;
12. attempts disposable BIOS and UEFI disks produced from the same offline rootfs/Calamares package-removal contract, generates initramfs and the matching BIOS or UEFI GRUB path, then checks a dinit first-boot marker and recovery-TTY service;

13. creates GitHub artifact attestations for the ISO and checksum;
14. publishes the ISO, checksum, QEMU logs and PPM captures as a temporary workflow artifact.

The temporary pacman repository is signed inside the builder with an ephemeral CI key. The workflow records the package-content snapshot, repository database/key checksums and signing fingerprint in `build-metadata.txt`, then verifies all package/database signatures and archive path ownership before `buildiso` consumes the repository. This qualifies the build contract; it is not the production repository key or an installed-system update channel.
The builder now asserts the pinned image environment before `docker run` and again inside the container, so metadata generation cannot proceed with an unset image identity.
The ISO compaction wrapper enforces the tool's supported xz preset with x86 BCJ, 1 MiB blocks and a 1 MiB dictionary, and excludes kernel sources, pacman package caches and build logs. The workflow records the compression schema and wrapper checksum in `build-metadata.txt`; `check_build_metadata.sh` binds them to the checked-out wrapper. Build-only SquashFS tooling stays in the builder and is not copied into the runtime payload.
The installed first-boot marker now checks that the pacman database survived the offline install, DINX core packages are installed, NetworkManager and elogind are available through dinit, DinitUI/DINXPanel have no unresolved dynamic libraries, and WIZP/CUPS remain outside the base image.

DinitUI is built from `distro/packages/dinitui` with Zig 0.17.0 against GTK4/libadwaita, while DINXPanel is built from `distro/packages/dinxpanel` and both packages are added to the temporary pacman repository and installed through the DINX profile. `scripts/check_dinitui.sh` validates the DinitUI backend contract; `scripts/check_dinxpanel.sh` validates the YaST-inspired control center, fixed shortcuts, direct-argv launches, fixed GPU bridge and safe kernel catalog before the container build.
The DINXPanel upgrade report uses Shelly's read-only `sync`/`list-updates all` path plus optional `fwupdmgr refresh`/`get-updates`; Topgrade preview is `topgrade --dry-run --show-skipped --no-self-update --no-tmux`, and applying Topgrade or Shelly remains an explicit terminal action.
`scripts/dinitui_dinit_qualification.sh` drives a temporary real Dinit user daemon, validates `list`/`status`/`stop`, and runs the production DinitUI GTK smoke against that socket. It requires Dinit binaries and `xvfb-run`; it is intentionally separate from the privileged ISO container gate. The Noctalia plugin is linted with `noctalia plugins lint`, and the shipped Noctalia config is checked with `noctalia config validate`.

The gaming profile preserves Bluetooth/controller and firewall/process-policy services by default; it does not trade security for an unmeasured benchmark gain. The standalone `dinx-gaming` launcher is exposed as a Wayland session and uses the native Gamescope DRM backend. Its Steam 32-bit dependencies are pulled from Artix's official `lib32` repository, enabled by the ISO builder. DINXPanel owns the visible GPU actions and delegates to DinitUI's fixed `lspci -nnk` detection and vendor plans; its kernel installer offers only `linux`, `linux-lts`, `linux-zen` and `linux-hardened` with matching headers, never removes packages, protects the running kernel and requires a reboot. `scripts/check_gaming.sh` runs before the container build, while `scripts/gaming_p5_qualification.sh` remains the local/runtime gate. Its fixture path does not authenticate Steam or claim a commercial game, controller/audio hardware, DRM output or suspend/resume.
The isolated NoctEd GTK smoke renders its fallback icons to PNG with `rsvg-convert` and uses a self-contained `NoctedSmoke` theme with only the standard `hicolor` fallback: GTK3 does not need the container's inherited Adwaita SVG assets, legacy XPM loaders or external theme loader setup. The Artix container explicitly installs Glycin, bubblewrap and shared-mime-info, rebuilds the MIME database, and refreshes the GdkPixbuf cache before the package build. The build-only Noctty qualification disables Glycin's nested sandbox because it already runs inside the privileged build container; the packaged runtime keeps the bubblewrap dependency and does not inherit that setting. The fixture therefore does not turn that packaging difference into a false release failure.

### Local P4/P5 qualification

The local gates pass the DinitUI package contract, a real temporary user-Dinit daemon plus GTK smoke, and the gaming session fixture plus headless Gamescope launch/exit. Tagged release run [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) supplies the matching stable package repository, ISO, QEMU, payload, Calamares BIOS/UEFI/Btrfs transaction, disposable BIOS and UEFI persistent-install/recovery-TTY, build-metadata verification, attestation and published Alpha 9 release assets. P5's real DRM, authenticated Steam/game, controller/audio and physical-hardware boundaries remain open.

A verificação de payload prova que labwc, Noctalia, ReGreet, greetd, a sessão `Labwc (DINX)`, o launcher/sessão gaming standalone, Gamescope, Steam, o payload gráfico de 32 bits, os arquivos de serviço dinit, NOCTTY/NoctEd, `clangd`, os dois esquemas do editor Nocted, Nano, Pori, Phyto e UDisks2 chegaram à ISO. O contrato de armazenamento exige o caminho de serviços dinit do Pori em `/etc/dinit.d`, o módulo de kernel `ntfs3` para leitura e escrita na sessão live e o canal opcional pós-instalação `ntfs-3g`, exige File Roller para ações com arquivos compactados e GParted para particionamento gráfico independente, enquanto rejeita payloads de Thunar, GVFS, Tumbler e KDE Partition Manager. Ela também confirma o agente independente de PolicyKit, rejeita metadados/runtime do pacote init systemd enquanto permite bibliotecas de compatibilidade exigidas por Gamescope/Steam e rejeita sessões completas do Xfce/LXQt. O smoke test do QEMU ainda prova somente aceitação de boot em nível de processo; não prova login gráfico, rede, MTP, SMB, acesso à câmera ou áudio dentro do guest.
The payload check also proves Firefox, its desktop entry, the default HTML/XHTML/HTTP/HTTPS handlers and `/etc/firefox/policies/policies.json`. That policy removes sponsored browser surfaces, Pocket/Stories, Firefox Studies and telemetry, browser recommendations, AI assistant/link-preview/tab-group surfaces and built-in IP Protection without disabling normal browser updates or user-initiated Firefox Accounts.
The same contract proves the expanded desktop payload: btop/nvtop/inxi, PCI/USB diagnostics, Git/curl/less/jq/rsync, Zathura with MuPDF, Swayimg, VLC with its Qt GUI/CLI split, Strawberry, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, `wl-clipboard`, SANE's `scanimage` backend, `fwupdmgr`, the Flatpak runtime and KolourPaint. It also verifies the labwc stacking default, the top `main` bar, the bottom Noctalia dock, the Noctalia screenshot/clipboard widgets and the VLC/Strawberry MIME handlers. Swayimg remains the default image viewer; KolourPaint provides simple image editing without changing that default. Noctalia remains the primary screenshot path; transitive Artix package dependencies may also provide `grim`/`slurp`.

The display contract also requires bundled `wdisplays` and `shikane` binaries plus DINX's `dinx-wdisplays` persistence wrapper and named-profile saver. The optional Seafoam group also contains Seafoam Settings, a fixed-argv native Zig/GTK4 settings launcher, and the source-pinned official ZLS 0.16.0 package used by Nocted for Zig LSP; neither package is part of the base ISO. The optional Dome package is source-pinned to Pearl v0.3.0 and is built with the workflow's pinned Zig 0.16 toolchain; it is not part of the base ISO payload.
The session contract also keeps Aqueous and Pearl out of the shipped greeter entries until their upstream `uwsm`/systemd user-unit lifecycle is replaced by a qualified dinit-native package. The read-only `dinx-doctor` overlay command reports session, dinit, storage, display and package evidence without starting services, mounting devices, changing profiles or contacting a network.
The package-management contract also proves `topgrade`, `paru`, and Shelly. Topgrade uses a pinned upstream release binary with DINX's Artix pacman configuration; paru is built from its pinned source release against Artix ALPM; Shelly delegates to Artix's `pacman` configuration. Their package metadata contains no `systemd` dependency or unit, no Arch repository is added, and all AUR recipes remain subject to explicit user review. They remain user-invoked; the ISO does not auto-run package upgrades.
The hardware contract proves AMDGPU firmware, Mesa RADV, Vulkan diagnostics and the pinned Cyan Skillfish SMU governor. A dinit service is linked for both the live and installed profiles, detects PCI `1002:13fe` (BC-250), then starts the governor with a conservative 1000-1850 MHz range; on other hardware it exits without changing anything. Use an Artix kernel with current BC-250 fixes (6.17.11 or newer). No systemd service is installed.
The BC250 Control Center package is pinned to the upstream v1.21.1 MIT source release. It installs the GUI, CLI, polkit policy and headless daemon with Python 3.12+ / PyQt6 runtime dependencies. DINX removes the upstream systemd user unit and Cyan systemd drop-in; labwc starts `bc250-control-centerd` in the logged-in user session through `/etc/xdg/labwc/autostart`, so the package adds no systemd service or dinit root service. The upstream dinit detection remains read-only for service persistence, while live BC-250 telemetry and the graphical controls remain available subject to their polkit and hardware prerequisites.
The same ISO contract proves UFW, Gufw, Qps, OpenSnitch and the `ufw`/`opensnitchd` dinit service files. It asserts the safe default (`ENABLED=no` and no boot links for either firewall service), so network policy changes require explicit user configuration.
The workflow also captures the QEMU VGA surface as a PPM artifact through the monitor. That capture is visual evidence to inspect; it does not automatically prove successful live autologin, user-session health, networking or audio.

Tagged releases reuse the same build artifact through `.github/workflows/release.yml`. The release job publishes either the ISO or ordered sub-2 GiB ISO parts, the full SHA-512, the Linux QEMU evidence and a small Windows launcher package. The launcher downloads the metadata-pinned HTTPS URL and, when required, each ordered part, verifies the parts and full SHA-512, then runs `scripts/smoke-iso.ps1` with QEMU on Windows. Its ZTASH metadata targets the registered `ddjarin` receiver without embedding credentials.

The live overlay also replaces the generic `root-ro` dinit service with a no-op: the live root is an overlay and cannot be remounted read-only. This is an ISO-only live-session adjustment, not an installed-system policy.

The labwc wrapper enables `WLR_RENDERER_ALLOW_SOFTWARE=1` only when `/dev/dri/renderD*` is absent, so the headless QEMU path does not mask a real DRM render node.

The profile owns the DINX visual contract at `root-overlay/etc/skel/.config/noctalia/palettes/DINX.json`. `scripts/check_dinx_theme.sh` validates both palette variants, Noctalia templates, GTK/Qt/labwc adapters, ReGreet, Calamares and GRUB before `buildiso`; `scripts/check-iso-content.sh` verifies the same files inside the root SquashFS image.
The profile also owns the Artix GRUB theme configuration at `root-overlay/usr/share/grub/themes/artix/theme.txt`. It keeps the upstream logo, icons and font assets, uses the DINX surface/text/primary colors, and omits the opaque `menu_pixmap_style` and `selected_item_pixmap_style` textures that produced a black panel on the graphical kernel-selection screen.
For a local graphical capture, set `DINX_QEMU_BOOT_KEYS=down,down,ret`, `DINX_QEMU_SCREENSHOT` and optionally `DINX_QEMU_SCREENSHOT_DELAY` before running `scripts/smoke-iso.sh`; the workflow uses the same boot keys, a 60-second delay and uploads the PPM with the ISO artifact.

The workflow also captures `dinx-boot-screen.ppm` three seconds after QEMU opens and before sending the boot-menu keys. This provides direct visual regression evidence for the GRUB kernel-selection screen.

The profile also embeds an experimental offline Calamares path with DINX branding and dinit service modules; Pori is the only graphical storage UI, while Phyto is the default file manager. The content check asserts the installer configuration, DINX palette/template defaults, ReGreet, Noctalia, labwc and recovery payloads. `scripts/smoke-install.sh` verifies offline BIOS and UEFI installs, initramfs/GRUB generation, first boot and recovery TTY on ephemeral disks; it is a CI contract smoke, not arbitrary hardware qualification.
The Calamares partition contract is checked before the container build: a 1 GiB recommended/64 MiB minimum EFI partition, FAT32 EFI and ext4/btrfs root restrictions, explicit manual partitioning, disabled LVM, live-mount exceptions, offline package removal, kernel `ntfs3` read/write support, optional post-install `ntfs-3g`, `os-prober` support and an explicit top-level Btrfs mount plan that does not recreate existing `@`/`@home`. `scripts/smoke_calamares_partitioning.sh` round-trips disposable BIOS and UEFI partition tables, filesystems and fstab data and reopens a Btrfs volume with existing subvolumes. `scripts/smoke_calamares_windows.sh` preserves an existing Windows-style FAT32 ESP/Microsoft boot path and NTFS partition while completing both side-by-side and manual-layout DINX root/GRUB transactions. These are supported-layout transaction smokes, not a claim that every Calamares filesystem, encryption, RAID, BitLocker, hibernation, Windows firmware or physical-firmware path is bug-free.

For a second diagnostic capture after boot, set `DINX_QEMU_POST_SCREENSHOT` and optionally `DINX_QEMU_POST_SCREENSHOT_DELAY`. Leave `DINX_QEMU_POST_KEYS` unset for the normal autologin path. A post frame proves only that QEMU rendered another point in the session.


## Latest published release run

Run [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) for tag `v0.1.0-alpha.9` on commit `0d1698a462d5d5486871a7aa17e9b97352ee9404` completed every release workflow step successfully, including build-metadata verification:

- the static contracts for first-party packages, DinitUI, gaming and the ISO payload passed before the container build;
- Artix package builds and `buildiso` completed, including the Steam/32-bit graphics packages resolved from the enabled Artix `lib32` repository;
- the Calamares partition contract passed, including BIOS/UEFI table and filesystem round-trips and an existing Btrfs volume with `@` and `@home`;
- QEMU boot and graphical capture passed;
- graphical ISO payload validation passed, including DinitUI, the standalone gaming session, Steam and the 32-bit graphics payload;
- disposable persistent-install, first-boot and recovery-TTY smoke passed on both BIOS and UEFI disks;
- GitHub provenance attestation, build-metadata verification and artifact upload passed;
- published release assets include the direct ISO, checksum, signed stable package repository, Windows package and build metadata; the ISO is 2,008,801,280 bytes with SHA-512 `b3724c82348c229ee897880e03e8adc80d9b5b25588b0aca9dfcfedf0c4744e4e1ae01dcb536f6555502e8fe595f71f06bed599372dffe0e1b0f34b29f3b5b2d`.


This run closes the P4 DinitUI package/ISO/persistent-install path for the alpha gate. It proves the package, ISO, VM boot, graphical payload, Calamares supported-layout transaction smokes, disposable BIOS and UEFI persistent-install/recovery paths and provenance contracts. It does not prove authenticated Steam/game use, a real DRM gaming display, controller/audio hardware, physical firmware or hardware installation, upgrades, rollback, BitLocker/hibernated Windows resizing or long-term hardware service health.

## Latest post-release `main` validation

Run [39934458077](https://github.com/rufl/DINX/actions/runs/39934458077) on `main` commit `eb9a0c143c06d9c1939f9d88684d164d8e2384fb` completed in 52m02s after passing the same package/profile contracts, compact ISO build, QEMU boot and graphical payload checks, BIOS/UEFI persistent-install and recovery-TTY smokes, provenance attestation and artifact upload. This is validation evidence only; it did not publish a new release.

## Earlier observed successful run

Run [38471629482](https://github.com/rufl/DINX/actions/runs/38471629482) on commit `6224b58` passed all workflow steps in 6m02s:

- ISO artifact: `artix-dinx-dinit-20261013-x86_64.iso`;
- size: 1,497,237,504 bytes;
- SHA-512: `adcd6cba882b368725ffa02d33e8a2ae17c3be1b9ffaa17692dbd9eb895689bb0a686530f1012a11f6d262ef2d9ab859d27c2995393aa1ded4cd50d4af42433c`;
- QEMU smoke window: 90 seconds, passed;
- payload check: Noctalia, ReGreet, greetd and dinit payloads present;
- graphical capture: this historical pre-autologin frame showed the ReGreet user/session selector, and the post-input frame showed the graphical user session with the Noctalia welcome screen;
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
4. The graphical payload check finds the compositor, shell, greeter, session, first-party apps, Pori, Phyto, UDisks2, the kernel `ntfs3` module and dinit files.
5. A SHA-512 checksum is generated beside the ISO.
6. `scripts/smoke-iso.sh` keeps QEMU alive for the boot window.
7. The ISO boots to the foundation session and a recovery TTY.
8. Networking, PipeWire, D-Bus, portals and graphics are checked in the booted image.
9. Only after these pass do the desktop and first-party application packages become release inputs.
