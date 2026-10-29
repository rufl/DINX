#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
greetd_config="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/config.toml"
pearl_config="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/pearl/greeter.json"
pearl_pkg="$root/distro/packages/pearl/PKGBUILD"
pearl_install="$root/distro/packages/pearl/pearl.install"
aqueous_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-pearl"
aqueous_init="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-init"
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
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

fail() {
  printf 'check_dinx_session: %s\n' "$*" >&2
  exit 1
}

for path in \
  "$profile" "$greetd_config" "$pearl_config" "$pearl_pkg" "$pearl_install" \
  "$aqueous_wrapper" "$aqueous_init" "$supervisor" "$aqueous_session" \
  "$gaming_session" "$lock" "$idle" "$desktop" "$shell_profile" "$fish_config" \
  "$useradd_defaults" "$users_conf"; do
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
[[ -x "$aqueous_wrapper" ]] || fail 'Aqueous session wrapper is not executable'
[[ -x "$aqueous_init" ]] || fail 'Aqueous session init is not executable'
[[ -x "$lock" ]] || fail 'lock wrapper is not executable'
[[ -x "$idle" ]] || fail 'idle wrapper is not executable'
[[ -x "$supervisor" ]] || fail 'session supervisor is not executable'

for package in greetd brightnessctl swayidle swaylock fish aqueous pearl vulkan-swrast; do
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
grep -Fq 'command = "/usr/lib/pearl/pearl-greeter-host"' "$greetd_config" \
  || fail 'greetd does not launch the Pearl Greeter host'
grep -Fq 'user = "pearl-greeter"' "$greetd_config" \
  || fail 'greetd does not use the dedicated Pearl Greeter account'
if grep -Fq '[initial_session]' "$greetd_config"; then
  fail 'installed greetd config must not enable live autologin'
fi
if grep -Eiq 'systemd|systemctl' "$greetd_config"; then
  fail 'greetd config contains a systemd integration'
fi

jq -e '
  .version == 1
  and .theme == "gtk"
  and .gtk_theme == "DINX"
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
grep -Fq 'usermod --append --groups video pearl-greeter' "$pearl_install" \
  || fail 'Pearl Greeter account is missing video access'
if grep -Eiq 'systemd|systemctl|uwsm' "$pearl_install"; then
  fail 'Pearl Greeter install hook contains a systemd integration'
fi

grep -Fq 'compositor=/usr/bin/aqueous' "$aqueous_wrapper" \
  || fail 'Aqueous hardware compositor selection is missing'
grep -Fq 'compositor=/usr/bin/aqueous-cpu' "$aqueous_wrapper" \
  || fail 'Aqueous CPU compositor selection is missing'
grep -Fq '0x1af4' "$aqueous_wrapper" \
  || fail 'Virtio GPU detection is missing'
grep -Fq 'if [ "$has_render_node" = false ]; then' "$aqueous_wrapper" \
  || fail 'Aqueous no-render-node detection is missing'
grep -Fq 'export WLR_RENDERER=pixman' "$aqueous_wrapper" \
  || fail 'Aqueous CPU branch does not select Pixman'
grep -Fq 'export GSK_RENDERER=cairo' "$aqueous_wrapper" \
  || fail 'GTK4 Cairo fallback is missing from the CPU branch'
grep -Fq 'exec "$compositor" -c /usr/local/libexec/dinx-aqueous-init' "$aqueous_wrapper" \
  || fail 'Aqueous wrapper does not launch the selected compositor'
if grep -Eq 'WLR_RENDERER_ALLOW_SOFTWARE|VK_DRIVER_FILES=.*lvp' "$aqueous_wrapper"; then
  fail 'Aqueous session still forces the failing Lavapipe compositor path'
fi
[[ $(grep -Fc 'export GSK_RENDERER=cairo' "$aqueous_wrapper") -eq 1 ]] \
  || fail 'GTK4 Cairo fallback is duplicated or overrides the hardware path'
grep -Fq 'xdg-user-dirs-update' "$aqueous_wrapper" \
  || fail 'Aqueous session does not initialize XDG user directories'
grep -Fq 'exec /usr/local/libexec/dinx-session-supervisor aqueous' "$aqueous_init" \
  || fail 'Aqueous init does not launch the supervisor'
grep -Fq 'start_required shell pearl' "$supervisor" || fail 'session supervisor does not own Pearl'
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
grep -Fq '    - libayatana-appindicator' "$profile" || fail 'profile is missing AppIndicator compatibility'

grep -Fq 'timeout 600 /usr/local/libexec/dinx-lock' "$idle" || fail 'idle lock timeout is missing'
grep -Fq 'before-sleep /usr/local/libexec/dinx-lock' "$idle" || fail 'lock-before-suspend hook is missing'
grep -Fq 'Exec=/usr/local/libexec/dinx-lock' "$desktop" || fail 'launcher lock action is missing'
grep -Fq 'TryExec=/usr/local/libexec/dinx-lock' "$desktop" || fail 'launcher lock TryExec is missing'

if grep -Eq '/bin/sh -c|systemctl|loginctl suspend' "$lock" "$idle"; then
  fail 'session wrappers contain forbidden shell indirection or systemd suspend calls'
fi

printf 'dinx_session_contract session=aqueous_pearl_only=true greeter=pearl_greeter=true x11=false uwsm=false lock=true idle=true before_suspend=true energy=true launcher=true hierarchy=true supervisor=true direct_dinit=true systemd=false\n'
