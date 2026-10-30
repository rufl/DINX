#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
workflow="$root/.github/workflows/p0-iso.yml"
aqueous_dir="$root/distro/packages/aqueous"
pearl_dir="$root/distro/packages/pearl"
graphics_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-graphics-profile"
iso_check="$root/scripts/check-iso-content.sh"
session_check="$root/scripts/check_dinx_session.sh"
wm_config="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/aqueous/wm.toml"

fail() {
  printf 'aqueous_pearl_contract: %s\n' "$*" >&2
  exit 1
}

for path in \
  "$profile" "$groups" "$workflow" "$iso_check" "$session_check" "$wm_config" \
  "$aqueous_dir/PKGBUILD" "$aqueous_dir/source.env" \
  "$aqueous_dir/dinit.patch" "$aqueous_dir/server-decorations.patch" \
  "$aqueous_dir/titlebar-text.patch" "$aqueous_dir/two-default-workspaces.patch" \
  "$aqueous_dir/window_policy_test.zig" \
  "$pearl_dir/PKGBUILD" "$pearl_dir/source.env" "$pearl_dir/pearl.install" \
  "$graphics_helper" "$root/scripts/check_dinx_graphics_profile.sh"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done

source "$aqueous_dir/source.env"
[[ "$AQUEOUS_VERSION" == 1.0.5 ]] || fail "unexpected Aqueous version: $AQUEOUS_VERSION"
[[ "$AQUEOUS_SOURCE_SHA256" == 7f71b328c191657a441b6c4ee3a18343f1751a5f2dacec229bf3d50c9de561d8 ]] \
  || fail 'Aqueous source checksum changed'
[[ "$AQUEOUS_WLROOTS_SHA256" == 972c7ac44b17828f4702bfae7cd8347346a3fb5b2c1076cfa2c3fcedac5ec343 ]] \
  || fail 'Aqueous wlroots checksum changed'
source "$pearl_dir/source.env"
[[ "$PEARL_VERSION" == 0.3.0 ]] || fail "unexpected Pearl version: $PEARL_VERSION"
[[ "$PEARL_SOURCE_SHA256" == afb15f5650cdd0aa00a9d6ee697dec1cde2cb9eaa77b1631e4876c125caba24a ]] \
  || fail 'Pearl source checksum changed'
[[ "$PEARL_ZIG_VERSION" == 0.16.0 ]] || fail "unexpected Pearl Zig version: $PEARL_ZIG_VERSION"
[[ "$PEARL_ZIG_SOURCE_URL" == https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz ]] \
  || fail 'Pearl Zig source URL changed'
[[ "$PEARL_ZIG_SOURCE_SHA256" == 70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00 ]] \
  || fail 'Pearl Zig source checksum changed'
aqueous_archive="$aqueous_dir/Aqueous-$AQUEOUS_VERSION.tar.gz"
[[ -r "$aqueous_archive" ]] || fail "missing pinned Aqueous source archive: ${aqueous_archive#$root/}"
for command_name in tar patch; do
  command -v "$command_name" >/dev/null 2>&1 || fail "required command not found: $command_name"
done
zig_bin="${ZIG:-zig}"
command -v "$zig_bin" >/dev/null 2>&1 || fail "required Zig compiler not found: $zig_bin"
window_test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/dinx-aqueous-window-tests.XXXXXX")
trap 'rm -rf "$window_test_tmp"' EXIT
source_root="$window_test_tmp/Aqueous-$AQUEOUS_VERSION"
tar -xzf "$aqueous_archive" -C "$window_test_tmp"
for patch_file in dinit.patch server-decorations.patch titlebar-text.patch two-default-workspaces.patch; do
  patch --batch --forward --fuzz=0 -Np1 -d "$source_root" \
    -i "$aqueous_dir/$patch_file" >/dev/null \
    || fail "pinned Aqueous source rejects ${patch_file}"
done
workspace_source="$source_root/compositor/aqueous/Output.zig"
grep -Fq 'while (i <= 2)' "$workspace_source" \
  || fail 'fresh Aqueous outputs do not start with two pinned workspaces'
if grep -Fq 'while (i <= 9)' "$workspace_source"; then
  fail 'Aqueous still creates nine initial pinned workspaces'
fi
if ! awk '
  /^pub fn notifyTitle\(window: \*Window\) void \{/ { in_notify_title = 1; next }
  in_notify_title && /window\.title_text_dirty = true;/ { invalidated = 1 }
  in_notify_title && /window\.wm_scheduled\.dirty_title = true;/ {
    valid = invalidated
    exit
  }
  in_notify_title && /^pub fn / { exit }
  END { exit !valid }
' "$source_root/compositor/aqueous/Window.zig"; then
  fail 'Aqueous title changes do not invalidate the compositor title cache'
fi
cp "$aqueous_dir/window_policy_test.zig" \
  "$source_root/compositor/aqueous/wm/dinx_window_policy_test.zig"
(
  cd "$source_root/compositor/aqueous/wm"
  ZIG_GLOBAL_CACHE_DIR="$window_test_tmp/zig-global-cache" \
    ZIG_LOCAL_CACHE_DIR="$window_test_tmp/zig-local-cache" \
    "$zig_bin" test dinx_window_policy_test.zig
)
printf 'aqueous_window_policy_smoke source_pinned=true patches_apply=true titlebar_zones=true floating_snap_geometry=true\n'


for package in aqueous pearl; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
done
jq -e '.groups.desktop.packages | index("aqueous") != null and index("pearl") != null' "$groups" >/dev/null \
  || fail 'desktop feature group is missing Aqueous or Pearl'
if jq -e 'any(.groups[].packages[]; . == "aqueous-core" or . == "aqueous-session" or . == "uwsm")' "$groups" >/dev/null; then
  fail 'obsolete Aqueous split or uwsm package is in a feature group'
fi

for required in \
  '  usr/bin/aqueous' \
  '  usr/bin/aqueous-cpu' \
  '  usr/bin/aqueousctl' \
  '  usr/bin/aqueous-config' \
  '  usr/bin/pearl' \
  '  usr/bin/pearl-greeter' \
  '  usr/lib/pearl/pearl-greeter-host' \
  '  usr/lib/pearl/pearl-greeter-session' \
  '  usr/lib/pearl/pearl-greeter-init' \
  '  usr/share/pearl-greeter/release-gate.json' \
  '  etc/pearl/greeter.json' \
  '  usr/share/polkit-1/actions/org.aqueous.Pearl.Greeter.Appearance.policy' \
  '  usr/share/wayland-sessions/dinx-aqueous-pearl.desktop' \
  '  usr/local/libexec/dinx-aqueous-pearl' \
  '  usr/local/libexec/dinx-aqueous-init'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done
grep -Fq 'spawn_terminal = "deetty"' "$wm_config" \
  || fail 'Aqueous Super+Return is not configured to launch the sole terminal'
if grep -Eiq 'foot|ghostty' "$wm_config"; then
  fail 'Aqueous default config references a terminal not shipped in the ISO'
fi

grep -Fq 'pkgver="$AQUEOUS_VERSION"' "$aqueous_dir/PKGBUILD" || fail 'Aqueous package version is not pinned'
grep -Fq '$AQUEOUS_SOURCE_SHA256' "$aqueous_dir/PKGBUILD" || fail 'Aqueous source checksum is not wired to source.env'
grep -Fq '$AQUEOUS_WLROOTS_SHA256' "$aqueous_dir/PKGBUILD" || fail 'Aqueous wlroots checksum is not wired to source.env'
grep -Fq 'settingsApplication/build.zig' "$aqueous_dir/PKGBUILD" || fail 'Aqueous config helper is not built'
grep -Fq 'aqueous-config' "$aqueous_dir/PKGBUILD" || fail 'Aqueous config helper is not packaged'
grep -Fq -- '-Dvulkan-effects=false' "$aqueous_dir/PKGBUILD" \
  || fail 'Aqueous CPU compatibility compositor does not disable Vulkan effects'
grep -Fq 'aqueous-cpu-dist/bin/aqueous' "$aqueous_dir/PKGBUILD" \
  || fail 'Aqueous CPU compatibility compositor is not built'
if grep -Fq "'systemd-libs'" "$aqueous_dir/PKGBUILD"; then
  fail 'Aqueous must not depend on systemd-libs'
fi
grep -Fq 'dinit.patch' "$aqueous_dir/PKGBUILD" \
  || fail 'Aqueous dinit patch is not applied'
grep -Fq 'two-default-workspaces.patch' "$aqueous_dir/PKGBUILD" \
  || fail 'Aqueous does not apply the two-workspace startup default'
grep -Fq 'patch --forward --fuzz=0 -Np1' "$aqueous_dir/PKGBUILD" \
  || fail 'Aqueous patches are not applied reproducibly'
grep -Fq 'server-decorations.patch' "$aqueous_dir/PKGBUILD" \
  || fail 'Aqueous compositor decorations are not applied reproducibly'
for decoration in drawTitlebar decorationActionAt toggleMaximized move_floating; do
  grep -Fq "$decoration" "$aqueous_dir/server-decorations.patch" \
    || fail "Aqueous compositor decoration patch is missing $decoration"
done
grep -Fq '@@ -292,1 +292,0 @@' "$aqueous_dir/dinit.patch" \
  || fail 'Aqueous build still links systemd'
grep -Fq '@@ -718,1 +718,0 @@' "$aqueous_dir/dinit.patch" \
  || fail 'Aqueous keyboard test still links systemd'
grep -Fq 'compositor/aqueous/activity_bootstrap.c' "$aqueous_dir/dinit.patch" \
  || fail 'Aqueous activity bootstrap is not patched for dinit'
grep -Fq '"Alt+Shift+F"        = "set_layout:stacking"' "$aqueous_dir/dinit.patch" \
  || fail 'Aqueous floating layout cannot be restored from the keyboard'
if grep -Eq "['\"](systemd|systemctl|uwsm)['\"]" "$aqueous_dir/PKGBUILD" \
  || grep -Eiq '(^|[[:space:]])(systemctl|uwsm)([[:space:]]|$)' "$aqueous_dir/PKGBUILD"; then
  fail 'Aqueous recipe contains a systemd init, systemctl or uwsm dependency/command'
fi

grep -Fq 'pkgver="$PEARL_VERSION"' "$pearl_dir/PKGBUILD" || fail 'Pearl package version is not pinned'
grep -Fq '$PEARL_SOURCE_SHA256' "$pearl_dir/PKGBUILD" || fail 'Pearl source checksum is not wired to source.env'
grep -Fq -- '-Dwasm-plugins=false' "$pearl_dir/PKGBUILD" || fail 'Pearl package does not select the compact native build'
grep -Fq 'build-greeter' "$pearl_dir/PKGBUILD" || fail 'Pearl package does not build Pearl Greeter'
grep -Fq 'install=pearl.install' "$pearl_dir/PKGBUILD" || fail 'Pearl package has no greeter account install hook'
grep -Fq "'greetd'" "$pearl_dir/PKGBUILD" || fail 'Pearl package does not declare greetd integration'
grep -Fq "'elogind'" "$pearl_dir/PKGBUILD" || fail 'Pearl package does not declare elogind power integration'
grep -Fq 'pearl-greeter-host' "$pearl_dir/PKGBUILD" || fail 'Pearl Greeter host is not packaged'
grep -Fq 'pearl-greeter-session' "$pearl_dir/PKGBUILD" || fail 'Pearl Greeter session helper is not packaged'
grep -Fq 'pearl-greeter-init' "$pearl_dir/PKGBUILD" || fail 'Pearl Greeter init helper is not packaged'
grep -Fq 'rm -rf "$pkgdir/usr/lib/systemd" "$pkgdir/usr/share/uwsm"' "$pearl_dir/PKGBUILD" \
  || fail 'Pearl upstream lifecycle payload is not removed'
if grep -Eq "['\"](systemd|systemctl|uwsm)['\"]" "$pearl_dir/PKGBUILD" \
  || grep -Eiq '(^|[[:space:]])(systemctl|uwsm)([[:space:]]|$)' "$pearl_dir/PKGBUILD"; then
  fail 'Pearl recipe contains a systemd init, systemctl or uwsm dependency/command'
fi
grep -Fq 'useradd --system --gid pearl-greeter' "$pearl_dir/pearl.install" \
  || fail 'Pearl Greeter account is not provisioned by the package hook'
grep -Fq 'usermod --append --groups video pearl-greeter' "$pearl_dir/pearl.install" \
  || fail 'Pearl Greeter account is missing video access'
if grep -Eiq 'systemd|systemctl|uwsm' "$pearl_dir/pearl.install"; then
  fail 'Pearl Greeter install hook contains a systemd integration'
fi

grep -Fq 'build_package aqueous' "$workflow" || fail 'workflow does not build Aqueous'
grep -Fq 'build_package pearl' "$workflow" || fail 'workflow does not build Pearl'
grep -Fq 'PEARL_ZIG_SOURCE_SHA256' "$workflow" || fail 'workflow does not verify the pinned Pearl Zig archive'
grep -Fq 'ZIG=/tmp/zig-x86_64-linux-${PEARL_ZIG_VERSION}/zig' "$workflow" \
  || fail "workflow does not select Pearl's declared Zig toolchain"
grep -Fq '                scdoc \' "$workflow" || fail 'workflow does not install Aqueous man-page builder'
if grep -Fq '                systemd-libs \' "$workflow"; then
  fail 'workflow still installs systemd-libs for Aqueous'
fi
grep -Fq 'scripts/check_aqueous_pearl.sh' "$workflow" || fail 'workflow does not run the Aqueous/Pearl contract'
grep -Fq 'scripts/check_dinx_session.sh' "$workflow" || fail 'workflow does not run the session contract'

aqueous_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-pearl"
grep -Fq 'compositor=/usr/bin/aqueous' "$aqueous_wrapper" \
  || fail 'hardware Aqueous compositor selection is missing'
grep -Fq 'compositor=/usr/bin/aqueous-cpu' "$aqueous_wrapper" \
  || fail 'compatibility Aqueous compositor selection is missing'
grep -Fq 'graphics_profile=$(/usr/local/libexec/dinx-graphics-profile)' "$aqueous_wrapper" \
  || fail 'Aqueous session does not select the detected graphics profile'
grep -Fq 'virtual-gl)' "$aqueous_wrapper" \
  || fail 'Aqueous session has no VM GLES renderer path'
grep -Fq 'export WLR_RENDERER=gles2' "$aqueous_wrapper" \
  || fail 'Aqueous VM renderer is not set to GLES2'
grep -Fq 'export GSK_RENDERER=gl' "$aqueous_wrapper" \
  || fail 'GTK4 VM renderer is not set to GL'
grep -Fq 'export WLR_RENDERER=pixman' "$aqueous_wrapper" \
  || fail 'Aqueous CPU renderer is not set to Pixman'
grep -Fq 'export GSK_RENDERER=cairo' "$aqueous_wrapper" \
  || fail 'GTK4 Cairo fallback is missing from the CPU branch'
grep -Fq 'exec "$compositor" -c /usr/local/libexec/dinx-aqueous-init' "$aqueous_wrapper" \
  || fail 'Aqueous wrapper does not execute the selected compositor'
grep -Fq 'virtio_gpu|vmwgfx)' "$graphics_helper" \
  || fail 'QEMU/VirtualBox render-node drivers are not detected'
grep -Fq 'vboxvideo|qxl|bochs|simpledrm|cirrus)' "$graphics_helper" \
  || fail '2D virtual display drivers do not use the safe fallback'
grep -Fq 'exec /usr/local/libexec/dinx-session-supervisor aqueous' \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-init" \
  || fail 'Aqueous init does not delegate to the supervised dinit session'
grep -Fq 'start_required shell pearl' \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor" \
  || fail 'session supervisor does not own Pearl'
grep -Fq 'wait_for_wayland' \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor" \
  || fail 'session supervisor does not gate Wayland readiness'

printf 'aqueous_pearl_contract aqueous=%s pearl=%s pearl_greeter=true direct_dinit=true initial_workspaces=2 qemu_virgl=true virtualbox_vmsvga=true graphics_fallback=cpu systemd_units=false uwsm=false sources_pinned=true\n' \
  "$AQUEOUS_VERSION" "$PEARL_VERSION"
