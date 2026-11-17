#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pkgdir="$root/distro/packages/dinx-first-run"
pkgbuild="$pkgdir/PKGBUILD"
frontend="$pkgdir/src/main.zig"
desktop="$pkgdir/resources/dinx-first-run.desktop"
glue="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-desktop-first-run"
theme_sync="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-sync-session-theme"
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"

fail() {
  printf 'dinx_first_run_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$frontend" "$desktop" "$glue" "$theme_sync" "$supervisor" "$profile"; do
  [[ -r "$path" ]] || fail "missing input: $path"
done

# Package identity: an in-tree Zig app with the toolkit deps the wizard needs.
grep -Fqx 'pkgname=dinx-first-run' "$pkgbuild" || fail 'PKGBUILD package name is not dinx-first-run'
grep -Eq '^[[:space:]]*source=\(\)[[:space:]]*$' "$pkgbuild" || fail 'first-run must build from its checked-in source tree'
grep -Fq 'depends=(gtk4 libadwaita glib2 dconf)' "$pkgbuild" || fail 'first-run runtime dependency contract changed'
grep -Fq 'install -Dm755 "$srcdir/stage/bin/dinx-first-run" "$pkgdir/usr/bin/dinx-first-run"' "$pkgbuild" \
  || fail 'first-run is not installed to /usr/bin/dinx-first-run'
grep -Fqx 'Exec=dinx-first-run' "$desktop" || fail 'first-run desktop entry launch command is incorrect'
grep -Fqx 'NoDisplay=true' "$desktop" || fail 'first-run must not appear in the application menu'

# The wizard writes the two state files the rest of the session reads.
grep -Fq 'dinx/appearance.json' "$frontend" || fail 'first-run does not write the shared appearance file'
grep -Fq 'installer-preferences.json' "$frontend" || fail 'first-run does not persist Calamares installer preferences'
grep -Fq 'desktop-first-run-complete' "$frontend" || fail 'first-run has no completion marker'
grep -Fq 'com.arkye.morghulis' "$frontend" || fail 'first-run does not target the Morghulis settings schema'
grep -Fq 'navbar-anchor' "$frontend" || fail 'first-run does not set the Morghulis bar position'
grep -Fq 'dinx-dock' "$frontend" || fail 'first-run does not reload the dock after a placement change'
for placement in '"left"' '"right"' '"bottom"' '"none"'; do
  grep -Fq "$placement" "$frontend" || fail "first-run does not offer the dock placement: $placement"
done
for variant in 'prefer-dark' 'prefer-light'; do
  grep -Fq "$variant" "$frontend" || fail "first-run does not offer the $variant color scheme"
done
for family in DINX Skeuos Orchis Fluent Jasper; do
  grep -Fq "$family" "$frontend" || fail "first-run does not offer the $family theme family"
done

# The session glue runs the wizard once, applies locale, then syncs the toolkits,
# and it must never be able to abort the session.
sh -n "$glue" || fail 'first-run glue has invalid shell syntax'
grep -Fq 'DINX_FIRST_RUN_COMMAND' "$glue" || fail 'first-run glue does not allow overriding the wizard command'
grep -Fq 'dinx-sync-session-theme' "$glue" || fail 'first-run glue does not run the theme synchronizer'
grep -Fq 'dinx-session.env' "$glue" || fail 'first-run glue does not publish the locale to session children'
grep -Fq 'exit 0' "$glue" || fail 'first-run glue can abort the session on failure'
grep -Fq 'dinx-desktop-first-run' "$supervisor" || fail 'the supervisor does not run the first-run glue'
grep -Fq '    - dinx-first-run' "$profile" || fail 'the DINX profile does not install dinx-first-run'

printf 'dinx_first_run_contract package=in-tree appearance=true installer_preferences=true marker=true morghulis_bar=true dock_placement=true theme_variant=true glue=locale+sync supervisor_hook=true systemd=false\n'
