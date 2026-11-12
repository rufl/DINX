#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
greetd_config="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/config.toml"
pearl_config="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/pearl/greeter.json"
pearl_pkg="$root/distro/packages/pearl/PKGBUILD"
pearl_install="$root/distro/packages/pearl/pearl.install"
aqueous_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-pearl"
graphics_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-graphics-profile"
graphics_environment="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-graphics-environment.sh"
greeter_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-pearl-greeter-host"
aqueous_layout="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/aqueous/layout.toml"
theme_sync="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-sync-session-theme"
live_config_seed="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-seed-aqueous-live-config"
aqueous_patch="$root/distro/packages/aqueous/dinit.patch"
aqueous_decoration_patch="$root/distro/packages/aqueous/server-decorations.patch"
gtk3_system="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/gtk-3.0/settings.ini"
gtk3_skel="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/gtk-3.0/settings.ini"
gtk4_system="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/gtk-4.0/settings.ini"
gtk4_skel="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/gtk-4.0/settings.ini"
aqueous_init="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-init"
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
pearl_shell="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-pearl-shell"
wizard_source="$root/distro/packages/pearl/dinx-first-run-wizard.c"
aqueous_session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions/dinx-aqueous-pearl.desktop"
gaming_session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions/dinx-gaming.desktop"
session_dir="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions"
lock="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-lock"
idle="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-idle"
desktop="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/dinx-lock.desktop"
architecture="$root/docs/architecture.md"
compatibility="$root/docs/compatibility.md"
pt_architecture="$root/docs/pt-BR/architecture.md"
pt_compatibility="$root/docs/pt-BR/compatibility.md"
shell_profile="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/profile.d/dinx.sh"
fish_config="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/fish/config.fish"
useradd_defaults="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/default/useradd"
users_conf="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/modules/users.conf"
qemu_session_checker="$root/scripts/check_dinx_qemu_session.sh"
iso_smoke="$root/scripts/smoke-iso.sh"

fail() {
  printf 'check_dinx_session: %s\n' "$*" >&2
  exit 1
}

for path in \
  "$profile" "$greetd_config" "$pearl_config" "$pearl_pkg" "$pearl_install" \
  "$aqueous_wrapper" "$theme_sync" "$live_config_seed" "$greeter_wrapper" "$aqueous_init" "$supervisor" "$aqueous_session" \
  "$pearl_shell" "$wizard_source" \
  "$gaming_session" "$lock" "$idle" "$desktop" "$shell_profile" "$fish_config" \
  "$aqueous_layout" "$aqueous_patch" "$graphics_helper" "$graphics_environment" \
  "$useradd_defaults" "$users_conf" "$gtk3_system" "$gtk3_skel" \
  "$gtk4_system" "$gtk4_skel" "$qemu_session_checker" "$iso_smoke"; do
  [[ -r "$path" ]] || fail "missing $path"
done
for retired in \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/regreet.toml" \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/aqueous/greeter-wm.toml" \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-regreet" \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-greeter" \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-greeter-init"; do
  [[ ! -e "$retired" ]] || fail "retired greeter path remains: ${retired#$root/}"
done
for session_path in "$session_dir"/*.desktop; do
  [[ -e "$session_path" ]] || continue
  case "${session_path##*/}" in
    dinx-aqueous-pearl.desktop|dinx-gaming.desktop) ;;
    *) fail "unsupported user session entry remains: ${session_path#$root/}" ;;
  esac
done
[[ -x "$greeter_wrapper" ]] || fail 'Pearl Greeter wrapper is not executable'
[[ -x "$aqueous_wrapper" ]] || fail 'Aqueous session wrapper is not executable'
sh -n "$aqueous_wrapper" || fail 'Aqueous session wrapper has invalid shell syntax'
[[ -x "$aqueous_init" ]] || fail 'Aqueous session init is not executable'
[[ -x "$theme_sync" ]] || fail 'GTK/Qt session theme synchronizer is not executable'
sh -n "$theme_sync" || fail 'GTK/Qt session theme synchronizer has invalid shell syntax'
[[ -x "$lock" ]] || fail 'lock wrapper is not executable'
[[ -x "$idle" ]] || fail 'idle wrapper is not executable'
[[ -x "$graphics_helper" ]] || fail 'graphics-profile helper is not executable'
[[ -x "$supervisor" ]] || fail 'session supervisor is not executable'
sh -n "$greeter_wrapper" || fail 'Pearl Greeter wrapper has invalid shell syntax'

for package in greetd brightnessctl swayidle swaylock wlopm fish aqueous pearl vulkan-swrast dconf gsettings-desktop-schemas; do
  grep -Fq "    - $package" "$profile" || fail "profile is missing $package"
done
for package in labwc noctalia aqueous-core aqueous-session uwsm greetd-regreet; do
  if grep -Fqx "    - $package" "$profile"; then
    fail "retired session or greeter package remains in the profile: $package"
  fi
done
grep -Fq 'export SHELL=/bin/fish' "$shell_profile" || fail 'POSIX shell default is not Fish'
grep -Fq 'XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Aqueous}"' "$shell_profile" \
  || fail 'POSIX desktop default is not Aqueous'
grep -Fq 'DINX_COLOR_SCHEME="${DINX_COLOR_SCHEME:-dark}"' "$shell_profile" \
  || fail 'DINX color scheme default is missing'
grep -Fq 'set -gx SHELL /bin/fish' "$fish_config" || fail 'Fish system shell default is missing'
grep -Fq 'set -gx XDG_CURRENT_DESKTOP Aqueous' "$fish_config" \
  || fail 'Fish desktop default is not Aqueous'
grep -Fq 'set -gx DINX_COLOR_SCHEME dark' "$fish_config" \
  || fail 'Fish DINX color scheme default is missing'
grep -Fq 'SHELL=/bin/fish' "$useradd_defaults" || fail 'new-user shell default is not Fish'
grep -Fq 'shell: /bin/fish' "$users_conf" || fail 'Calamares user shell is not Fish'

for doc in "$architecture" "$compatibility" "$pt_architecture" "$pt_compatibility"; do
  grep -Fq 'Aqueous' "$doc" || fail "Aqueous session boundary is undocumented: ${doc#$root/}"
  grep -Fq 'Pearl Greeter' "$doc" || fail "Pearl Greeter boundary is undocumented: ${doc#$root/}"
  grep -Fq 'dinit' "$doc" || fail "dinit boundary is undocumented: ${doc#$root/}"
done

grep -Fq '[general]' "$greetd_config" || fail 'greetd general section is missing'
grep -Fq 'source_profile = false' "$greetd_config" \
  || fail 'greetd must not source the greeter account profile'
grep -Fq 'command = "/usr/local/libexec/dinx-pearl-greeter-host"' "$greetd_config" \
  || fail 'greetd does not launch the graphics-safe Pearl Greeter wrapper'
grep -Fq 'user = "pearl-greeter"' "$greetd_config" \
  || fail 'greetd does not use the dedicated Pearl Greeter account'
if grep -Fq '[initial_session]' "$greetd_config"; then
  fail 'installed greetd config must not enable live autologin'
fi
if grep -Eiq 'systemd|systemctl' "$greetd_config"; then
  fail 'greetd config contains a systemd integration'
fi

grep -Fq 'grep -qx seat' "$greeter_wrapper" \
  || fail 'Pearl Greeter does not verify seatd group membership before selecting the seatd backend'
grep -Fq 'export LIBSEAT_BACKEND=seatd' "$greeter_wrapper" \
  || fail 'Pearl Greeter does not select the seatd libseat backend'
grep -Fq 'export LIBSEAT_BACKEND=logind' "$greeter_wrapper" \
  || fail 'Pearl Greeter does not fall back to elogind for libseat'
grep -Fq 'export HOME=/var/empty/pearl-greeter' "$greeter_wrapper" \
  || fail 'Pearl Greeter does not use its root-owned trusted home'
grep -Fq 'export XDG_CONFIG_HOME=/var/lib/pearl-greeter/.config' "$greeter_wrapper" \
  || fail 'Pearl Greeter config home is not on its writable private directory'
grep -Fq 'export XDG_DATA_HOME=/var/lib/pearl-greeter/.local/share' "$greeter_wrapper" \
  || fail 'Pearl Greeter data home is not on its writable private directory'
grep -Fq 'export XDG_STATE_HOME=/var/lib/pearl-greeter/.local/state' "$greeter_wrapper" \
  || fail 'Pearl Greeter state home is not its dedicated writable state directory'
grep -Fq 'export XDG_CACHE_HOME=/var/cache/pearl-greeter' "$greeter_wrapper" \
  || fail 'Pearl Greeter cache home is not on its writable runtime directory'
jq -e '
  .version == 1
  and .theme == "gtk"
  and .gtk_theme == "Adwaita"
  and .default_session == "wayland:dinx-aqueous-pearl.desktop"
  and .force_session == "wayland:dinx-aqueous-pearl.desktop"
  and .allow == ["wayland:dinx-aqueous-pearl.desktop"]
  and (.roots | length == 1)
  and .roots[0].path == "/usr/share/wayland-sessions"
  and .roots[0].type == "wayland"
  and .accounts == true
  and .password_first == true
  and .power == true
  and .remember_session == false
  and .fingerprint_hint == false
  and .allow_uwsm == false
  and .x11 == false
' "$pearl_config" >/dev/null || fail 'Pearl Greeter config does not force the DINX Aqueous/Pearl session'
if grep -Eiq 'systemd|systemctl' "$pearl_config"; then
  fail 'Pearl Greeter config contains a systemd integration'
fi

grep -Fq 'build-greeter' "$pearl_pkg" || fail 'Pearl package does not build Pearl Greeter'
grep -Fq 'install=pearl.install' "$pearl_pkg" || fail 'Pearl package has no greeter account install hook'
for binary in pearl-greeter pearl-greeter-host pearl-greeter-session pearl-greeter-init; do
  grep -Fq "$binary" "$pearl_pkg" || fail "Pearl package does not install or validate $binary"
done
grep -Fq 'rm -rf "$pkgdir/usr/lib/systemd" "$pkgdir/usr/share/uwsm"' "$pearl_pkg" \
  || fail 'Pearl package does not remove upstream systemd/UWSM lifecycle payloads'
if grep -Eq "['\"](systemd|systemctl|uwsm)['\"]" "$pearl_pkg" \
  || grep -Eiq '(^|[[:space:]])(systemctl|uwsm)([[:space:]]|$)' "$pearl_pkg"; then
  fail 'Pearl recipe contains a systemd, systemctl or UWSM dependency/command'
fi
grep -Fq 'useradd --system --gid pearl-greeter' "$pearl_install" \
  || fail 'Pearl Greeter account is not provisioned by the package hook'
grep -Fq 'usermod --append --groups video,render pearl-greeter' "$pearl_install" \
  || fail 'Pearl Greeter account is missing video/render access'
grep -Fq 'install -d -o root -g root -m 0755 /var/empty/pearl-greeter' "$pearl_install" \
  || fail 'Pearl Greeter trusted home is not provisioned as root-owned and read-only'
for greeter_path in \
  /var/lib/pearl-greeter \
  /var/lib/pearl-greeter/.config \
  /var/lib/pearl-greeter/.local \
  /var/lib/pearl-greeter/.local/share \
  /var/lib/pearl-greeter/.local/state \
  /var/cache/pearl-greeter; do
  grep -Fq "$greeter_path" "$pearl_install" \
    || fail "Pearl Greeter writable path is not provisioned by its package hook: $greeter_path"
done
grep -Fq '    - render' "$users_conf" || fail 'Calamares users are missing render-node access'
grep -Fq 'two-default-workspaces.patch' "$root/distro/packages/aqueous/PKGBUILD" \
  || fail 'Aqueous package does not apply the two-workspace default'
if grep -Eiq 'systemd|systemctl|uwsm' "$pearl_install"; then
  fail 'Pearl Greeter install hook contains a systemd integration'
fi

grep -Fq 'compositor=/usr/bin/aqueous' "$aqueous_wrapper" \
  || fail 'Aqueous hardware compositor selection is missing'
grep -Fq 'compositor=/usr/bin/aqueous-cpu' "$aqueous_wrapper" \
  || fail 'Aqueous compatibility compositor selection is missing'
grep -Fq 'graphics_profile=$(/usr/local/libexec/dinx-graphics-profile)' "$aqueous_wrapper" \
  || fail 'Aqueous wrapper does not select the graphics profile'
grep -Fq 'virtual-gl)' "$aqueous_wrapper" \
  || fail 'Aqueous VM GLES branch is missing'
grep -Fq '. /usr/local/libexec/dinx-graphics-environment.sh' "$aqueous_wrapper" \
  || fail 'Aqueous wrapper does not load the shared renderer policy'
grep -Fq 'dinx_apply_graphics_environment "$graphics_profile"' "$aqueous_wrapper" \
  || fail 'Aqueous wrapper does not apply the selected renderer policy'
grep -Fq 'export WLR_RENDERER=gles2' "$graphics_environment" \
  || fail 'Aqueous VM renderer policy does not use GLES2'
grep -Fq 'export WLR_RENDERER=vulkan' "$graphics_environment" \
  || fail 'Aqueous VirtualBox renderer policy does not use Vulkan'
grep -Fq 'unset GSK_RENDERER' "$graphics_environment" \
  || fail 'GTK4 VM renderer selection is not left automatic'
[[ $(grep -Fc 'unset GSK_RENDERER' "$graphics_environment") -eq 3 ]] \
  || fail 'GTK4 renderer selection is not automatic for CPU, virtual GL and Vulkan profiles'
grep -Fq 'exec "$compositor" -c /usr/local/libexec/dinx-aqueous-init' "$aqueous_wrapper" \
  || fail 'Aqueous wrapper does not launch the selected compositor'
grep -Fq 'XDG_RUNTIME_DIR=/run/dinx-session' "$aqueous_wrapper" \
  || fail 'Aqueous live session does not use its private runtime directory'
grep -Fq 'lock_path=$XDG_RUNTIME_DIR/dinx-aqueous-pearl.lock' "$aqueous_wrapper" \
  || fail 'Aqueous compositor lock is not scoped to the session runtime directory'
grep -Fq 'flock -n 9' "$aqueous_wrapper" \
  || fail 'Aqueous session does not reject a duplicate compositor instance'
if grep -Eq 'WLR_RENDERER_ALLOW_SOFTWARE|VK_DRIVER_FILES=.*lvp' "$aqueous_wrapper"; then
  fail 'Aqueous session still forces the failing Lavapipe compositor path'
fi
grep -Fq 'xdg-user-dirs-update' "$aqueous_wrapper" \
  || fail 'Aqueous session does not initialize XDG user directories'
if grep -Eq 'GTK_THEME=|set -gx GTK_THEME' "$aqueous_wrapper" \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/etc/profile.d/dinx.sh" \
  "$root/distro/iso/iso-profiles/dinx/root-overlay/etc/fish/config.fish"; then
  fail 'DINX session forces a GTK theme and overrides application preferences'
fi
grep -Fq 'export QT_QPA_PLATFORMTHEME=qt6ct' "$aqueous_wrapper" \
  || fail 'Aqueous session does not force the Qt6ct platform theme'
grep -Fq 'default = "stacking"' "$aqueous_layout" \
  || fail 'Aqueous live and installed sessions do not default to floating windows'
for slot in primary secondary tertiary quaternary; do
  grep -Fq "$slot = \"stacking\"" "$aqueous_layout" \
    || fail "Aqueous $slot layout slot does not resolve to floating stacking"
done
for binding in set_layout_primary set_layout_secondary set_layout_tertiary set_layout_quaternary; do
  grep -Eq "^\+${binding}[[:space:]]*=[[:space:]]*\[\]$" "$aqueous_patch" \
    || fail "Aqueous $binding shortcut remains bound to a non-floating layout"
done
for setting in 'snap_gap = 0' 'snap_threshold = 24' 'resistance = 12' 'top_edge_maximize = true'; do
  grep -Fq "$setting" "$aqueous_layout" || fail "Aqueous floating snap config is missing $setting"
done
grep -Fq 'force_ssd = false' "$aqueous_layout" \
  || fail 'Aqueous must honor client-side GTK decorations by default'
grep -Fq 'export MOZ_GTK_TITLEBAR_DECORATION=system' "$aqueous_wrapper" \
  || fail 'Aqueous session does not force Gecko browsers to use the system/compositor titlebar'
grep -Fq 'client_requires_csd' "$aqueous_decoration_patch" \
  || fail 'Aqueous decoration policy does not distinguish client-side decorations'
grep -Fq '.xwayland => decoration_policy.useServerSideDecorations(' "$aqueous_decoration_patch" \
  || fail 'Aqueous XWayland decoration policy ignores client CSD hints'
grep -Fq 'window.wm_scheduled.decoration_hint == .prefers_csd or' "$aqueous_decoration_patch" \
  || fail 'Aqueous XWayland decoration policy misses preferred CSD'
grep -Fq 'window.wm_scheduled.decoration_hint == .only_supports_csd' "$aqueous_decoration_patch" \
  || fail 'Aqueous XWayland decoration policy misses required CSD'
grep -Fq 'if (!window.usesServerTitlebar()) return null;' "$aqueous_decoration_patch" \
  || fail 'Aqueous titlebar hit testing is active without server-side decorations'
for gtk_settings in "$gtk3_system" "$gtk3_skel" "$gtk4_system" "$gtk4_skel"; do
  grep -Fq 'gtk-decoration-layout=:minimize,maximize,close' "$gtk_settings" \
    || fail "GTK fallback window controls are incomplete in ${gtk_settings#$root/}"
done
grep -Fq 'aqueous/layout.toml' "$aqueous_wrapper" \
  || fail 'Aqueous session does not seed the DINX floating layout'
aqueous_wm_seed_block=$(awk '
  /^if / && /aqueous\/wm\.toml/ { capture = 1 }
  capture { print }
  capture && /^fi$/ { exit }
' "$aqueous_wrapper")
grep -Fq '[ ! -e "$config_home/aqueous/wm.toml" ]' <<<"$aqueous_wm_seed_block" \
  || fail 'Aqueous session may overwrite an existing live-user window-manager config'
grep -Fq 'install -Dm644 /etc/xdg/aqueous/wm.toml "$config_home/aqueous/wm.toml"' <<<"$aqueous_wm_seed_block" \
  || fail 'Aqueous session does not seed the system window-manager config for a new user'
grep -Fq 'exec /usr/local/libexec/dinx-session-supervisor aqueous' "$aqueous_init" \
  || fail 'Aqueous init does not launch the supervisor'
grep -Fq 'start_required shell "$libexec_dir/dinx-pearl-shell"' "$supervisor" \
  || fail 'session supervisor does not launch the Pearl first-run wrapper'
sh -n "$pearl_shell" || fail 'Pearl shell wrapper has invalid shell syntax'
if grep -Fq 'dinx-sync-session-theme' "$aqueous_wrapper"; then
  fail 'toolkit theme synchronization runs before session D-Bus readiness'
fi
grep -Fq 'theme_sync_helper=${DINX_THEME_SYNC_HELPER:-/usr/local/libexec/dinx-sync-session-theme}' "$pearl_shell" \
  || fail 'Pearl shell does not invoke the toolkit theme synchronizer'
[[ -x "$live_config_seed" ]] || fail 'live Aqueous config seed helper is not executable'
sh -n "$live_config_seed" || fail 'live Aqueous config seed helper has invalid shell syntax'
pearl_shell_test=$(mktemp -d)
trap 'rm -rf "$pearl_shell_test"' EXIT
mkdir -p "$pearl_shell_test/bin" "$pearl_shell_test/config/pearl"
mkdir -p "$pearl_shell_test/config/aqueous"
cat >"$pearl_shell_test/config/aqueous/wm.toml" <<'TOML'
[blur]
enabled = true # preserve blur note
radius = 9
[unrelated]
enabled = true
[opacity]
enabled = true # preserve opacity note
  value = 0.8
[keybinds]
lock_screen = "Super+Ctrl+L"
focus_left = "Super+H"
TOML
chmod 0640 "$pearl_shell_test/config/aqueous/wm.toml"
"$live_config_seed" "$pearl_shell_test/config/aqueous/wm.toml"
[[ $(stat -c '%a' "$pearl_shell_test/config/aqueous/wm.toml") == 640 ]] \
  || fail 'live Aqueous effects seed did not preserve config permissions'
grep -Fqx 'enabled = false # preserve blur note' "$pearl_shell_test/config/aqueous/wm.toml" \
  || fail 'live Aqueous config seed did not disable backdrop blur or preserve its comment'
grep -Fqx 'enabled = false # preserve opacity note' "$pearl_shell_test/config/aqueous/wm.toml" \
  || fail 'live Aqueous config seed did not disable window opacity or preserve its comment'
grep -Fqx 'radius = 9' "$pearl_shell_test/config/aqueous/wm.toml" \
  || fail 'live Aqueous config seed changed the blur radius'
grep -Eq '^[[:space:]]*value = 0\.8$' "$pearl_shell_test/config/aqueous/wm.toml" \
  || fail 'live Aqueous config seed changed the opacity value'
grep -Fqx 'enabled = true' "$pearl_shell_test/config/aqueous/wm.toml" \
  || fail 'live Aqueous config seed changed an unrelated enabled setting'
grep -Fqx 'lock_screen = []' "$pearl_shell_test/config/aqueous/wm.toml" \
  || fail 'live Aqueous config seed did not disable the lock-screen keybind'
grep -Fqx 'focus_left = "Super+H"' "$pearl_shell_test/config/aqueous/wm.toml" \
  || fail 'live Aqueous config seed changed an unrelated keybind'
live_config_seed_hash=$(sha256sum "$pearl_shell_test/config/aqueous/wm.toml")
"$live_config_seed" "$pearl_shell_test/config/aqueous/wm.toml"
[[ $(sha256sum "$pearl_shell_test/config/aqueous/wm.toml") == "$live_config_seed_hash" ]] \
  || fail 'live Aqueous config seed is not idempotent'
printf '[unrelated]\nvalue = 1\n' >"$pearl_shell_test/aqueous-wm-missing-sections.toml"
"$live_config_seed" "$pearl_shell_test/aqueous-wm-missing-sections.toml"
awk '
  /^\[blur\]$/ { section = "blur"; next }
  /^\[opacity\]$/ { section = "opacity"; next }
  /^\[keybinds\]$/ { section = "keybinds"; next }
  /^\[/ { section = "" }
  section == "blur" && $0 == "enabled = false" { blur = 1 }
  section == "opacity" && $0 == "enabled = false" { opacity = 1 }
  section == "keybinds" && $0 == "lock_screen = []" { lock = 1 }
  END { exit !(blur && opacity && lock) }
' "$pearl_shell_test/aqueous-wm-missing-sections.toml" \
  || fail 'live Aqueous config seed did not add missing disabled settings'
printf 'aqueous_live_config_seed blur=disabled opacity=disabled lock_keybind=disabled preserves_settings=true idempotent=true\n'
cat >"$pearl_shell_test/wizard" <<'SH'
#!/bin/sh
printf 'called\n' >>"$DINX_WIZARD_CALLS"
printf 'off bottom material-light\n'
SH
cat >"$pearl_shell_test/bin/pearl" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$pearl_shell_test/wizard" "$pearl_shell_test/bin/pearl"
cat >"$pearl_shell_test/config/pearl/preferences.json" <<'JSON'
{"theme":{"seed":"#F4515B"},"wallpaper":{"mode":"solid","path":"","color":"#0b0d12"},"bar":{"retained":true},"dock":{"retained":true},"unrelated":42}
JSON
pearl_shell_test_env=(
  "PATH=$pearl_shell_test/bin:$PATH"
  "HOME=$pearl_shell_test/home"
  "XDG_CONFIG_HOME=$pearl_shell_test/config"
  "XDG_STATE_HOME=$pearl_shell_test/state"
  "DINX_FIRST_RUN_WIZARD=$pearl_shell_test/wizard"
  "DINX_WIZARD_CALLS=$pearl_shell_test/wizard-calls"
  "DINX_THEME_SYNC_HELPER=/bin/true"
)
mkdir -p "$pearl_shell_test/home"
env "${pearl_shell_test_env[@]}" "$pearl_shell"
jq -e '.theme.mode == "static" and .theme.variant == "light" and .theme.gtk_name == "" and .theme.seed == "#F4515B" and .bar.edge == "bottom" and .bar.retained == true and .dock.enabled == false and .dock.edge == "top" and .dock.retained == true and .unrelated == 42' \
  "$pearl_shell_test/config/pearl/preferences.json" >/dev/null \
  || fail 'Pearl wizard selection did not update preferences while preserving existing settings'
[[ -e "$pearl_shell_test/state/dinx/pearl-first-run-complete" ]] \
  || fail 'Pearl first-run completion marker is missing'
[[ $(stat -c '%a' "$pearl_shell_test/config/pearl/preferences.json") == 600 ]] \
  || fail 'Pearl first-run preferences are not private'
env "${pearl_shell_test_env[@]}" "$pearl_shell"
[[ $(wc -l <"$pearl_shell_test/wizard-calls") == 1 ]] \
  || fail 'Pearl first-run wizard runs again after completion'
printf 'pearl_first_run_smoke dock=off bar=bottom theme=material-light preserves_settings=true once=true\n'
pearl_shell_top_test="$pearl_shell_test/top"
mkdir -p "$pearl_shell_top_test/bin" "$pearl_shell_top_test/home" \
  "$pearl_shell_top_test/config/pearl" "$pearl_shell_top_test/state"
cat >"$pearl_shell_top_test/wizard" <<'SH'
#!/bin/sh
printf 'on top material-dark\n'
SH
cat >"$pearl_shell_top_test/bin/pearl" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$pearl_shell_top_test/wizard" "$pearl_shell_top_test/bin/pearl"
printf '{}\n' >"$pearl_shell_top_test/config/pearl/preferences.json"
env \
  "PATH=$pearl_shell_top_test/bin:$PATH" \
  "HOME=$pearl_shell_top_test/home" \
  "XDG_CONFIG_HOME=$pearl_shell_top_test/config" \
  "XDG_STATE_HOME=$pearl_shell_top_test/state" \
  "DINX_FIRST_RUN_WIZARD=$pearl_shell_top_test/wizard" \
  "DINX_THEME_SYNC_HELPER=/bin/true" \
  "$pearl_shell"
jq -e '.bar.edge == "top" and .dock.edge == "bottom" and .theme.variant == "dark"' \
  "$pearl_shell_top_test/config/pearl/preferences.json" >/dev/null \
  || fail 'Pearl top-bar selection did not preserve the bar edge and opposite dock edge'
printf 'pearl_bar_edge_smoke top=true bottom=true exclusive_edge=selected\n'
qemu_screen="$pearl_shell_test/qemu-client-window.ppm"
printf 'P6\n2 2\n255\n\377\377\377\377\377\377\377\377\377\377\377\377' >"$qemu_screen"
cat >"$pearl_shell_test/bin/tesseract" <<'SH'
#!/bin/sh
printf '%s\n' "${DINX_TEST_OCR:-}"
SH
chmod +x "$pearl_shell_test/bin/tesseract"
env "${pearl_shell_test_env[@]}" DINX_TEST_OCR='Dock Show the dock Next' \
  "$qemu_session_checker" "$qemu_screen" first-run >/dev/null
env "${pearl_shell_test_env[@]}" DINX_TEST_OCR='DINX Aqueous desktop' \
  "$qemu_session_checker" "$qemu_screen" session >/dev/null
if env "${pearl_shell_test_env[@]}" DINX_TEST_OCR='DINX desktop' \
  "$qemu_session_checker" "$qemu_screen" first-run >/dev/null 2>&1; then
  fail 'QEMU first-run client-window check accepts a screenshot without readable client text'
fi
env "${pearl_shell_test_env[@]}" DINX_TEST_OCR=$'Aqueous + Pearl (DINX) - Wayland\nPas\n\nrd\nSign in' \
  "$qemu_session_checker" "$qemu_screen" greeter >/dev/null
if env "${pearl_shell_test_env[@]}" DINX_TEST_OCR=$'Aqueous + Pearl (DINX) - Wayland\nPas\n\nrd\nSign in\nAccessDenied' \
  "$qemu_session_checker" "$qemu_screen" greeter >/dev/null 2>&1; then
  fail 'QEMU greeter check accepts an access-denied startup failure'
fi
if env "${pearl_shell_test_env[@]}" DINX_TEST_OCR='DINX desktop Pas rd Sign in' \
  "$qemu_session_checker" "$qemu_screen" greeter >/dev/null 2>&1; then
  fail 'QEMU greeter check accepts controls without Pearl Greeter identity'
fi
grep -Fq '"$script_dir/check_dinx_qemu_session.sh" "$session_screenshot_path" first-run' "$iso_smoke" \
  || fail 'QEMU live smoke does not check readable first-run client-window content'
printf 'qemu_client_window_smoke readable_first_run=true session_marker=true greeter_ocr_fragment=true greeter_startup_error_rejected=true rejects_missing_title=true\n'
grep -Fq 'wait_for_wayland' "$supervisor" || fail 'session supervisor does not gate Wayland readiness'
grep -Fq 'wait_for_dbus' "$supervisor" || fail 'session supervisor does not gate D-Bus readiness'
grep -Fq 'set_status failed' "$supervisor" || fail 'session supervisor has no failure status boundary'
grep -Fq 'stop_parent' "$supervisor" || fail 'session supervisor does not clean up the tracked compositor parent'
if grep -Eiq 'labwc|noctalia|systemd|uwsm' "$aqueous_wrapper" "$aqueous_init" "$supervisor"; then
  fail 'Aqueous supervisor path contains a retired session or systemd integration'
fi
grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-aqueous-pearl' "$aqueous_session" \
  || fail 'Aqueous/Pearl session command is incorrect'
grep -Fq 'TryExec=/usr/local/libexec/dinx-aqueous-pearl' "$aqueous_session" \
  || fail 'Aqueous/Pearl session TryExec is missing'
grep -Fq 'DesktopNames=Aqueous;Pearl' "$aqueous_session" \
  || fail 'Aqueous/Pearl desktop identity is missing'
grep -Fq 'Hidden=true' "$gaming_session" || fail 'gaming session is not hidden'
grep -Fq 'NoDisplay=true' "$gaming_session" || fail 'gaming session remains visible'

if grep -Eq '/bin/sh -c|systemctl|loginctl suspend' "$lock" "$idle"; then
  fail 'session wrappers contain forbidden shell indirection or systemd suspend calls'
fi
grep -Fq 'Exec=/usr/local/libexec/dinx-lock' "$desktop" || fail 'launcher lock action is missing'
grep -Fq 'TryExec=/usr/local/libexec/dinx-lock' "$desktop" || fail 'launcher lock TryExec is missing'
bash "$root/scripts/smoke_dinx_session.sh"

printf 'dinx_session_contract session=aqueous_pearl_only=true greeter=pearl_greeter=true x11=false uwsm=false floating_default=stacking=true layout_slots=stacking=true layout_shortcuts=disabled native_edge_snap=halves+quarters=true top_edge_maximize=true gtk_fallback_controls=minimize+maximize+close=true gtk_dark_mode=prefer-dark-preserves-user=true client_csd_without_duplicate_ssd=true xwayland_csd=true compositor_titlebar_controls=minimize+maximize+close=true theme_env=gtk+qt=true qemu_client_window=true qemu_virgl_gles=true virtualbox_vmsvga_vulkan=true no_render_node_vulkan=true render_group=true live_lock=false live_blank=true installed_lock=true idle=true before_suspend_blank=true energy=true launcher=true hierarchy=true supervisor=true direct_dinit=true systemd=false\n'
