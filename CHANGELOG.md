# Changelog

This file records meaningful DINX changes in direct language. It does not claim that the roadmap is complete; the linked qualification evidence and release metadata are the source of truth.

## Unreleased
- Maximize ISO SquashFS compaction with xz, x86 BCJ, 1 MiB blocks and a 1 MiB dictionary (the largest SquashFS values supported by the builder); retain the mksquashfs XZ tool default because it exposes no compression-level control. Metadata and ISO qualification now verify the new settings.
- Include `jq` in the Artix builder image: `check_dinx_theme.sh` needs it to verify Pearl's dark-theme defaults before ISO assembly, and builder provenance contracts now require it.
- Trim the generic rootfs package set: remove the unused standalone ISC DHCP client (NetworkManager defaults to its built-in DHCP client), eCryptfs utilities, legacy exfat-utils (retain exfatprogs), BIOS-only Memtest86+ absent from DINX's two-entry boot menu, NFS-root initramfs tools, NBD tools, unconfigured s-nail mail delivery and Zsh (Fish remains the default). No DINX service or launcher depends on these packages; Artix packages remain installable later.
- Remove `libva-utils` and legacy `net-tools` from the ISO. Keep `libva` for VA-API applications and `iproute2` for network management; no DINX helper or profile contract uses `vainfo`, `ifconfig`, or `netstat`. Only those diagnostic/legacy commands are omitted.
- Replace Firefox with the checksum-pinned official Floorp x86_64 release, make it the default web handler and move policy/update ownership into the DINX package-source refresh. Restore OpenSnitch for live and installed systems: enable its daemon through Dinit, autostart the UI in the session tray, and retain its upstream nftables default-allow behavior alongside Firewalld.

- Configure weekly reviewed upstream source-pin PRs for 21 custom package sources, including a monthly-refreshed Noto Latin subset; publish signed packages through the GitHub Release tag `dinx-packages-latest` and configure `dinx-keyring`/Shelly pacman integration. The workflows remain unverified until required production signing secrets are configured and a publication run succeeds.
- Replace the `vlc` and `vlc-cli` ISO selections with Haruna 1.9.0, built from checksum-pinned KDE source and refreshed through weekly source-pin PRs. Publish Haruna in the signed DINX package repository and make it the default video handler; pacman resolves the new dependency graph without retaining packages used only by VLC.
- Add the Papirus and Qogir icon themes to the DINX live and installed package roster; keep Adwaita as the initial icon-theme selection.
- Replace Portmaster with Firewalld and firewall-config. Install Artix's `firewalld-dinit`, enable it in both live and installed root filesystems, remove Portmaster and its exclusive runtime dependencies, and expose firewall-config in the app menu and DINXPanel.
- Replace Artix's full `noto-fonts` package with `dinx-noto-latin`. The five Latin-subset fonts provide both `noto-fonts` and `ttf-font`, satisfying Calamares' hard dependency through `plasma-integration` without the upstream package's 106.8 MiB installed payload; ISO qualification now requires the subset files and rejects full-package metadata.
- Add Krita, Inkscape, Godot, Impasto, Patchy and Blockbench to the live and installed rootfs application roster; pin and checksum the Impasto/Patchy/Blockbench AppImages and complete license notices, preserve the AppImages byte-for-byte, launch them without requiring FUSE, and require the graphics apps in the ISO content gate.
- Exclude unused Artix Calamares extension payloads from the ISO: the alternate basestrap module, Artix branding/slideshow trees and configuration switcher. Retain the DINX branding plus the `services-artix` and `postcfg` modules selected by the installer.
- Add Pixelorama 1.2.4, the official Linux x86_64 pixel-art and animation editor, to the live and installed application roster. Pin the release archive, MIT license, icon and `.pxo` MIME definition by SHA-256; add an executable launcher, visible desktop entry and ISO package/content checks, and refresh all upstream pins through the weekly reviewed package updater.
- Add the official Zrythm v2.0.0-alpha.7 AppImage and ONLYOFFICE Desktop Editors 10.0.0 to live and installed DINX. Keep both upstream AppImages byte-for-byte, attach their licenses, and expose ONLYOFFICE document, spreadsheet, presentation and PDF MIME types. Zrythm v2 is pre-release; ONLYOFFICE's integrated app also retains Forms and Diagram Viewer. The combined payload makes the ISO exceed 2 GiB, so tagged-release delivery uses the existing split-image path and cannot refresh the single-file rolling alias.
- Remove Zathura and its MuPDF backend, including libmupdf; ONLYOFFICE becomes the default PDF handler. The ISO gate rejects breeze-icons, Zathura, its backend and libmupdf package metadata from both rootfs and livefs.
- Replace KolourPaint with Impasto, a source-pinned AppImage with bundled GTK, no-FUSE launch support and all upstream MIT/LGPL/third-party notices. Pacman resolves the profile from remaining application dependencies, dropping dependencies used only by KolourPaint while retaining shared libraries.
- Disable Aqueous backdrop blur and window opacity only when seeding a fresh live Pearl user's config; preserve saved user settings.
- Apply DINX semantic dark/light colors to the Pearl GTK4 first-run wizard and update its preview when the theme changes; keep Pearl's work-area reservation on the selected bar edge.
- Brand the CLI login banner as DINX Linux; reduce the live GRUB menu to the default DINX entry and a UEFI firmware option with a visible six-second countdown.
- Grant passwordless Polkit authorization to the active local `dinx` user in the livefs only; installed systems retain normal authentication.
- Keep the live ISO recoverable after inactivity: blank displays through `wlopm`, wake them on activity/resume, and deny session locking; preserve installed-system locking.

- Draw Aqueous titlebars above client content and extend the continuous rounded frame around titlebar and client surfaces. Double-clicking the titlebar toggles maximize/restore; restore returns the saved floating geometry, keeps focus, and raises the window. Pearl's `window_corner_radius` applies at the next Vulkan-effects Aqueous session; CPU-compatibility rendering remains square.
- Default GNOME/libadwaita to dark mode only when dconf has no explicit user choice; honor xdg-decoration CSD requests and XWayland Motif CSD hints so client-owned titlebars do not overlap compositor titlebars, content offsets or controls.
- Hide the upstream Artix Calamares desktop entry and run `Install DINX` through a Wayland/D-Bus-preserving polkit helper with visible startup errors; seed an `Install DINX` desktop shortcut for the live user and new installed users.
- Include `squashfs-tools` in the live rootfs because Calamares `unpackfs` requires `unsquashfs`; remove the installer-only dependency from the installed system and verify both sides in ISO and install-smoke checks.
- Launch Gapless directly so it inherits the live Wayland environment; route Gufw through a helper that resolves its pkexec executable consistently; show a localized diagnostic when Bluetooth is unavailable, including VirtualBox USB passthrough guidance.
- Force Firefox's GTK system-decoration mode on Wayland to prevent duplicate client window controls; extend server-decorated Aqueous surface masks through the compositor titlebar so client top edges stay square within one rounded outer silhouette.
- Keep `linux-headers` in the Artix build root through initramfs generation, then remove it transactionally from staged root filesystems before SquashFS creation; verify the final ISO package databases and record the omission in build metadata.


- Use canonical `rufl/DEETTY` source access with an optional `DEETTY_SOURCE_READ_TOKEN`, and rename Deetty smoke/qualification executable outputs, fixture markers and isolated-display test variables; upstream module, ABI, config and resource identifiers remain pinned source internals.
- Make the Deetty SQLite TUI qualification prompt deterministic across SQLite shell versions; the test no longer depends on SQLite's version-specific default prompt.
- Keep the Deetty man-page qualification fixture filename consistent with the test input so `man` opens the page and reaches the pager.
- Publish the generated Deetty source archive as mode `0644`, so non-root checks and builds can read it after root preparation.
- Include declared external package inputs in package-cache keys, so a source license or boot-mark change invalidates the consuming package artifact.
- Record Artix sync-database hashes, the Deetty source-pin file hash and source-tree fingerprint in build metadata; wait for the signed package server before ISO assembly and require one ISO with adjacent metadata.
- Preflight disk space/inodes for build outputs, caches, chroots and Docker storage; probe privileged loop attachment, preserve non-empty custom chroots on failure, and reject malformed post-build-skip flags.
- OCR-check the installed recovery TTY and document that the BIOS/UEFI smoke simulates installation from the rootfs rather than exercising Calamares end to end.
- Match required installed-rootfs and livefs paths against exact fields in SquashFS long listings; metadata columns previously made valid ISO files appear missing.

- Bundle Artix Intel firmware for `i915`/`xe` and install a backed-up `FONT=ter-124n` console configuration with the Plymouth package; verify the firmware files and selected font in the built rootfs.
- Default Pearl Greeter's libseat backend to elogind for greetd sessions under dinit, while preserving an explicit backend override.
- Stop the ZLS Zig shim's `version` branch before optional compiler delegation; the installed rootfs can report its pinned Zig version without the optional `zig` package.
- Poll QEMU frames until the centered DINX Plymouth logo is visible, reject GRUB-menu captures, and reserve time for session screenshots within the boot timeout.
- Force the installed-initramfs listing smoke to use the C locale, avoiding non-fatal `bsdcpio` locale warnings.
- Use one full ISO qualifier for local builds and P0 CI: metadata, checksum, payload and budget checks; default-VGA and Virtio-VGA QEMU captures; and disposable BIOS/UEFI install smokes. Full local qualification runs by default; static-only is not boot evidence. QEMU 11.1.2/KVM with `vmware-svga` stalls in early udev while `vmwgfx` loads; the test now avoids that emulator path rather than mislabel it VirtualBox evidence. Direct VirtualBox and physical hardware remain unqualified.
- Recognize the Arch `edk2-ovmf` 4 MiB firmware paths for full host checks and UEFI install smoke, avoiding a false missing-OVMF failure when the package is installed.
- Persist local pacman, makepkg-source, Cargo-registry, per-package Cargo-target and Zig global caches; combine pacman's database refresh and upgrade. Skip ownership walks over disposable chroots and same-UID source/cache trees. End QEMU qualification after required screenshots and installed first-boot checks instead of waiting for fixed timeout windows; all existing boot, screenshot, package and installation gates remain required.
- Cache DINX package archives locally by source and build-environment hash; validate cached archives, sign hits with the current ephemeral key, and publish artifacts only after successful `makepkg`. The first build remains cold.
- Initialize each package build's timing state before invoking `makepkg`, preventing `nounset` from aborting the ISO build after a package completes.
- Make Cargo-built packages honor the per-package `CARGO_TARGET_DIR` cache during packaging; Cyan Skillfish, Matugen and Shikane now install binaries from the same target directory used by Cargo.
- Drop the persistent-install smoke marker's live-session dependency on `early-root-rw.target`; the disposable installed root boots from writable ext4, so this remount ordering is not needed.
- Put the DINX GRUB templates in the live overlay consumed by Artix `prepare_grub`; previously they landed only in the root filesystem, so the ISO silently kept Artix's indefinite menu. The ISO now boots the first DINX option after a visible six-second timeout.
- Add a DINX-branded Plymouth splash during kernel handoff: reuse the canonical boot mark, include the Plymouth hook after `udev` and `quiet splash` in the live GRUB kernel arguments, and quit via a Dinit service after `greetd` starts. VGA and Virtio-VGA qualification captures the splash separately; no systemd/UWSM integration.
- Inspect both CPIO layers of Artix mkinitcpio images during ISO qualification. The raw early archive contains kernel modules; Plymouthd and its DINX payload are in the appended Zstandard archive. QEMU capture gates exercise the splash-to-Dinit/greetd handoff.

- Use Pearl Material dark as the fresh-session and first-run default; keep GTK application defaults on Adwaita and preserve existing user theme choices.
- Bump Pearl to `pkgrel=5` and refresh the pinned first-run wizard checksum for the Material default.
- Set and persist the live-session hostname as `dinxlive` before greetd starts. Apply DINX branding to live and installed GRUB menus, replacing the old boot mark with the new DINX gradient mark.
- Declare `local.target` and `artix-live` as separate Dinit dependencies for live autologin, so both services resolve instead of being parsed as one missing service.
- Ensure the Aqueous/Pearl session exports a UTF-8 character locale when its inherited locale is ASCII, so terminal applications such as `btop` render correctly without overriding valid user locales.
- Remove a failed Dome build's partial source/cache before retrying, and restore bind-mounted files to the invoking user when the local ISO builder runs through sudo.
- Pin local post-build metadata checks to the commit and source-tree baseline captured before Docker starts; exclude generated makepkg trees, package archives and staging outputs from that fingerprint while still rejecting changed source inputs.
- Initialize the ISO content checker's GTK settings from the user skeleton before checking theme defaults.
- Ignore empty compatibility directories in SquashFS manifests while continuing to reject files and symlinks from retired desktops and init systems.
- Set `DownloadUser = root` only in the temporary Artix `buildiso` pacman config. Pacman 7's `alpm` downloader cannot write the root-owned sync-database staging directory in a fresh basestrap target; host pacman and the installed image remain unchanged.
- Remove only DINX repository package archives and detached signatures from pacman's shared cache before ISO assembly, preventing signatures from an earlier ephemeral CI key from invalidating the current local repository. Initialize the pacman keyring before importing and locally signing that repository key.
- Provision system groups with `esysusers` before creating the installed-smoke user and Pearl Greeter; make Pearl declare the install-hook tool as a runtime dependency and bump `pkgrel` to 6.
- Replace the ignored synthetic Dinit marker service in installed-system smoke with checks against actual NetworkManager, elogind and local-target boot output; keep installed payload and recovery checks on disk.
- Delay QEMU boot-menu input by three seconds and capture the pre-key GRUB screen, matching the successful default-VGA smoke.
- Remove DINX's custom Pixman scene-buffer rounded-corner patches and stop routing VirtualBox `vmwgfx`/`vboxvideo` or systems without an accessible DRM render node through `aqueous-cpu`; use the full Aqueous binary with `WLR_RENDERER=vulkan` and `GSK_RENDERER` unset, matching Devario's Vulkan-only wlroots renderer policy. QEMU `virtio_gpu` keeps reduced-effects GLES2, and QXL/other 2D adapters retain the CPU compatibility profile when a render node is present. VirtualBox client-surface behavior still requires a fresh-ISO smoke.
- Extend QEMU VGA and Virtio-VGA smoke checks to OCR the Pearl GTK4 first-run window's `Dock` title before accepting the later desktop screenshot; catches blank client surfaces that a wallpaper/panel-only check could miss.
- Install Shikane profile-save cleanup before creating scratch files; its smoke forces the second `mktemp` to fail and verifies no temporary profile files remain.

- Validate Pearl Settings form values before publishing drafts, keeping invalid intermediate input editable instead of corrupting the JSON draft. Remove the Settings client-side headerbar to avoid duplicate compositor decorations and make GTK-theme windows opaque. Pearl border synchronization affects colors only; `aqueous-cpu` keeps square corners until Vulkan effects are available.

- Stop forcing GTK4's Cairo GSK renderer in CPU/Pixman and virtual-GL sessions; leave renderer selection to GTK4 while keeping Aqueous's compositor renderer profile-specific. This addresses blank client surfaces reported in VirtualBox; actual VirtualBox verification is still required. The first VMware-SVGA boot smoke exposed the initramfs omission of `vmwgfx` and `vboxvideo`; `build-iso.sh` now adds both to a private Artix initramfs helper copy and ISO inspection verifies them. The current QEMU/KVM VMware-SVGA test hangs during early udev with `vmwgfx` loaded, so P0 uses Virtio-VGA instead; neither path qualifies direct VirtualBox boot.
- Repair the `dinx-live-autologin` source checksum and bump `pkgrel` to 7. The stale checksum stopped an earlier P0 run before ISO composition; a later run built the first ISO with the graphics fallback and exposed that Artix had omitted `vmwgfx` and `vboxvideo` from its generated initramfs.

## DINX v0.1.0-alpha.12 — 2026-10-31

- Published from `56a814575e33bfae6215993972784f11b7dae215` after release workflow [#41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) passed ISO build, QEMU graphical boot, Calamares transactions and persistent BIOS/UEFI installation and recovery checks. The 1,836,830,720-byte ISO is below GitHub's 2 GiB asset limit; `alpha-latest` now points to this release with the matching SHA-512 checksum.
- Alpha 12 advances DINX's live-first goal: the live image opens Aqueous/Pearl without a credential prompt; Calamares offers guided and manual install paths with optional swap; the default desktop uses floating, decorated windows with titlebar controls and edge/corner snapping; and the base includes everyday file, archive, partition, storage, display and media tools. The runtime remains dinit-only, without systemd or UWSM. It is an experimental x86_64 image, not a claim of broad hardware support.
- Fixed tagged-release alias failures caused by GitHub's delayed release visibility. The publisher retries transient 404s for release metadata, assets and alias uploads with a fixed limit, waits for the release listing to catch up, prevents stale alphas from rolling back the alias, and reports stage-specific failures; fixture smokes cover recovery and exhaustion.
- Restored the DinitUI and DINXPanel Zig sources required by their in-tree packages; their removal made clean CI checkouts fail source contracts and left package builds without their entry points.

- Made ISO validation independent of the upstream Calamares desktop name; it now requires the package entry and verifies the same-ID DINX override hides it, leaving only the Install DINX launcher visible.
- Alpha 12 attempted to fix the Alpha 11 VirtualBox VMSVGA login loop by requesting and checking GLES2 + Vulkan in the wlroots recipe; `libglvnd` supplies EGL/GLES2 dependencies. The published guest still reports GLES2 disabled at compile time when VMSVGA selects it, so the desktop can return to the greeter. Release CI verified QEMU graphics only; direct VirtualBox boot remains unqualified.
- Added a rolling direct-download alias and matching SHA-512 checksum for the latest alpha ISO. The tagged release workflow refreshes it, and both GitHub landing pages link to it.
- Fixed the P0 ISO build failure caused by omitting the pinned Gapless package from the signed local repository. The Artix builder now installs Vala and GStreamer build dependencies, packages Gapless before composing the rootfs, and checks this wiring in the provenance contract.
- Made local package installation retry after refreshing pacman databases when mirror metadata drifts. Preserved checked-in Zig sources by skipping `makepkg --clean` for DinitUI, DINXPanel and Seafoam Settings; added a recovery smoke.
- Fixed the Artix builder's EXIT cleanup to stop the temporary package-repository server and restore host ownership of ISO and package outputs, allowing checksum generation and local post-build checks to write to the mounted directories.
- Updated the ISO graphics payload checks to the Mesa DRI filenames actually shipped in the built image (`virtio_gpu_dri.so` and `vmwgfx_dri.so`). The previous `virgl_dri.so` and `svga_dri.so` names caused a false missing-file failure despite both required virtual-GPU drivers being present.
- Removed the ISO-content expectation for a Dintor 128×128 PNG the package does not install; its scalable SVG is the packaged icon.
- Matched the QEMU kernel-module check to the packaged `virtio-gpu.ko.zst` filename; the module was present, but the underscore spelling made verification report it missing.
- Preserved Aqueous' full patched WM defaults in the ISO; a three-line root overlay had replaced them, dropping Deetty and the layout-shortcut disables. The package patch now sets Deetty while keeping freeform `stacking` as the default.
- Corrected P0 contract checks to verify Seafoam/ZLS smokes and builder-only Gamescope qualification in the Artix container builder, rather than expecting those steps in the host workflow.
- Pinned Shelly's AUR desktop/config payload to immutable revision `f89d773125357baaa1d2fae715286ce9e00e2cb4`; the mutable `shelly-bin` branch had changed `shellybuild.conf`, causing the ISO package build's existing checksum verification to fail.
- Make the Deetty package build discard its previous source tree before patching, so failed builds cannot make retries apply file-creation patches to already-modified sources.
- Updated both upstream Dintor task-probe and clangd LSP smokes to invoke the renamed `dintor` binary; the package integration contract rejects stale `nocted` executable paths.
- Added `scripts/build-iso-docker.sh`, which runs the same digest-pinned privileged Artix container builder used by P0 CI, generates the ignored Deetty/Dintor archive from a local checkout at the pinned public NOCTTY commit when needed, and emits local source-bound metadata and an ephemeral-key package bundle.

- Fixed P0 push-trigger coverage for the Docker/container build entrypoints and restored host ownership of bind-mounted package sources after the Artix builder exits. P0 and contracts runs check out the pinned public NOCTTY source with the workflow's built-in `GITHUB_TOKEN` and generate its ignored archive; the contracts workflow now runs these source-dependent checks on fork PRs too. No extra Actions secret is needed.

- Seed fresh Aqueous outputs with two workspaces instead of the upstream nine-workspace startup set.

- Added graphics profiles for QEMU `virtio_gpu`/virgl and VirtualBox VMSVGA (`vmwgfx`). Alpha 12 initially selected GLES2 for both when render nodes were accessible; its published runtime exposed the VirtualBox GLES2 build gap. Current source routes `vmwgfx`/`vboxvideo` and systems without accessible DRM render nodes through full Aqueous with `WLR_RENDERER=vulkan` and `GSK_RENDERER` unset, while QEMU `virtio_gpu` retains reduced-effects GLES2. The live user, Pearl Greeter and new installed accounts receive `render` access; no systemd packages or services are added.

- Export `GTK_CSD=0` from the Aqueous/Pearl session and request server-side decorations so standard GTK and protocol-capable Wayland apps use the compositor titlebar. Document the remaining boundary for apps that hard-code custom client-side chrome.

- Run the non-privileged DINX contracts and REUSE workflow on every pull request and every push to `main`, including documentation and license-only changes. Keep the privileged ISO build on its selected build-related triggers.

- Corrected the Beta 0.1 ISO gate to GitHub's actual per-file release limit: strictly below 2 GiB, with no arbitrary 1.8-billion-byte target. Alpha 12 is 1,836,830,720 bytes and remains below the cap.

- Complete REUSE coverage for the GPL-3.0-only DINX decoration helpers and exclude the retained local Aqueous source checkout from project scans.

- Updated the English and pt-BR GitHub landing pages to use the DINX Linux wordmark already shipped in the ISO branding assets.

- Made Deetty the sole terminal emulator in the live ISO and fresh installation; DINX shell defaults, Aqueous terminal action and DINX launcher calls target it directly. Nano remains the recovery editor. The ISO ships only `ghostty-vt-runtime` (VT library, headers and license); full Ghostty is builder-only and removed before ISO assembly.

- Renamed the DINX-owned terminal/editor package and applications to `deetty` (Deetty) and Dintor, including the `dintor` command, `DINTOR_THEME`, desktop IDs `org.dinx.Deetty` / `org.dinx.Dintor`, package path and qualification-script names. The pinned upstream remains NOCTTY at its existing URL, commit and checksum; archive provenance and internal source paths are unchanged.

- Added concise launcher names: Dintor is labeled “Editor” in the default and pt-BR desktop entries; Seafoam Settings, DINXPanel and File Roller use “Ajustes do Desktop,” “Central de Controle” and “Descompactador” in pt-BR. File Roller’s localized desktop-ID override and MIME cache live under `/usr/local/share`, outside package-owned files, preserving the label and archive associations across package upgrades.

- Set the Gufw and Qps launcher labels to “Firewall” and “Process Manager” in English, and “Firewall” and “Processos” in pt-BR. Their executable commands remain unchanged.

- Set the OpenSnitch launcher label to “Traffic Monitor” in English and “Monitor de Tráfego” in pt-BR. Its `opensnitch-ui` command and upstream autostart metadata remain unchanged; the System category prevents duplicate menu placement.

- Standardized English and pt-BR launcher labels for the base desktop apps. File Roller now appears as “Archive Manager” / “Descompactador” without changing its archive MIME handling. Hid the package-provided Artix Calamares alias; the DINX `Install DINX` / `Instalar DINX` entry remains the sole installer shortcut.

- Replaced Strawberry with Gapless (G4Music) in the base ISO. DINX builds pinned upstream v4.6.2 as a signed `gapless` package, includes GStreamer base/good codec support, enables gapless playback by default, and assigns common audio MIME types to Gapless.

- Added Galculator, a compact GTK 3 calculator from Artix's signed `world` repository, to the base desktop roster. It uses the existing GTK stack and adds no separate GUI toolkit.

- Set DINX dark as the system GTK 3/4 default and export GTK/Qt6ct theme selection from the direct Aqueous session launcher. Existing user homes receive the Qt6ct DINX configuration and palette when missing.
- Seed fresh Aqueous user profiles with floating `stacking` on every workspace. The shipped WM config disables the default tile, scrolling, monocle and grid shortcuts (`Super+T/F/M/G`); `Alt+Shift+F` selects stacking and `Super+Shift+Space` toggles floating per window. Dragging a floating window to the left/right/bottom edge snaps it to a half, corners to quarters, and the top-center edge maximizes it (24 px threshold, no gap). Existing user configs remain untouched.
- Give Aqueous top-level windows a compositor-drawn DINX titlebar with minimize, maximize/restore and close controls, including GTK and Pearl clients. Long titles ellipsize before the controls. Dragging an unobstructed part of the bar moves the window and uses the floating snap behavior; double-clicking that titlebar area minimizes it; fullscreen hides the bar. Client-drawn chrome within the top 36 logical pixels can be obscured.
- Fixed stale Aqueous titlebar text when Wayland or XWayland clients change their title. The Aqueous/Pearl gate now applies DINX patches to the pinned upstream source, tests titlebar hit zones and floating snap geometry, and asserts title notifications invalidate the text cache.
- Added a one-time Pearl setup wizard for dock visibility, top/bottom bar placement and DINX dark/light or Pearl Material dark/light themes. Selections persist in the user's Pearl preferences.

- Added the reduced D-and-ray symbol as a transparent canonical SVG at `design/brand/dinx-ray-mark.svg`; GRUB uses its RGBA rendering and Calamares uses it as the product icon. Pearl Greeter and the initial desktop now use solid backgrounds without a wallpaper image or DINX logo; Calamares retains the full wordmark on its logo/welcome surfaces. Upstream/Adwaita app and desktop icons remain unchanged.
- Replaced the first ASCII approximation with a density-mapped rendering of the DINX D-ray source SVG. The plain-ASCII asset works with Fastfetch and Areofyl's optional `fetch` custom-logo format.

## v0.1.0-alpha.10 — 2026-10-29

- Published [v0.1.0-alpha.10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10) from commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e` via [release workflow 40879223746](https://github.com/rufl/DINX/actions/runs/40879223746). The direct ISO is 1,862,772,736 bytes with SHA-512 `5f49a65eac1481c01555a8f44b049c9a06e75ec7270ac3cdef97cc5e0b051d4b3c48a200542a36ec1832700accbc5509e3c314726c2f747530095eba4112219a`; signed package repository snapshot `b0015a0655d7d56a4949731d1a4f33cb2cc8daa55d4ec77df6d1a22161d2f5fd`.

- Moved Gamescope, Steam, GameMode, MangoHud, Steam device rules and 32-bit gaming libraries out of the base ISO into optional post-install packages. The base keeps 64-bit RADV/Vulkan; P0 no longer enables `[lib32]` during ISO assembly. ISO checks reject game binaries/package metadata in both rootfs and livefs. The published Alpha 10 direct ISO is 1,862,772,736 bytes.

- Removed the BC-250 governor, dinit service and Control Center from generic live and installed roots. Their pinned packages remain in the signed DINX repository; the documented install command is gated on PCI `1002:13fe`.

- Added a bilingual Calamares install-choice page before partitioning. It explains whole-disk erasure, supported alongside installs, partition replacement and manual layouts; destructive choices remain unselected, and swap stays optional with no swap as the default.

- Changed the local guidance smoke to render the QML page with Qt Quick on Arch-based hosts. EndeavourOS's Calamares fork omits `notesqml` and Artix-specific modules, so full installer integration remains verified by the Artix ISO build.

- Fixed the live desktop's missing XDG Desktop directory warning: the Aqueous/Pearl launcher runs `xdg-user-dirs-update` before the compositor, creating the standard directories for fresh live and installed accounts.

- Fixed the latest P0 livefs transaction conflict: `dinx-live-autologin` no longer packages a duplicate `/etc/dinit.d/greetd`; its boot-enabled Dinit service orders the one-time session-config writer before greetd and `login.target`, leaving the upstream `greetd-dinit` service file intact.
- Fixed an intermittent UEFI persistent-install smoke failure: the first-boot marker now waits for Dinit's `early-root-rw.target` before writing under `/var`. The failed run exposed the marker/root-remount race; the fix passed both firmware modes in main P0 run [40870759044](https://github.com/rufl/DINX/actions/runs/40870759044). The tagged Alpha 10 release was subsequently validated and published by [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746); physical hardware qualification remains separate.
- Fixed the Alpha 10 livefs payload check to validate the greetd service and boot symlink at their exact manifest paths. The corrected check and the BIOS/UEFI install, metadata and provenance gates passed in main P0 run [40870759044](https://github.com/rufl/DINX/actions/runs/40870759044); tagged workflow [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) published the validated ISO.
- Strengthened the QEMU ISO smoke: it captures and OCR-checks the selected live-session screen, accepts the Pearl panel's desktop/clock/layout markers when no product name is visible, and rejects the greeter, TTY, login prompts, missing XDG Desktop directory and visible Dinit failures. P0 installs Tesseract with English data for this gate.
- Kept Mesa Lavapipe (`vulkan-swrast`) in the base ISO for Vulkan applications, but stopped forcing it for Aqueous: QEMU and no-render-node sessions use the Pixman compatibility compositor instead of the failing llvmpipe presentation path.

- Reduced unused base payload: removed standalone DHCP client, legacy eCryptfs, duplicate exFAT tools, BIOS-only Memtest, NBD client utilities, optional mail client, Zsh, and NFS-root initramfs helpers. The live image retains `exfatprogs` and NetworkManager's built-in DHCP client; NFS-root boot is not configured. Removed `squashfs-tools` from the installed root only; the live root keeps it for Calamares `unpackfs`, and the builder keeps its own copy. Also deduplicated the feature-group inventory's `udisks2-btrfs` entry.
- Hardened the Artix builder contract: the pinned image digest is asserted before package/build work, forwarded explicitly into the container, and recorded safely in build metadata.
- Closed the absolute-path compression gap: CI preserves the real `mksquashfs` binary, installs the DINX wrapper at `/usr/bin/mksquashfs`, and the post-build ISO check verifies that both rootfs/livefs superblocks are xz-compressed with 256 KiB blocks. The wrapper also rejects self-recursion.
- Made the privileged `mksquashfs` wrapper check tolerate Artix's `/usr/sbin` symlink while still resolving the installed command to the DINX wrapper, avoiding a false CI failure before ISO assembly.
- Stabilized Artix package retrieval with two official HTTPS mirrors selected from the current mirror inventory, rejecting an empty active list and recording the source label/hash in build metadata so stale or removed mirrors do not break rootfs assembly.
- Kept the sole-session contract intact despite Artix Calamares' indirect Plasma integration dependency: CI excludes the package's `plasma.desktop` entry from both rootfs and livefs, so Pearl exposes only Aqueous/Pearl while Calamares remains available.
- Replaced the former ReGreet login path with Pearl Greeter: greetd launches `/usr/lib/pearl/pearl-greeter-host` as the dedicated `pearl-greeter` account. Power actions remain dinit-safe absolute wrappers, and the ISO rejects additional sessions.
- Added an ISO-content guard for the livefs itself: `AUTOLOGIN=true`, the dinit autologin service/link, the Aqueous/Pearl command and the `dinx` live user must all be present, while livefs systemd/uwsm payloads are rejected.
- Reduced the full-image payload with a repository-owned compact common manifest: the documented AMDGPU path remains included, generic firmware and `powertop` are omitted from final images, and kernel headers remain only for ISO initramfs generation while their source tree is excluded from final SquashFS.
- Made Aqueous + Pearl the only selectable and live-initial user session; removed Labwc, Noctalia and the ReGreet package from the base payload. Pearl Greeter is the installed/manual login UI.
- Added Phyto as the default native file manager and Pori as the only graphical disk/mount manager. Pori discovers devices through UDisks2 and persists mounts as dinit services under `/etc/dinit.d`.
- Restored File Roller for graphical archive open/create/extract actions and GParted for standalone partition editing, while retaining the removal of Thunar, GVFS, Tumbler and KDE Partition Manager. The kernel `ntfs3` driver supplies NTFS read/write support in the live ISO and installed system; legacy `ntfs-3g` is optional after installation.

- Added `wdisplays` and `shikane` to the base desktop payload for interactive and deterministic Wayland display setup. Added Dome 0.1.1 as a source-pinned base Seafoam package from Pearl v0.3.0; its resource/process views are dinit-safe and the package installs no systemd or uwsm integration. Coral is intentionally not included.
- Added the base Seafoam Settings native Zig/GTK4 launcher for wdisplays, Shikane, DinitUI, DINXPanel, Qt6ct and Dome entry points. Added the source-pinned official ZLS 0.16.0 package for Dintor's Zig LSP path; all three are included in the base ISO. ZLS carries only the matching Zig `lib/std` tree plus a metadata-only shim, so completion/navigation work without a full compiler or systemd; the shim delegates to an optional Artix `zig` installation for compiler commands.
- Kept the upstream compiler boundary explicit: Pearl 0.3.0, including the source used by Dome, and Phyto's bundled Pearl 0.2.8 source use their pinned Zig 0.16.0 toolchain, which P0 downloads and verifies; Pori, Aqueous and other DINX-native Zig packages outside that upstream Pearl tree remain on the verified Zig 0.17.0 toolchain.
- Added the DINX display persistence bridge: the wdisplays desktop entry, DINXPanel and Seafoam Settings use `dinx-wdisplays`; closing the editor atomically replaces the `DINX wdisplays` profile, reloads Shikane and keeps the layout across sessions.
- Added the read-only `dinx-doctor` report for session, dinit, storage, display and package evidence; it never performs service, mount, package or network mutations.
- Added Aqueous 1.0.5 and Pearl 0.3.0 to the base ISO as the only selectable direct-dinit session. The greeter and live autologin launch Aqueous/Pearl through DINX wrappers; after Wayland and session D-Bus readiness, the DINX supervisor starts Shikane, PolicyKit, optional BC250, the required idle helper and Pearl, removes upstream systemd/uwsm units, and records failure instead of leaving a blank desktop. The session adds no systemd package, runtime or user unit. Removed the legacy Xorg/XLibre server, driver and Plasma X11 payload from the ISO while retaining XWayland and builder-only Xvfb support.
- Refreshed the English and Brazilian Portuguese landing pages and operational documentation with the published Alpha 9 snapshot plus the successful post-release `main` validation run `39934458077`; the docs distinguish validation evidence from published release assets.
- Removed the manual live greeter step: the disposable ISO session starts `Aqueous + Pearl (DINX)` through a live-only dinit autologin package, while the installed system and Calamares keep autologin disabled. If the live session exits, greetd returns to Pearl Greeter.
- Added a supervised Aqueous/Pearl session boundary: the helper waits for Wayland and D-Bus readiness, starts required display/policy/idle components and Pearl, records `starting`/`ready`/`failed`/`exited` state, terminates the compositor on required-helper or compositor failure, and terminates the tracked compositor parent if the supervisor itself is stopped, without systemd or uwsm.
- Hardened Pori mount persistence with a dinit `process` wrapper that waits for devices, retries mounts, owns only mounts it created, unmounts them on shutdown and restarts after an unexpected disappearance. Phyto, File Roller, GParted and kernel `ntfs3` remain the supported file, archive, partition and NTFS paths.
- Serialized wdisplays-to-Shikane updates with `flock`; profile replacement remains atomic, and a failed Shikane reload now fails visibly instead of reporting a successful persistence update.
- Added exact source-input inventories to `feature-groups.json` and an unprivileged pull-request contract workflow so package/profile drift, helper contracts, the pinned Zig 0.17 Pori source smoke, fixture smokes and REUSE coverage are checked before the privileged ISO build.
- Ordered the persistent-install first-boot marker after `early-root-rw.target`, preventing its `/var` write from racing the installed root's read-only remount on UEFI first boot.


## v0.1.0-alpha.9 — 2026-10-23

- Published the previous public DINX system alpha for x86_64 Artix Linux with dinit: [GitHub release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9).
- Passed tagged release workflow [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) from commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`, including package/profile contracts, Artix package builds, compact ISO creation, QEMU boot/graphical payload, Calamares BIOS/UEFI/Btrfs smokes, disposable persistent-install/recovery-TTY smokes, build-metadata verification, persistent package signing, provenance attestation and release publication.
- Published a direct ISO, SHA-512 checksum, build metadata, Windows QEMU package, signed DINX package repository and verification assets.
- Published ISO size: `2,008,801,280` bytes. Full ISO SHA-512: `b3724c82348c229ee897880e03e8adc80d9b5b25588b0aca9dfcfedf0c4744e4e1ae01dcb536f6555502e8fe595f71f06bed599372dffe0e1b0f34b29f3b5b2d`.
- Published signed DINX repository snapshot: `01fc8270e5f0fa0339647c9bbde5934ec247a7c29cf235940d4ea9dcedab5827`.
- The supported xz preset plus x86 BCJ, 1 MiB blocks and a 1 MiB dictionary keeps the direct release ISO below GitHub's 2 GiB asset limit.

## v0.1.0-alpha.8 — 2026-10-21

- Published the current public DINX system alpha for x86_64 Artix Linux with dinit: [GitHub release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8).
- Passed tagged release workflow [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024) from commit `eea66ac`, including package and ISO contracts, QEMU boot, graphical payload validation, Calamares BIOS/UEFI/Btrfs transaction smokes, disposable persistent-install/recovery-TTY smokes, build-metadata verification, persistent package signing, attestation and release publication.
- Published the split ISO parts, SHA-512 checksum, build metadata, Windows QEMU package, signed DINX package repository and verification assets.
- Published ISO size: `2,803,349,504` bytes. Full ISO SHA-512: `50e8d535fd4a482ea5433b454921a34402f64e2aa9f82ed9434cff659820c944df7b44b062ebd56094948147109ff65b6f31889080340de484c36fb5d7eb5b8a`.
- Published signed DINX repository snapshot: `5a61d50f3837161bed1af7619965b44e80bd885e79457e443c328e0151d805d9`.
- Updated the user-facing English and Portuguese landing pages and release documentation to point to Alpha 8.

### Known boundaries

This remains a public alpha. Physical hardware, a real DRM gaming session, authenticated Steam and commercial-game launch, controller input, PipeWire game audio, suspend/resume, GPU recovery, Secure Boot and installed-ISO upgrade/rollback remain outside the release claim.
