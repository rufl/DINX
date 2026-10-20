#!/usr/bin/env bash
set -euo pipefail

repo_dir=${1:-}

fail() {
  printf 'smoke_dinx_update: %s\n' "$*" >&2
  exit 1
}

[[ -n "$repo_dir" ]] || fail "usage: $0 REPOSITORY_DIR"
[[ -d "$repo_dir" ]] || fail "repository directory does not exist: $repo_dir"

for command in gpg makepkg pacman pacman-key repo-add bsdtar sha256sum runuser; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done
if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || fail 'root or passwordless sudo is required'
  exec sudo "$0" "$@"
fi

repo_contract="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/check_dinx_package_repository.sh"
[[ -x "$repo_contract" ]] || fail "repository contract is missing: $repo_contract"
"$repo_contract" "$repo_dir" >/dev/null

work_dir=$(mktemp -d)
build_user=
created_build_user=false
cleanup() {
  set +e
  if [[ "$created_build_user" == true ]]; then
    userdel --remove "$build_user" >/dev/null 2>&1 || true
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT

key_home="$work_dir/gpg"
public_key="$work_dir/dinx-update-key.gpg"
install -d -m 700 "$key_home"
cat > "$work_dir/keyparams" <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 3072
Name-Real: DINX update smoke
Name-Email: update-smoke@dinx.invalid
Expire-Date: 0
%commit
EOF
gpg --batch --homedir "$key_home" --generate-key "$work_dir/keyparams" >/dev/null
signing_key=$(gpg --batch --homedir "$key_home" --with-colons --list-secret-keys \
  | awk -F: '$1 == "fpr" { print $10; exit }')
[[ "$signing_key" =~ ^[A-Fa-f0-9]{40}$ ]] || fail 'update smoke signing fingerprint is invalid'
gpg --batch --homedir "$key_home" --export "$signing_key" > "$public_key"

if [[ $EUID -eq 0 ]]; then
  install -d -m 700 "$work_dir/build-home"
  if id dinxbuild >/dev/null 2>&1; then
    build_user=dinxbuild
  else
    build_user=dinxupdatesmoke
    useradd --system --create-home --user-group --home-dir "$work_dir/build-home" --shell /bin/bash "$build_user"
    created_build_user=true
  fi
  chown -R "$build_user:$build_user" "$work_dir" "$key_home"
fi

build_fixture() {
  local version=$1
  local destination="$work_dir/build-$version"
  mkdir -p "$destination"
  cat > "$destination/PKGBUILD" <<EOF
pkgname=dinx-update-fixture
pkgver=$version
pkgrel=1
pkgdesc='DINX signed update smoke fixture'
arch=('x86_64')
license=('MIT')

package() {
  install -d "\$pkgdir/usr/share/dinx-update-fixture"
  printf '%s\\n' "\$pkgver" > "\$pkgdir/usr/share/dinx-update-fixture/version"
}
EOF
  chown -R "${build_user:-$(id -un)}:${build_user:-$(id -gn)}" "$destination"
  if [[ -n "$build_user" ]]; then
    runuser -u "$build_user" -- env \
      HOME="$work_dir/build-home" \
      GNUPGHOME="$key_home" \
      makepkg --clean --nodeps --nocheck --noconfirm --sign --key "$signing_key" \
      --dir "$destination" >/dev/null
  else
    ( 
      cd "$destination"
      GNUPGHOME="$key_home" makepkg --clean --nodeps --nocheck --noconfirm \
        --sign --key "$signing_key" >/dev/null
    )
  fi
  find "$destination" -maxdepth 1 -type f \
    \( -name 'dinx-update-fixture-*.pkg.tar.*' -o -name 'dinx-update-fixture-*.pkg.tar.*.sig' \) \
    -print
}

pkg_v1=$(build_fixture 1.0.0 | awk '/\.pkg\.tar\.[^.]+$/ { print; exit }')
pkg_v2=$(build_fixture 2.0.0 | awk '/\.pkg\.tar\.[^.]+$/ { print; exit }')
sig_v1="$pkg_v1.sig"
sig_v2="$pkg_v2.sig"
[[ -s "$pkg_v1" && -s "$sig_v1" ]] || fail 'version 1 fixture package or signature is missing'
[[ -s "$pkg_v2" && -s "$sig_v2" ]] || fail 'version 2 fixture package or signature is missing'

repo_v1="$work_dir/repo-v1"
repo_v2="$work_dir/repo-v2"
mkdir -p "$repo_v1" "$repo_v2"
cp -- "$pkg_v1" "$sig_v1" "$repo_v1/"
cp -- "$pkg_v2" "$sig_v2" "$repo_v2/"
GNUPGHOME="$key_home" repo-add --include-sigs --sign --key "$signing_key" \
  "$repo_v1/dinx.db.tar.gz" "$repo_v1"/dinx-update-fixture-*.pkg.tar.zst
GNUPGHOME="$key_home" repo-add --include-sigs --sign --key "$signing_key" \
  "$repo_v2/dinx.db.tar.gz" "$repo_v2"/dinx-update-fixture-*.pkg.tar.zst

pacman_gpg="$work_dir/pacman-gnupg"
pacman_root="$work_dir/root"
pacman_cache="$pacman_root/var/cache/pacman/pkg"
pacman_db="$pacman_root/var/lib/pacman"
pacman_conf="$work_dir/pacman.conf"
mkdir -p "$pacman_root/etc" "$pacman_cache" "$pacman_db" "$pacman_root/usr/share"
install -d -m 700 "$pacman_gpg"
pacman-key --gpgdir "$pacman_gpg" --init >/dev/null
pacman-key --gpgdir "$pacman_gpg" --add "$public_key" >/dev/null
pacman-key --gpgdir "$pacman_gpg" --lsign-key "$signing_key" >/dev/null

write_pacman_conf() {
  local repository=$1
  cat > "$pacman_conf" <<EOF
[options]
Architecture = auto
SigLevel = Required

[dinx]
SigLevel = Required
Server = file://$repository
EOF
}

pacman_run() {
  pacman --root "$pacman_root" \
    --dbpath "$pacman_db" \
    --cachedir "$pacman_cache" \
    --gpgdir "$pacman_gpg" \
    --config "$pacman_conf" \
    "$@"
}

assert_version() {
  local expected=$1
  local actual
  actual=$(cat "$pacman_root/usr/share/dinx-update-fixture/version")
  [[ "$actual" == "$expected" ]] || fail "fixture payload version mismatch: expected=$expected actual=$actual"
  pacman_run -Q dinx-update-fixture | awk '{ print $2 }' | grep -Fqx "$expected" \
    || fail "pacman database version mismatch: expected=$expected"
}

write_pacman_conf "$repo_v1"
pacman_run -Sy --noconfirm >/dev/null
pacman_run -S --noconfirm dinx-update-fixture >/dev/null
assert_version 1.0.0

write_pacman_conf "$repo_v2"
pacman_run -Sy --noconfirm >/dev/null
pacman_run -Su --noconfirm >/dev/null
assert_version 2.0.0

cached_v1="$pacman_cache/$(basename "$pkg_v1")"
[[ -s "$cached_v1" ]] || fail 'previous package was not retained in the pacman cache'
pacman_run -U --noconfirm "$cached_v1" >/dev/null
assert_version 1.0.0

printf 'dinx_update_smoke repository_contract=true signed_install=true update=true cached_package_rollback=true filesystem_rollback=not-claimed\n'
