# P0 build status

[English](p0-build.md) · [Português (Brasil)](pt-BR/p0-build.md)

## Selected implementation

DINX uses Artix's current `artools`/`buildiso` flow with a repository-local `profile.yaml` under `distro/iso/iso-profiles/dinx`. This keeps dinit service package selection in the Artix-supported path and avoids inventing a second ISO builder.

The entry points are:

- `scripts/check-iso-host.sh` — prerequisite probe;
- `scripts/build-iso.sh` — root-aware build wrapper;
- `scripts/prepare_first_party_apps.sh` — deterministic archive generator for the pinned upstream source that supplies Deetty and Dintor;
- `scripts/check_first_party_apps.sh` — first-party source, package and profile contract check;
- `scripts/check_build_metadata.sh` — validates builder provenance, package snapshots, builder pacman-configuration hashes, source checksums and the emitted ISO digest, and can recompute the ISO byte count and SHA-512 against the downloaded artifact;
- `scripts/check_dinx_package_repository.sh` — verifies repository snapshot metadata, package/database signatures, key fingerprint and duplicate archive paths;
- `scripts/smoke_dinx_update.sh` — real signed pacman install/update/downgrade transaction against disposable roots;
- `scripts/check_dinx_release_preflight.sh` — stable-channel, persistent-key and GitHub release-asset preflight;
- `scripts/check_dinx_package_provenance.sh` — requires pinned source checksums or explicit local/staged package contracts for every DINX PKGBUILD;
- `scripts/check_dinx_feature_groups.sh` — validates the Mocaccino-inspired feature-group manifest against the Artix profile;
- `scripts/check_wizp_package.sh` — staged self-contained WIZP/CEF package, desktop entry, icon and text-file argument contract;
- `scripts/check_dinxpanel.sh` — DINXPanel control-center, fixed GPU bridge and safe kernel-installer contract;
- `scripts/check_gaming.sh` — hidden manual launcher, optional package-group boundary, base Vulkan retention, and ISO payload exclusions;
- `scripts/check_alpha7_hardware_report.sh` and `scripts/check_dinx_hardware_evidence.sh` — the hardware-report schema retains the Alpha 7 name for compatibility; the checks cover BC250 detection, manual boundaries and release evidence;
- `docs/alpha7-qualification.md` — three-machine hardware evidence matrix and manual qualification boundary for the current Alpha 12 system release;
- `scripts/check_dinx_budget.sh` and `scripts/measure_dinx_session.sh` — payload/startup/native-binary/boot-window/ISO ceilings and runtime RSS/CPU observation;
- `scripts/gaming_p5_qualification.sh` — fixture session return, signal-time process-group cleanup/profile restoration and real headless Gamescope launch/exit qualification;
- `scripts/deetty_p2_qualification.sh` — deterministic ReleaseSafe P2 matrix for allocator/fairness, PTY/session continuity, ncurses and system TUIs;
- `scripts/dintor_p3_qualification.sh` — deterministic P3 matrix for Dintor core/index/workers/state/tasks, a builder-only real `clangd` protocol fixture, native GTK/X11 dark/light smoke and Git status/diff;
- `scripts/smoke-iso.sh` — QEMU boot probe;
- `scripts/smoke-install.sh` — disposable-disk persistent-install and recovery-TTY smoke;
- `scripts/dinitui_dinit_qualification.sh` — real temporary Dinit daemon, service lifecycle and GTK smoke;
- `scripts/smoke_calamares_startup.sh` — bounded Calamares startup smoke against the shipped configuration;
- `.github/workflows/p0-iso.yml` — remote build in an Artix container;
- `.github/workflows/release.yml` — tagged pre-release publication and Windows QEMU package assembly;
- `distro/packages/deetty/PKGBUILD` — native Zig package that installs Deetty and Dintor;
- `distro/packages/deetty/qualification-compat.patch` — packaging patch that wires the pinned source's PTY qualification target to its existing compatibility module and adds the Dintor P3 Git/theme/package contract;
- `distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/config.toml` and `distro/iso/iso-profiles/dinx/root-overlay/etc/pearl/greeter.json` — checked-in Pearl Greeter configuration; greetd launches the dedicated host directly without systemd or UWSM;
- `distro/packages/wizp/PKGBUILD` — package boundary for the exact self-contained WIZP Linux directory; it requires `WIZP_PACKAGE_DIR` instead of rebuilding an unpinned source tree.
- `distro/iso/iso-profiles/dinx/feature-groups.json` — foundation, desktop, gaming, hardware and optional package-group metadata; optional groups are outside the base ISO.

## Remote build

The separate `DINX contracts` workflow runs static/fixture checks and REUSE lint on every pull request and push to `main`. P0 and contracts checkout `rufl/DEETTY` with `DEETTY_SOURCE_READ_TOKEN` when configured, otherwise `GITHUB_TOKEN`; the token must be able to read the source repository. Contracts skips source-dependent checks only for pull requests from external forks that cannot receive repository secrets.

### Live state and handoff

Conversation summaries and this document's history are pointers, not live CI state. Before reporting a PR/run status or dispatching/restarting P0, query GitHub:

```sh
gh pr view <number> --json state,mergedAt,mergeCommit,headRefOid,url
gh run list --workflow p0-iso.yml --branch main --limit 20 --json databaseId,status,conclusion,headSha,createdAt,url
gh run view <run-id> --json status,conclusion,headSha,event,url,updatedAt
```

After a merge, the push-triggered `main` run is canonical. Reuse a queued/in-progress run for the same workflow and commit; do not dispatch a duplicate. On failure, inspect failed-step logs and published diagnostics/screenshots before changing code; target only a failure those artifacts demonstrate.

Checkpoint, last checked live on 2026-11-11: no PR is open. Canonical push P0 [run #43100285777](https://github.com/rufl/DINX/actions/runs/43100285777) on main commit `b8eb2d82c6b1df8310a3dc6f557961988f71361b` completed with **success**. The build exercised precompiled DINX package cache and upstream delta synchronization (`scripts/sync_dinx_cache.sh`), assembled the foundation ISO, and passed all qualification gates: static ISO metadata and content checks (`check_build_metadata.sh`, `check-iso-content.sh`), live QEMU VGA boot with Plymouth splash and Aqueous/Pearl graphical session, live QEMU Virtio-VGA boot with Plymouth splash and Aqueous/Pearl graphical session, installed BIOS boot with Pearl Greeter and persistent keyring verification, and installed UEFI boot with Pearl Greeter and persistent keyring verification. Artifact `dinx-p0-success-b8eb2d82c6b1df8310a3dc6f557961988f71361b` (ID `13894392024`, 3,532,355,115 bytes) was produced and published. QEMU evidence is not VirtualBox evidence.

A focused `makepkg` build of Paru 2.1.0-3 passed against OpenSSL 4.1.0 with both pinned crates before this handoff.

An ISO is verified only after a successful P0 run, retrieval of that run's artifact, checksum/build-metadata verification, and review of the qualification evidence. State which gates ran; QEMU success is not VirtualBox evidence.

The `P0 ISO foundation` workflow runs manually or when profile/build files change. It:

1. checks out DINX;
2. reads the pinned source commit from `distro/packages/deetty/source.env`, checks out `rufl/DEETTY`, generates the git-ignored Deetty/Dintor source archive and verifies it against the pinned SHA-256;
3. installs QEMU, ISO inspection tools and Tesseract's English OCR data on the Ubuntu runner;
4. runs Artix in a privileged container;
5. installs `artools`, `iso-profiles`, Rust, gettext, go-md2man, Zig 0.17.0, builder-only `clang`/`clangd`, Xvfb and VTE 2.91 (`vte3`) for Deetty's headless smokes. The full Ghostty application is installed temporarily in the builder only as the extraction source for `ghostty-vt-runtime`; that package contains the VT library, headers and license, after which the full application is removed before ISO assembly. The DINX Aqueous/Pearl packages and their direct Wayland dependencies are built from the configured package inputs.
Pearl 0.3.0 follows its upstream `.zigversion` and is built with the exact Zig 0.16.0 archive verified by the workflow; DINX-native Zig packages remain on the verified Zig 0.17.0 toolchain.
6. builds pinned DINX packages, including paru and Shelly plus the BC250 Control Center v1.21.1 and Cyan Skillfish governor; hardware-specific packages are marked `iso:false` and remain absent from both generic rootfs profiles. It builds and installs Deetty/Dintor against the VT-only runtime before DINXPanel and the Aqueous/Pearl session packages, then packages Seafoam Settings; all DINX terminal launch paths use Deetty. The Deetty package build runs the pinned PTY/VT/session smoke markers, allocator-accounted terminal-session qualification, protocol/Unicode qualification, `scripts/deetty_p2_qualification.sh` and `scripts/dintor_p3_qualification.sh` in ReleaseSafe. The P3 matrix proves the native editor path in both packaged schemes, a builder-only real `clangd` symbol response and bounded Git status/diff markers. It uses real tmux plus a deterministic Zellij shim, real Nano/Less/Dialog, top/watch/whiptail/fzf/SQLite/Glances/Bash/man/local SFTP and the Dintor project/editor qualification.
The product-identity patch updates the upstream task-probe and clangd LSP smokes to launch the renamed `zig-out/bin/dintor`; the package integration contract verifies neither smoke uses the old `nocted` executable path.

7. runs the host prerequisite probe;
8. builds the ISO with `buildiso`;
9. validates the root and live-session SquashFS payloads, including the rootfs Dinit log-directory tmpfiles rule and livefs-only root-remount overrides;
10. generates the SHA-512 checksum;
11. runs `scripts/qualify-iso.sh`: verifies metadata, checksum, payload and budgets; boots/captures default VGA and Virtio-VGA in QEMU; then runs BIOS/UEFI install simulations from the same rootfs, checks installed packages and Dinit services, and OCR-checks recovery TTY 2. These simulations do not execute Calamares's GUI or partition modules end to end;
12. creates GitHub artifact attestations for the ISO and checksum;
13. publishes the ISO, checksum, QEMU logs and PPM captures as a temporary workflow artifact.

The temporary pacman repository is signed inside the builder with an ephemeral CI key. The workflow records the package-content snapshot, repository database/key checksums and signing fingerprint in `build-metadata.txt`, then verifies all package/database signatures and archive path ownership before `buildiso` consumes the repository. This qualifies the build contract; it is not the production repository key or an installed-system update channel.
Only the temporary Artix `buildiso` pacman config sets `DownloadUser = root`: pacman 7's `alpm` downloader cannot write the root-owned sync-database staging directory in a fresh basestrap target. This does not change the host pacman config or the installed image.
Local `pacman -U` installs retry up to three times, refreshing repository databases between attempts; a failed refresh aborts the transaction. `makepkg --clean` is skipped only for DinitUI, DINXPanel and Seafoam Settings because those recipes compile from checked-in `src/` trees. `scripts/smoke_pacman_local_install.sh` exercises first-attempt success, recovery, bounded failure and database-refresh failure.
The builder now asserts the pinned image environment before `docker run` and again inside the container, so metadata generation cannot proceed with an unset image identity.
The builder package preflight accepts installed package entries and expands pacman sync-group entries such as `artools` to verify every member; `pacman -Q` cannot query a group name.
The ISO compaction wrapper enforces xz with x86 BCJ and the largest SquashFS block/dictionary sizes supported by the tool (1 MiB each), while excluding kernel sources, pacman package caches and build logs. `mksquashfs` exposes no XZ compression-level option, so its tool default remains. The workflow records the compression schema and wrapper checksum in `build-metadata.txt`; `check_build_metadata.sh` binds them to the checked-out wrapper. Build-only SquashFS tooling stays in the builder and is not copied into the runtime payload.
Because Artix `buildiso` can call `/usr/bin/mksquashfs` directly, the privileged workflow preserves the real binary, installs the DINX wrapper at that absolute path, exports its real-binary path and rejects wrapper self-recursion. After assembly, `check-iso-content.sh` reads both generated SquashFS superblocks and verifies xz compression with 1 MiB blocks instead of trusting command-line intent alone.
The install simulation checks the on-disk pacman database, core packages, ZLS payload/version, DinitUI/DINXPanel/Dome/Seafoam/ZLS libraries, and exclusion of WIZP/CUPS before boot. It then checks real NetworkManager, elogind and `local.target` boot output and OCRs the recovery login prompt; it does not use a synthetic first-boot marker or claim a Calamares end-to-end install.

DinitUI, DINXPanel and Seafoam Settings use Zig 0.17.0 with `-Dcpu=baseline` on the native x86_64 Linux target so shared package-cache artifacts remain compatible across runner CPUs. DinitUI is built from `distro/packages/dinitui` against GTK4/libadwaita, while DINXPanel is built from `distro/packages/dinxpanel`; both packages enter the temporary pacman repository and are installed by the DINX profile. Their contracts validate the generic CPU setting along with the backend and app integration before container build.
The DINXPanel upgrade report uses Shelly's read-only `sync`/`list-updates all` path plus optional `fwupdmgr refresh`/`get-updates`; the panel also offers PaintFE and Zenkai launch shortcuts, and applying upgrades remains an explicit Shelly or terminal action.
`scripts/dinitui_dinit_qualification.sh` drives a temporary real Dinit user daemon, validates `list`/`status`/`stop` and runs the production DinitUI GTK smoke against that socket. It requires Dinit binaries and `xvfb-run`; it is intentionally separate from the privileged ISO container gate. The DinitUI package and its direct profile-state contract are checked without a shell plugin or private shell configuration.

The gaming service profile preserves Bluetooth/controller and firewall/process-policy services by default; it does not trade security for an unmeasured benchmark gain. The hidden standalone `dinx-gaming` launcher uses the native Gamescope DRM backend. Gamescope, Steam, Steam device rules, GameMode, MangoHud and 32-bit libraries are in the optional `gaming` feature group, excluded from rootfs and livefs; 64-bit RADV and Vulkan tools remain in the base. Users can opt in after installation using the Artix `[lib32]` setup in `docs/install.md`. P0 installs Gamescope only inside the builder for headless qualification, does not enable `[lib32]` or add Arch repositories, and retains a launcher preflight that checks Gamescope/Steam before profile changes. DINXPanel owns visible GPU actions and delegates to DinitUI's fixed `lspci -nnk` detection and vendor plans; its kernel installer offers only `linux`, `linux-lts`, `linux-zen` and `linux-hardened` with matching headers, never removes packages, protects the running kernel and requires a reboot. `scripts/check_gaming.sh` runs before the container build, while `scripts/gaming_p5_qualification.sh` remains the local/runtime gate; its fixture path does not authenticate Steam or claim a commercial game, controller/audio hardware, DRM output or suspend/resume.
The isolated Dintor GTK smoke renders its fallback icons to PNG with `rsvg-convert` and uses a self-contained `DintorSmoke` theme with only the standard `hicolor` fallback: GTK3 does not need the container's inherited Adwaita SVG assets, legacy XPM loaders or external theme loader setup. The Artix container explicitly installs Glycin, bubblewrap and shared-mime-info, rebuilds the MIME database, and refreshes the GdkPixbuf cache before the package build. The build-only Deetty qualification disables Glycin's nested sandbox because it already runs inside the privileged build container; the packaged runtime keeps the bubblewrap dependency and does not inherit that setting. The fixture therefore does not turn that packaging difference into a false release failure.

### Local P4/P5 qualification

The local gates pass the DinitUI package contract, a real temporary user-Dinit daemon plus GTK smoke, and the gaming session fixture plus headless Gamescope launch/exit. Tagged release workflow [41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) published Alpha 12 after the package/profile contracts, Artix build, QEMU graphical capture using default VGA, Calamares BIOS/UEFI/Btrfs transactions, disposable BIOS/UEFI install/recovery smokes, metadata binding, provenance attestation and release publication passed. That run did not exercise VMware-SVGA or VirtualBox VMSVGA. The current shared qualifier tests default VGA and Virtio-VGA; QEMU 11.1.2/KVM with `vmware-svga` stalls in early udev when `vmwgfx` loads, so that path is not VirtualBox evidence. Direct VirtualBox boot remains unqualified. P5's real DRM, authenticated Steam/game, controller/audio and physical-hardware boundaries remain open.

The published Alpha 9 payload check historically confirmed that Gamescope, Steam and 32-bit graphics packages were present in that release artifact; those package-presence claims do not describe the new base profile. Current P0 checks require the hidden gaming launcher and desktop entry while rejecting optional game binaries and package metadata in both rootfs and livefs. The storage contract still requires Pori's dinit service path under `/etc/dinit.d`, kernel `ntfs3` live read/write, optional post-install `ntfs-3g`, File Roller and GParted, while rejecting Thunar, GVFS, Tumbler and KDE Partition Manager. It also confirms the standalone PolicyKit agent and rejects systemd init package metadata/runtime while retaining dinit.
The payload check proves the Artix-packaged Firefox binary, desktop entry and default HTML/XHTML/HTTP/HTTPS handlers, with no DINX-managed browser policy file; browser updates arrive through the reviewed Artix package sources.
The same contract proves the expanded desktop payload: btop/nvtop/inxi, PCI/USB diagnostics, Git/curl/less/jq/rsync, PaintFE for raster editing, WordCraft for documents, GridCraft for spreadsheets, DeckCraft for presentations, PdfCraft for PDFs, Transit for audio production, Zenkai as the application launcher, Swayimg, source-built Haruna (Qt/QML on libmpv), Gapless (G4Music), Galculator, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, `wl-clipboard`, SANE's `scanimage` backend, `fwupdmgr`, the Flatpak runtime and Pixelorama. It requires the Pixelorama official Linux x86_64 release archive with pinned SHA-256, executable wrapper, visible launcher, icon, MIT license and `.pxo` MIME registration; the upstream binary is preserved without stripping. It also requires the checksum-pinned PaintFE, WordCraft, GridCraft, DeckCraft, PdfCraft, Transit and Zenkai AppImages, each installed as `/opt/<pkg>/<Name>.AppImage` with a `/usr/bin/<pkg>` wrapper that execs it with `--appimage-extract-and-run "$@"` and a visible `/usr/share/applications/<pkg>.desktop` launcher, so none of them needs FUSE. The same payload check requires the upstream license texts shipped by each package (`LICENSE.md` for PaintFE, `LICENSE-MIT` plus `LICENSE-APACHE` for the five dual-licensed Rust suites, `LICENCE.md` for Zenkai) and the 256x256 hicolor icon for PaintFE, WordCraft, GridCraft, DeckCraft, PdfCraft and Transit; Zenkai has no upstream square icon and uses the themed `system-search` name. PdfCraft is the default `application/pdf` handler. It rejects KolourPaint binaries/launchers/metadata, and rejects breeze-icons, Zathura, its MuPDF backend and libmupdf metadata in rootfs and livefs. It also verifies the Gapless package, codec dependencies, default gapless playback, D-Bus activation and audio MIME handlers; the upstream application exposes MPRIS media controls. Strawberry binaries, desktop entries and package metadata are rejected. Pearl shell surfaces, the Pearl Greeter host and DINX MIME handlers are verified; Swayimg remains the default image viewer.

The ISO no longer carries the retired browser, office, raster-editor,
audio-workstation and updater payload: the MIME defaults reject the retired
browser and office desktop entries, and the content check rejects those
packages' pacman metadata in both generic images. Releases use the existing
split-ISO path when the final image exceeds GitHub's 2 GiB per-asset limit.

The display contract also requires bundled `wdisplays` and `shikane` binaries plus DINX's `dinx-wdisplays` persistence wrapper and named-profile saver. The base Seafoam payload includes Seafoam Settings, a fixed-argv native Zig/GTK4 settings launcher, Dome source-pinned to Pearl v0.3.0 and the source-pinned official ZLS 0.16.0 package used by Dintor for Zig LSP. DINX native Zig packages are built with Zig 0.17.0; the ZLS package carries only the matching Zig `lib/std` tree plus its metadata-only shim, so the base ISO does not install a full Zig compiler or systemd; the workflow smoke-tests real completion/navigation before ISO assembly. The workflow builds all three into the signed DINX package repository, and the ISO profile requires their binaries, desktop metadata, icons and documentation.
The Seafoam smoke commands run inside the Artix builder after package installation; they are not separate host-run workflow steps.
The session contract builds and installs Aqueous 1.0.5 and Pearl 0.3.0, checks that `Aqueous + Pearl (DINX)` is the only selectable greeter entry and verifies the direct dinit lifecycle: Aqueous launches the DINX init child, which waits for Wayland and session D-Bus readiness, then the supervisor starts Shikane, PolicyKit, the required idle helper and Pearl. The optional BC-250 daemon is started only when a user separately installs the signed package after detecting PCI `1002:13fe`; BC-250 packages are not in the generic ISO. The recipes remove upstream `uwsm` and systemd user units; the Aqueous build removes its systemd library and activity-bootstrap D-Bus checks, replacing them with pidfd, executable and environment checks for direct dinit launches. The Pearl Greeter host runs only Pearl Greeter, and no legacy Xorg/XLibre server, driver or Plasma X11 payload is accepted in the runtime ISO; XWayland and builder-only Xvfb remain available where needed.
The package-management contract also proves `paru` and Shelly; Topgrade is no longer shipped. paru is built from its pinned source release against Artix ALPM; Shelly delegates to Artix's `pacman` configuration. Shelly's AUR desktop/config payload is pinned to immutable AUR revision `f89d773125357baaa1d2fae715286ce9e00e2cb4`, with checksums retained; the moving `shelly-bin` branch is not used. Their package metadata contains no `systemd` dependency or unit, no Arch repository is added, and all AUR recipes remain subject to explicit user review. They remain user-invoked; the ISO does not auto-run package upgrades.

The Paru recipe retains upstream Paru 2.1.0 while pinning Rust `openssl` 0.10.78 and `openssl-sys` 0.9.118, which support the builder's Artix OpenSSL 4.1.
The ISO contract verifies Firewalld, firewall-config and Qps; the Firewalld Dinit service boots in rootfs/livefs. The content gate rejects Portmaster, its exclusive dependencies, Gufw and UFW in both generic images.
A QEMU smoke captures two surfaces on default VGA and Virtio-VGA: OCR must read the fresh Pearl GTK4 setup window's `Dock` title, then the later Aqueous/Pearl session frame must contain a Pearl/Aqueous/DINX marker and reject Pearl Greeter, TTY consoles, login prompts, password/sign-in fields and visible Dinit failures. The first check catches a blank GTK client surface; the desktop check confirms session startup. Neither proves every application's rendering, VirtualBox boot, networking, audio or long-term service health.

Tagged releases reuse the same build artifact through `.github/workflows/release.yml`. The release job publishes either the ISO or ordered sub-2 GiB ISO parts, the full SHA-512, the Linux QEMU evidence and a small Windows launcher package. The launcher downloads the metadata-pinned HTTPS URL and, when required, each ordered part, verifies the parts and full SHA-512, then runs `scripts/smoke-iso.ps1` with QEMU on Windows. Its ZTASH metadata targets the registered `ddjarin` receiver without embedding credentials.

The livefs-only `dinx-live-autologin` package replaces `root-ro` and `early-root-rw.target` with no-ops for the already-writable overlay. Its boot preparation service sets the `dinxlive` hostname, provisions the private `/run/dinx-session` runtime directory, grants the disposable `dinx` account access to the live `seatd` service and waits up to five seconds for its socket. A separate restartable Dinit process service launches `dbus-run-session /usr/local/libexec/dinx-aqueous-pearl` as `dinx` through `runuser`; greetd is not in the live session path. The live overlay shadows greetd with a no-op service so existing Dinit dependencies remain satisfiable without starting a display manager. Calamares installs `rootfs.img`, so the installed system retains Artix's manual-login greetd service and its dedicated VT 7.
Artix's live `login.target` still starts agetty/autologin on tty1. The direct live compositor obtains its VT through seatd instead of competing for tty1 or depending on elogind session activation.

The live and greeter graphics wrappers share one profile policy. Each accessible DRM render node is associated with its own sysfs driver. QEMU `virtio_gpu` with a readable/writable render node selects `aqueous-cpu` and wlroots GLES2; GTK4 renderer selection remains automatic. VirtualBox `vmwgfx`/`vboxvideo` and systems without an accessible render node select full Aqueous with `WLR_RENDERER=vulkan` and `GSK_RENDERER` unset, matching Devario's Vulkan-only wlroots renderer policy; `vulkan-swrast` is packaged. QXL and other 2D adapters with a render node retain the CPU compatibility profile. The custom Pixman scene-buffer rounded-corner patches are removed. The current qualifier tests default VGA and Virtio-VGA; QEMU 11.1.2/KVM with `vmware-svga` stalls in early udev when `vmwgfx` loads and is not used as VirtualBox evidence. Direct VirtualBox validation remains required.

The profile owns the DINX visual contract at `/usr/share/dinx/theme/DINX.json`. `scripts/check_dinx_theme.sh` validates the static palette, `DINX_COLOR_SCHEME`, GTK/Qt bridges, Pearl Greeter, Calamares and GRUB before `buildiso`; `scripts/check-iso-content.sh` verifies the same files inside the root SquashFS image.
The profile overrides the upstream Artix GRUB theme at its package-compatible path `root-overlay/usr/share/grub/themes/artix/theme.txt`. The active theme uses DINX surface/text/primary colors, displays the new DINX gradient boot mark instead of the upstream logo, retains upstream icons and fonts, and omits opaque menu textures that produced a black panel on the graphical kernel-selection screen.

Devario's downloaded ISO has a text GRUB menu; its logo splash appears after kernel handoff through Plymouth. DINX keeps its two branded live choices and visible six-second GRUB timeout, then runs the Artix Plymouth package with the same DINX boot mark. The ISO kernel options include `quiet splash`, and the mkinitcpio hook inserts Plymouth after `udev`; a Dinit service quits the splash after the greetd boundary is reached—real greetd on installed systems, the post-preparation no-op shadow on the live image. No systemd/UWSM integration is added.

For local graphical capture, install QEMU, `socat`, `tesseract-ocr` and `tesseract-ocr-eng`, then set `DINX_QEMU_BOOT_KEYS=down,down,ret`, `DINX_QEMU_SCREENSHOT` and optionally `DINX_QEMU_SCREENSHOT_DELAY` before running `scripts/smoke-iso.sh`. `DINX_QEMU_PLYMOUTH_SCREENSHOT` triggers repeated captures for up to `DINX_QEMU_PLYMOUTH_WAIT_SECONDS` (default 30); OCR rejects the GRUB menu before checking centered DINX logo pixels. The configured waits must fit inside `DINX_QEMU_TIMEOUT`; full qualification allows a 120-second QEMU window, captures the timed default menu, then presses `ret` to make the default-entry boot deterministic.
Qualification writes `dinx-plymouth-screen.ppm` and `dinx-virtio-vga-plymouth-screen.ppm` beside the ISO. The first-run desktop capture waits 57 seconds to leave time for splash detection and the post-capture session check.
Without `DINX_QEMU_SCREENSHOT`, the smoke saves its checked frame beside the QEMU log as `<iso>.qemu.log.session.ppm`. `DINX_QEMU_OCR_LANG` selects another installed Tesseract language model when needed.

To request host-side virgl in a local graphical QEMU smoke, the host QEMU must support GTK/OpenGL and virgl:

```sh
DINX_QEMU_DISPLAY=gtk,gl=on \
DINX_QEMU_VIDEO_DEVICE=virtio-vga-gl \
scripts/smoke-iso.sh /path/to/dinx.iso
```

The current VirtualBox policy selects full Aqueous with `WLR_RENDERER=vulkan` for `vmwgfx`/`vboxvideo`; GTK4 selects its renderer automatically and `vulkan-swrast` remains packaged as a software Vulkan ICD. The source does not establish whether VirtualBox 3D acceleration must be enabled. Published Alpha 12 predates this renderer policy. QEMU's Virtio-VGA smoke verifies a separate live graphics path, not the VMware driver or direct VirtualBox boot; direct VBox validation still requires a fresh ISO.

Full qualification captures `dinx-boot-screen.ppm` three seconds after QEMU opens, then polls for the centered Plymouth logo and records `dinx-plymouth-screen.ppm` (and a Virtio-VGA counterpart). The validator rejects GRUB menu OCR and logos at the GRUB corner position. The graphical and post-session captures remain separate desktop evidence.

The profile also embeds an experimental offline Calamares path with DINX branding and dinit service modules; Pori is the only graphical storage UI, while Phyto is the default file manager. The content check asserts the installer configuration, static DINX palette/theme defaults, Pearl Greeter, the forced Aqueous/Pearl session and recovery payloads. `scripts/smoke-install.sh` now mounts `rootfs.img` read-only and copies it with the same rsync options as Calamares `unpackfs`, then checks BIOS/UEFI boot and recovery on disposable 16 GiB disks. This is a CI contract smoke, not a VirtualBox end-to-end installation.
The Calamares partition contract is checked before the container build: a 1 GiB recommended/64 MiB minimum EFI partition, FAT32 EFI and ext4/btrfs root restrictions, explicit manual partitioning, disabled LVM, live-mount exceptions, offline package removal, kernel `ntfs3` read/write support, optional post-install `ntfs-3g`, `os-prober` support and an explicit top-level Btrfs mount plan that does not recreate existing `@`/`@home`. `scripts/smoke_calamares_partitioning.sh` round-trips disposable BIOS and UEFI partition tables, filesystems and fstab data and reopens a Btrfs volume with existing subvolumes. `scripts/smoke_calamares_windows.sh` preserves an existing Windows-style FAT32 ESP/Microsoft boot path and NTFS partition while completing both side-by-side and manual-layout DINX root/GRUB transactions. These are supported-layout transaction smokes, not a claim that every Calamares filesystem, encryption, RAID, BitLocker, hibernation, Windows firmware or physical-firmware path is bug-free.

For a second diagnostic capture after boot, set `DINX_QEMU_POST_SCREENSHOT` and optionally `DINX_QEMU_POST_SCREENSHOT_DELAY`. Leave `DINX_QEMU_POST_KEYS` unset for the normal autologin path. A post frame proves only that QEMU rendered another point in the session.


## Latest published release run

Tagged release run [41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) for `v0.1.0-alpha.12`, on commit `56a814575e33bfae6215993972784f11b7dae215`, completed every workflow step successfully:

- package/profile and first-party contracts, including native application and package-provenance checks, passed before the Artix build;
- package builds and compact `buildiso` completed; ISO content, size and build-metadata/digest binding passed;
- Calamares partition transactions and QEMU boot/graphical-session capture using the default VGA device passed; this run did not exercise VMware-SVGA or VirtualBox VMSVGA;
- persistent-install, first-boot and recovery-TTY smokes passed on disposable BIOS and UEFI disks;
- the signed DINX repository, release preflight, SHA-512, GitHub provenance attestation and release publication passed;
- the published direct ISO is 1,836,830,720 bytes with SHA-512 `ac1dbd237e484f8d61aab5438185218b13d9e23824ce671440ff67ed275ce7073b90dbcc14bc8d8f7008b2422d66e2756f1b3a88a0d5c21d8c7bbc67c9d60bf9`; signed repository snapshot `37dfe99d5e4003e217e786ef82c8ea29562693db2d44b996a9624a68f31c490d`.

This closes the P4 DinitUI and disposable install/recovery path for the system-alpha gate. It does not prove authenticated Steam/game use, real DRM gaming output, controller/audio hardware, physical installation, firmware, upgrades, filesystem rollback, BitLocker/hibernated Windows resizing or long-term hardware health.

## Historical main P0 validation after Alpha 10

Run [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770) on main commit `bf773500965c843e014e3bc3ef8fea685e14b91b` passed the full P0 workflow, including package contracts, Artix build, ISO checks, QEMU graphical boot, Calamares transactions, persistent BIOS/UEFI installation, recovery TTY, metadata, attestation and artifact upload. This was an earlier post-Alpha-10 main validation; it neither exercised VMware-SVGA nor published or replaced the later Alpha 12 artifact from tagged run [41197618617](https://github.com/rufl/DINX/actions/runs/41197618617).

## Historical main ISO build before Alpha 10

Run [40637700291](https://github.com/rufl/DINX/actions/runs/40637700291) on commit `f01f372cc9c93283bbc2a33de24c27aced1428bf` passed the ISO build, QEMU and disposable BIOS/UEFI installation smokes. Its ISO was 2,065,172,480 bytes. This is historical comparison evidence; Alpha 10 qualification is documented in the published release run above.

## Earlier successful post-release `main` validation


Run [39934458077](https://github.com/rufl/DINX/actions/runs/39934458077) on `main` commit `eb9a0c143c06d9c1939f9d88684d164d8e2384fb` completed in 52m02s after passing the same package/profile contracts, compact ISO build, QEMU boot and graphical payload checks, BIOS/UEFI persistent-install and recovery-TTY smokes, provenance attestation and artifact upload. This is validation evidence only; it did not publish a new release.

## Earlier observed successful run

Run [38471629482](https://github.com/rufl/DINX/actions/runs/38471629482) on commit `6224b58` passed all workflow steps in 6m02s:

- ISO artifact: `artix-dinx-dinit-20261013-x86_64.iso`;
- size: 1,497,237,504 bytes;
- SHA-512: `adcd6cba882b368725ffa02d33e8a2ae17c3be1b9ffaa17692dbd9eb895689bb0a686530f1012a11f6d262ef2d9ab859d27c2995393aa1ded4cd50d4af42433c`;
- QEMU smoke window: 90 seconds, passed;
- payload check: legacy shell, ReGreet, greetd and dinit payloads present;
- graphical capture: this historical pre-Aqueous/Pearl frame showed the ReGreet user/session selector, and the post-input frame showed the graphical user session with the legacy shell welcome screen; this evidence predates the current session cutover;
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

The development host is EndeavourOS x86_64. The Artix `buildiso` toolchain runs only in the digest-pinned container; do not install Artix build packages or `mkinitcpio` on the host. The local build requires an accessible rootful Docker Engine with privileged-container and loop-device support.

## Local Docker build

Run from the DINX checkout:

```sh
bash scripts/build-iso-docker.sh
```

If the ignored Deetty archive is absent, the script prepares it from a checkout at the pinned upstream commit. Set `DEETTY_SOURCE_CHECKOUT` to that checkout; the commit and generated archive SHA-256 are verified.

```sh
DEETTY_SOURCE_CHECKOUT=/path/to/DEETTY bash scripts/build-iso-docker.sh
```

The Deetty package build clears its cached source tree before applying patches. A failed build therefore cannot leave patched source that breaks the next retry.

Local builder-image creation retries up to twice (three attempts total) only for BuildKit's transient `forwarding Ping: no such job` gateway error, with a three-second delay between attempts. Other builder-image failures stop immediately.

Requirements: a reachable rootful Docker Engine, `--privileged` and loop-device support, network access, and enough free disk for the temporary rootfs and ISO. The local build runs the same full qualification as P0 by default. It also requires the commands listed by `scripts/check-iso-qualification-host.sh full`, QEMU with the `virtio-vga` device, Tesseract's `eng` model, OVMF firmware, and `sudo` (or root). Check prerequisites before starting:

```sh
scripts/check-iso-qualification-host.sh full
```

The local builder reuses verified artifacts under `dist/.cache/dinx`: pinned Zig toolchain archives, pacman package archives, makepkg source downloads, Cargo registry data, per-package Cargo build outputs, Zig's global cache and content-addressed DINX package archives. A package-cache key covers that package's source inputs, builder/cache implementation, makepkg configuration/options, installed package set and explicit build environment; generated package and compiler outputs are excluded. Cached archives are checksum-checked, then signed with the current build's repository key. Only successful `makepkg` outputs are published atomically. The first run is cold; later runs can skip unchanged package builds. The P0 workflow saves its verified archive cache only after full ISO qualification; the contracts workflow restores that cache read-only when available. Package-repository staging, rootfs and final ISO are still produced and qualified on every build; only individual DINX package archives are reused.

Static-only mode is explicit and **does not** qualify boot or installation:

```sh
DINX_ISO_QUALIFICATION=static bash scripts/build-iso-docker.sh
scripts/qualify-iso.sh --static /path/to/dinx.iso
```

For build debugging only, `DINX_SKIP_POSTBUILD_CHECKS=1` skips all ISO qualification. That output is unqualified; run `scripts/qualify-iso.sh` in full mode before using or publishing it.

To rerun the same full gates on an ISO with `build-metadata.txt` beside it:

```sh
DINX_EXPECTED_COMMIT=$(git rev-parse HEAD) scripts/qualify-iso.sh /path/to/dinx.iso
```

`DINX_LOCAL_BUILD_DIR` selects a new, empty output directory under `dist`; existing results are never overwritten. `DINX_BUILD_CACHE_DIR` selects a different cache directory under `dist`.

The builder emits `dinx-build-timing` for package builds, including `cache=hit` or `cache=miss`, builder pacman setup, ISO assembly and total container time. Compare equivalent logs before claiming a time reduction; warm package-cache hits avoid rebuilding unchanged DINX packages, while download and Cargo caches can reuse their respective inputs/outputs. Local `scripts/qualify-iso.sh` writes QEMU logs and PPM captures beside the ISO.

On container exit, the builder stops the temporary package-repository server and restores host ownership of the ISO, package, build-tree and mounted package-source directories. The P0 checksum step and local post-build checks can then write to their output directories.

Local post-build validation uses the commit and source-tree baseline captured before Docker starts. Generated makepkg trees, package archives and staging outputs are excluded from the source fingerprint; changes to tracked or untracked source inputs still fail validation.


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
