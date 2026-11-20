#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/lib/pacman-local-install.sh"

fail() {
  printf 'pacman_local_install_smoke: %s\n' "$*" >&2
  exit 1
}

mode=success
install_attempts=0
refresh_attempts=0
sync_install_attempts=0
sync_update_attempts=0
expected_package='/tmp/package with spaces.pkg.tar.zst'

pacman() {
  case "${1:-}" in
    -U)
      [[ "$#" -eq 3 && "$2" == --noconfirm && "$3" == "$expected_package" ]] \
        || return 90
      install_attempts=$((install_attempts + 1))
      case "$mode" in
        transient) [[ "$install_attempts" -gt 1 ]] ;;
        persistent|sync-failure) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    -S)
      [[ "$#" -eq 4 && "$2" == --needed && "$3" == --noconfirm && "$4" == "$expected_package" ]] \
        || return 93
      sync_install_attempts=$((sync_install_attempts + 1))
      case "$mode" in
        sync-transient) [[ "$sync_install_attempts" -gt 1 ]] ;;
        sync-persistent|sync-install-refresh-failure) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    -Syy)
      [[ "$#" -eq 2 && "$2" == --noconfirm ]] || return 91
      refresh_attempts=$((refresh_attempts + 1))
      [[ "$mode" != sync-failure ]] || return 1
      ;;
    -Syu)
      [[ "$#" -eq 2 && "$2" == --noconfirm ]] || return 94
      sync_update_attempts=$((sync_update_attempts + 1))
      [[ "$mode" != sync-install-refresh-failure ]] || return 1
      ;;
    *)
      return 92
      ;;
  esac
}

pacman_retry() {
  pacman "$@"
}

sleep() {
  [[ "${1:-}" == 15 ]]
}
mode=sync-transient
sync_install_attempts=0
sync_update_attempts=0
pacman_sync_install "$expected_package" \
  || fail 'stale repository metadata was not recovered'
[[ "$sync_install_attempts" -eq 2 && "$sync_update_attempts" -eq 1 ]] \
  || fail 'repository retry did not synchronize the builder once'

mode=sync-persistent
sync_install_attempts=0
sync_update_attempts=0
if pacman_sync_install "$expected_package"; then
  fail 'persistent repository transaction failure was accepted'
fi
[[ "$sync_install_attempts" -eq 3 && "$sync_update_attempts" -eq 2 ]] \
  || fail 'persistent repository failure was not bounded'

mode=sync-install-refresh-failure
sync_install_attempts=0
sync_update_attempts=0
if pacman_sync_install "$expected_package"; then
  fail 'repository install continued after builder synchronization failed'
fi
[[ "$sync_install_attempts" -eq 1 && "$sync_update_attempts" -eq 1 ]] \
  || fail 'builder synchronization failure did not abort immediately'

mode=success
install_attempts=0
refresh_attempts=0
pacman_install_local "$expected_package" \
  || fail 'successful first attempt was rejected'
[[ "$install_attempts" -eq 1 && "$refresh_attempts" -eq 0 ]] \
  || fail 'successful install performed unnecessary retries or database refreshes'

mode=transient
install_attempts=0
refresh_attempts=0
pacman_install_local "$expected_package" \
  || fail 'transient package-download failure was not recovered'
[[ "$install_attempts" -eq 2 && "$refresh_attempts" -eq 1 ]] \
  || fail 'transient failure did not refresh databases once before retrying'

mode=persistent
install_attempts=0
refresh_attempts=0
if pacman_install_local "$expected_package"; then
  fail 'persistent package transaction failure was accepted'
fi
[[ "$install_attempts" -eq 3 && "$refresh_attempts" -eq 2 ]] \
  || fail 'persistent failure did not stop after three installs and two refreshes'

mode=sync-failure
install_attempts=0
refresh_attempts=0
if pacman_install_local "$expected_package"; then
  fail 'database refresh failure was accepted'
fi
[[ "$install_attempts" -eq 1 && "$refresh_attempts" -eq 1 ]] \
  || fail 'install continued after database refresh failed'

printf 'pacman_local_install_smoke success=true refresh_retry=true bounded_failure=true refresh_failure=true sync_install_upgrade=true sync_install_bounded=true argv_safe=true\n'
