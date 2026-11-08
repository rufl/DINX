#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
wrapper="$repo_root/scripts/iso-tools/mksquashfs"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-final-package-prune.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

fail() {
  printf 'smoke_final_squashfs_package_exclusions: %s\n' "$*" >&2
  exit 1
}

(( EUID == 0 )) || fail 'run this smoke as root inside the ISO builder'
command -v pacman >/dev/null 2>&1 || fail 'pacman is required'
if pacman -Q linux-headers >/dev/null 2>&1; then
  builder_headers_before=present
else
  builder_headers_before=absent
fi
if pacman -Q pahole >/dev/null 2>&1; then
  builder_pahole_before=present
else
  builder_pahole_before=absent
fi

root="$work_dir/rootfs"
header_db="$root/var/lib/pacman/local/linux-headers-1.0-1"
other_db="$root/var/lib/pacman/local/dinx-prune-smoke-1.0-1"
pahole_db="$root/var/lib/pacman/local/pahole-1.0-1"
header_file="$root/usr/src/linux-fixture/include/dinx-fixture.h"
other_file="$root/usr/share/dinx-prune-smoke/keep"
pahole_file="$root/usr/bin/pahole"
mkdir -p -- "$header_db" "$pahole_db" "$other_db" \
  "$(dirname -- "$header_file")" "$(dirname -- "$pahole_file")" \
  "$(dirname -- "$other_file")" "$root/etc"
cp -- /var/lib/pacman/local/ALPM_DB_VERSION "$root/var/lib/pacman/local/ALPM_DB_VERSION"
printf '[options]\nArchitecture = auto\nInclude = %s/missing-dinx-mirrorlist\n' "$work_dir" > "$root/etc/pacman.conf"
printf 'fixture header\n' > "$header_file"
printf 'pahole fixture\n' > "$pahole_file"
printf 'preserved runtime file\n' > "$other_file"

cat > "$header_db/desc" <<'EOF'
%NAME%
linux-headers

%VERSION%
1.0-1

%DESC%
build-only kernel headers fixture

%DEPENDS%
pahole

%SIZE%
15

EOF
cat > "$pahole_db/desc" <<'EOF'
%NAME%
pahole

%VERSION%
1.0-1

%DESC%
build-only kernel header dependency fixture

%SIZE%
7

EOF
cat > "$pahole_db/files" <<'EOF'
%FILES%
usr/
usr/bin/
usr/bin/pahole
EOF
cat > "$header_db/files" <<'EOF'
%FILES%
usr/
usr/src/
usr/src/linux-fixture/
usr/src/linux-fixture/include/
usr/src/linux-fixture/include/dinx-fixture.h
EOF
cat > "$other_db/desc" <<'EOF'
%NAME%
dinx-prune-smoke

%VERSION%
1.0-1

%DESC%
retained package fixture

%SIZE%
24

EOF
cat > "$other_db/files" <<'EOF'
%FILES%
usr/
usr/share/
usr/share/dinx-prune-smoke/
usr/share/dinx-prune-smoke/keep
EOF

add_fixture_package() {
  local package=$1
  local dependency=${2:-}
  local reason=${3:-0}
  local package_db="$root/var/lib/pacman/local/$package-1.0-1"
  local payload="usr/share/dinx-prune-fixtures/$package/payload"
  mkdir -p -- "$package_db" "$root/$(dirname -- "$payload")"
  printf 'fixture payload for %s\n' "$package" > "$root/$payload"
  {
    printf '%%NAME%%\n%s\n\n%%VERSION%%\n1.0-1\n\n%%DESC%%\nprune fixture\n\n' "$package"
    if [[ -n "$dependency" ]]; then
      printf '%%DEPENDS%%\n%s\n\n' "$dependency"
    fi
    printf '%%REASON%%\n%s\n\n%%SIZE%%\n1\n\n' "$reason"
  } > "$package_db/desc"
  {
    printf '%%FILES%%\nusr/\nusr/share/\nusr/share/dinx-prune-fixtures/\n'
    printf 'usr/share/dinx-prune-fixtures/%s/\n%s\n' "$package" "$payload"
  } > "$package_db/files"
}
assert_calamares_icon_chain() {
  local root=$1
  local stage=$2
  local package
  for package in breeze-icons kiconthemes kio kparts calamares-smoke; do
    [[ -d "$root/var/lib/pacman/local/$package-1.0-1" ]] \
      || fail "$stage removed required Calamares dependency package: $package"
    [[ -f "$root/usr/share/dinx-prune-fixtures/$package/payload" ]] \
      || fail "$stage removed required Calamares dependency payload: $package"
  done
}
create_orphaned_vi_compat_entries() {
  local root=$1
  local name
  mkdir -p -- "$root/usr/bin"
  cat > "$root/usr/bin/vi" <<'EOF'
#!/usr/bin/bash
if [[ -n "${EXINIT}" ]]; then
  readonly VIMRC="$(mktemp)"
  trap 'rm "${VIMRC}"' EXIT
  printf '%s\n' "${EXINIT}" > "${VIMRC}"
else
  readonly VIMRC='NONE'
fi
exec /usr/bin/vim -C -u "${VIMRC}" "$@"
EOF
  chmod 0755 "$root/usr/bin/vi"
  for name in ex vedit view; do
    ln -s vim "$root/usr/bin/$name"
  done
}

assert_orphaned_vi_compat_entries_removed() {
  local root=$1
  local stage=$2
  local name
  for name in vi ex vedit view; do
    [[ ! -e "$root/usr/bin/$name" && ! -L "$root/usr/bin/$name" ]] \
      || fail "$stage retained an orphaned Vim compatibility entry: $name"
  done
}
pruned_packages=(
  breeze
  breeze-cursors
  plasma-integration
  plasma-workspace
  qogir-icon-theme
  qqc2-breeze-style
  xdg-desktop-portal-kde
  dhcpcd
  dhcpcd-dinit
  ex-vi-compat
  man-db
  man-pages
  texinfo
  vim
  vim-runtime
)
add_fixture_package dinx-breeze-runtime '' 1
add_fixture_package breeze dinx-breeze-runtime
add_fixture_package dinx-vim-runtime '' 1
add_fixture_package dinx-man-db-runtime '' 1
add_fixture_package dinx-texinfo-runtime '' 1
add_fixture_package breeze-icons '' 1
add_fixture_package kiconthemes breeze-icons 1
add_fixture_package kio kiconthemes 1
add_fixture_package kparts kio 1
add_fixture_package calamares-smoke kparts 0
for package in "${pruned_packages[@]:1}"; do
  case "$package" in
    dhcpcd-dinit) add_fixture_package "$package" dhcpcd ;;
    ex-vi-compat) add_fixture_package "$package" vim ;;
    man-db) add_fixture_package "$package" dinx-man-db-runtime ;;
    texinfo) add_fixture_package "$package" dinx-texinfo-runtime ;;
    vim) add_fixture_package "$package" vim-runtime ;;
    vim-runtime) add_fixture_package "$package" dinx-vim-runtime ;;
    *) add_fixture_package "$package" ;;
  esac
done
create_orphaned_vi_compat_entries "$root"

[[ -f "$root/usr/share/dinx-prune-fixtures/dinx-breeze-runtime/payload" ]] \
  || fail 'theme runtime fixture payload was not created'
[[ -f "$root/usr/share/dinx-prune-fixtures/breeze/payload" ]] \
  || fail 'Breeze fixture payload was not created'
[[ -f "$root/usr/share/dinx-prune-fixtures/dinx-man-db-runtime/payload" \
   && -f "$root/usr/share/dinx-prune-fixtures/dinx-texinfo-runtime/payload" ]] \
  || fail 'documentation runtime fixture payloads were not created'
fake_mksquashfs="$work_dir/mksquashfs"
cat > "$fake_mksquashfs" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -ge 2 ]]
EOF
chmod 0755 "$fake_mksquashfs"
blocked_root="$work_dir/blocked-rootfs"
cp -a -- "$root" "$blocked_root"
blocked_consumer="$blocked_root/var/lib/pacman/local/dinx-excluded-package-consumer-1.0-1"
mkdir -p -- "$blocked_consumer"
cat > "$blocked_consumer/desc" <<'EOF'
%NAME%
dinx-excluded-package-consumer

%VERSION%
1.0-1

%DESC%
runtime dependency fixture

%DEPENDS%
qogir-icon-theme


%SIZE%
1

EOF
printf '%%FILES%%\n' > "$blocked_consumer/files"
if DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$blocked_root" "$work_dir/blocked.sfs" >"$work_dir/blocked.log" 2>&1; then
  fail 'pruning removed an excluded package while a retained package depends on it'
fi
[[ -d "$blocked_root/var/lib/pacman/local/linux-headers-1.0-1" \
   && -d "$blocked_root/var/lib/pacman/local/pahole-1.0-1" \
   && -d "$blocked_root/var/lib/pacman/local/breeze-icons-1.0-1" ]] \
  || fail 'failed dependency-safe pruning partially removed package records'
for package in "${pruned_packages[@]}"; do
  [[ -d "$blocked_root/var/lib/pacman/local/$package-1.0-1" ]] \
    || fail "failed dependency-safe pruning partially removed $package"
done
assert_calamares_icon_chain "$blocked_root" 'failed prune transaction'
live_root="$work_dir/livefs"
cp -a -- "$root" "$live_root"
DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$root" "$work_dir/rootfs.sfs"
assert_orphaned_vi_compat_entries_removed "$root" 'rootfs prune'

[[ ! -e "$header_db" ]] || fail 'linux-headers package record remains in final rootfs layer'
[[ ! -e "$header_file" ]] || fail 'linux-headers payload remains in final rootfs layer'
[[ ! -e "$pahole_db" ]] || fail 'pahole package record remains in final rootfs layer'
[[ ! -e "$pahole_file" ]] || fail 'pahole payload remains in final rootfs layer'
for package in "${pruned_packages[@]}"; do
  [[ ! -e "$root/var/lib/pacman/local/$package-1.0-1" ]] \
    || fail "$package package record remains in final rootfs layer"
  [[ ! -e "$root/usr/share/dinx-prune-fixtures/$package/payload" ]] \
    || fail "$package payload remains in final rootfs layer"
done
for runtime in dinx-breeze-runtime dinx-vim-runtime dinx-man-db-runtime dinx-texinfo-runtime; do
  [[ ! -e "$root/var/lib/pacman/local/$runtime-1.0-1" \
     && ! -e "$root/usr/share/dinx-prune-fixtures/$runtime/payload" ]] \
    || fail "unused $runtime dependency remains in final rootfs layer"
done
assert_calamares_icon_chain "$root" 'rootfs prune'
preserved_vi_root="$work_dir/preserved-vi-rootfs"
cp -a -- "$root" "$preserved_vi_root"
printf '#!/usr/bin/bash\nprintf "unrelated vi implementation\\n"\n' \
  > "$preserved_vi_root/usr/bin/vi"
chmod 0755 "$preserved_vi_root/usr/bin/vi"
DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$preserved_vi_root" "$work_dir/preserved-vi.sfs"
[[ -f "$preserved_vi_root/usr/bin/vi" && ! -L "$preserved_vi_root/usr/bin/vi" ]] \
  || fail 'pruning removed an unrelated vi executable'

# A second pass has no excluded package records; stale compatibility aliases
# must still be removed from both image layers.
create_orphaned_vi_compat_entries "$root"
DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$root" "$work_dir/orphan-rootfs.sfs"
assert_orphaned_vi_compat_entries_removed "$root" 'orphan-only rootfs prune'
[[ -d "$other_db" && -f "$other_file" ]] \
  || fail 'pruning modified an unrelated package or runtime file'
DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$live_root" "$work_dir/livefs.sfs"
assert_orphaned_vi_compat_entries_removed "$live_root" 'livefs prune'
[[ ! -e "$live_root/var/lib/pacman/local/linux-headers-1.0-1" ]] \
  || fail 'linux-headers package record remains in final livefs layer'
[[ ! -e "$live_root/usr/src/linux-fixture/include/dinx-fixture.h" ]] \
  || fail 'linux-headers payload remains in final livefs layer'
[[ ! -e "$live_root/var/lib/pacman/local/pahole-1.0-1" ]] \
  || fail 'pahole package record remains in final livefs layer'
[[ ! -e "$live_root/usr/bin/pahole" ]] \
  || fail 'pahole payload remains in final livefs layer'
for package in "${pruned_packages[@]}"; do
  [[ ! -e "$live_root/var/lib/pacman/local/$package-1.0-1" ]] \
    || fail "$package package record remains in final livefs layer"
  [[ ! -e "$live_root/usr/share/dinx-prune-fixtures/$package/payload" ]] \
    || fail "$package payload remains in final livefs layer"
done
for runtime in dinx-breeze-runtime dinx-vim-runtime dinx-man-db-runtime dinx-texinfo-runtime; do
  [[ ! -e "$live_root/var/lib/pacman/local/$runtime-1.0-1" \
     && ! -e "$live_root/usr/share/dinx-prune-fixtures/$runtime/payload" ]] \
    || fail "unused $runtime dependency remains in final livefs layer"
done
assert_calamares_icon_chain "$live_root" 'livefs prune'
[[ -d "$live_root/var/lib/pacman/local/dinx-prune-smoke-1.0-1" \
   && -f "$live_root/usr/share/dinx-prune-smoke/keep" ]] \
  || fail 'livefs pruning modified an unrelated package or runtime file'
create_orphaned_vi_compat_entries "$live_root"
DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$live_root" "$work_dir/orphan-livefs.sfs"
assert_orphaned_vi_compat_entries_removed "$live_root" 'orphan-only livefs prune'
if pacman -Q linux-headers >/dev/null 2>&1; then
  builder_headers_after=present
else
  builder_headers_after=absent
fi
if pacman -Q pahole >/dev/null 2>&1; then
  builder_pahole_after=present
else
  builder_pahole_after=absent
fi
[[ "$builder_headers_after" == "$builder_headers_before" ]] \
  || fail 'pruning changed linux-headers in the ISO builder environment'
[[ "$builder_pahole_after" == "$builder_pahole_before" ]] \
  || fail 'pruning changed pahole in the ISO builder environment'

printf 'final_squashfs_package_prune_smoke builder_headers_unchanged=%s builder_pahole_unchanged=%s rootfs_excluded_unused_themes_plasma_vi_dhcpcd_docs=true livefs_excluded_unused_themes_plasma_vi_dhcpcd_docs=true calamares_kiconthemes_breeze_icons_retained=true unrelated_payload_preserved=true\n' \
  "$builder_headers_after" "$builder_pahole_after"
