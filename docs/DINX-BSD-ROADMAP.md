# DINX-BSD Architecture and Porting Roadmap

Target: FreeBSD 14.2+ base with dinit, seatd, wlroots, Aqueous, Pearl, PipeWire, OctaPkg, and linux-rl9.

## 1. Core Stack Mapping
- **Kernel / Drivers**: FreeBSD kernel + `drm-kmod` (AMD/Intel/NVIDIA)
- **Init / Supervision**: `dinit` (FreeBSD port)
- **Session / Seat**: `seatd` + `libseat`
- **Compositor**: Aqueous (Zig/wlroots)
- **Desktop Shell**: Pearl Greeter / Pearl Panel (GTK4 / Qt6)
- **Audio**: PipeWire + WirePlumber (OSS/sndio backend)
- **Package Management**: OctaPkg (frontend) + FreeBSD `pkg` (native ports) + `linux-rl9` (compatibility layer)

## 2. Reusable DINX Components
- Test harnesses and contract scripts (`scripts/check_*.sh`, `scripts/smoke_*.sh`)
- Aqueous and Pearl configuration sidecars and layouts
- Theme engines and icon/font assets (Noto, Breeze, Papirus)

## 3. Porting Inventory
- Convert core application build recipes from Arch Linux `PKGBUILD` to FreeBSD Ports Makefiles.
- Configure `linux-rl9` environment for Steam and proprietary Linux binaries.
