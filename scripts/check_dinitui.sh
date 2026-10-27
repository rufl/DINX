#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pkg_dir="$root/distro/packages/dinitui"
pkgbuild="$pkg_dir/PKGBUILD"
backend="$pkg_dir/src/dinit.zig"
gpu="$pkg_dir/src/gpu.zig"
profiles="$pkg_dir/src/profiles.zig"
frontend="$pkg_dir/src/main.zig"
profile_conf="$pkg_dir/profiles.conf"
desktop="$pkg_dir/resources/dinitui.desktop"
readme="$pkg_dir/README.md"
qualification="$root/scripts/dinitui_dinit_qualification.sh"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
workflow="$root/.github/workflows/p0-iso.yml"

fail() {
  printf 'check_dinitui: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$backend" "$gpu" "$profiles" "$frontend" "$profile_conf" "$desktop" \
  "$readme" "$profile" "$workflow" "$qualification"; do
  [[ -r "$path" ]] || fail "missing $path"
done

grep -Fqx 'pkgname=dinitui' "$pkgbuild" || fail 'PKGBUILD package name is not dinitui'
grep -Fq 'depends=(dinit gtk4 libadwaita polkit pciutils)' "$pkgbuild" || fail 'runtime dependency contract is incomplete'
grep -Fq "makedepends=('zig>=0.17')" "$pkgbuild" || fail 'Zig 0.17 build dependency is missing'
grep -Fq 'Exec=dinitui' "$desktop" || fail 'desktop launcher does not execute dinitui'
grep -Fq 'Icon=org.dinx.DinitUI' "$desktop" || fail 'desktop launcher icon is missing'
grep -Fq '    - dinitui' "$profile" || fail 'DINX profile does not install dinitui'
grep -Fq '    - seafoam-settings' "$profile" || fail 'Seafoam Settings is missing from the DINX rootfs'
grep -Fq 'build_package dinitui' "$workflow" || fail 'ISO workflow does not build dinitui'
grep -Fq 'pacman -U --noconfirm "$package_repo"/dinitui-*.pkg.tar.zst' "$workflow" || fail 'workflow does not install the packaged DinitUI before qualification'
grep -Fq 'DINITUI_BIN=/usr/bin/dinitui scripts/dinitui_dinit_qualification.sh' "$workflow" || fail 'workflow does not qualify the packaged DinitUI binary'
grep -Fq 'std.process.run' "$backend" || fail 'DinitUI does not use argv-safe process execution'
grep -Fq 'service-file discovery failed' "$frontend" || fail 'service-file discovery errors are not surfaced'
grep -Fq 'gtk_button_new_with_label("Refresh")' "$frontend" || fail 'refresh control lacks a visible accessible label'
grep -Fq 'Filter services' "$frontend" || fail 'service search lacks an input cue'
grep -Fq -- '--profile-status' "$frontend" || fail 'profile status CLI is missing'
grep -Fq -- '--apply-profile' "$frontend" || fail 'profile apply CLI is missing'
grep -Fq -- '--toggle-profile' "$frontend" || fail 'profile toggle CLI is missing'
grep -Fq -- '--gpu-status' "$frontend" || fail 'GPU status CLI is missing'
grep -Fq -- '--install-gpu-drivers' "$frontend" || fail 'GPU install CLI is missing'
grep -Fq -- '--gaming-enter' "$frontend" || fail 'Gaming enter CLI is missing'
grep -Fq -- '--gaming-leave' "$frontend" || fail 'Gaming leave CLI is missing'
grep -Fq 'lspci", "-nnk"' "$gpu" || fail 'GPU detection does not use lspci argv'
for package in mesa vulkan-radeon vulkan-intel nvidia-open-dkms nvidia-utils-dinit; do
  grep -Fq "\"$package\"" "$gpu" || fail "GPU plan is missing $package"
done
grep -Fq 'profiles.conf' "$frontend" "$profiles" "$pkgbuild" || fail 'profile persistence contract is missing'
for action in start stop restart reload enable disable wake release unpin unload trigger untrigger is-started is-failed add-dep rm-dep setenv unsetenv catlog signal shutdown; do
  grep -Fq "\"$action\"" "$backend" || fail "Dinit action is missing: $action"
done
grep -Fq 'CONFIRM' "$backend" || fail 'shutdown confirmation guard is missing'
grep -Fq 'stop", service, &.{ "stop", service })) failures += 1' "$profiles" || fail 'profile stop failures are not fatal'
grep -Fq 'return self.apply("gaming");' "$profiles" || fail 'gaming recovery state is not preserved on apply failure'
grep -Fq 'active-state=unchanged' "$profiles" || fail 'profile failure does not preserve active-state semantics'
grep -Fq 'result=skipped reason=service-not-discovered' "$profiles" || fail 'profile skips are not reported'
if grep -Eq 'catch \\{\\}' "$frontend" "$profiles"; then
  fail 'DinitUI contains a silently ignored error path'
fi
if grep -Eiq '/bin/sh|systemctl|systemd' "$pkgbuild" "$backend" "$gpu" "$frontend"; then
  fail 'DinitUI implementation contains a forbidden shell or systemd integration path'
fi
if grep -Eiq 'noctalia|labwc' "$pkgbuild" "$backend" "$gpu" "$frontend" "$readme"; then
  fail 'DinitUI contains a retired desktop-shell integration path'
fi
grep -Fq 'GTK4 and libadwaita' "$readme" || fail 'toolkit decision is not documented'
grep -Fq 'argv-safe' "$readme" || fail 'privilege/input boundary is not documented'
grep -Fq 'Performance profiles' "$readme" || fail 'profile behavior is not documented'
grep -Fq 'dinitui_dinit_runtime' "$qualification" || fail 'real Dinit qualification script is missing its result marker'
grep -Fq 'dinitui_profile_failure' "$qualification" || fail 'profile failure qualification is missing'
printf 'dinitui_contract package=true profile_entry=true workflow_build=true argv_safe=true pkexec_fallback=true dinit_actions=true performance_profiles=true errors_surface=true profile_report=true ui_labels=true gpu_drivers=true seafoam_integration=true systemd=false\n'
