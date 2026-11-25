pacman_sync_install() {
  local attempt
  for attempt in 1 2 3; do
    if pacman -S --needed --noconfirm "$@"; then
      return 0
    fi
    [[ "$attempt" -lt 3 ]] || break
    printf 'pacman_sync_install: repository transaction failed (attempt %s/3); synchronizing the builder before retry\n' \
      "$attempt" >&2
    if ! pacman_retry -Syu --noconfirm; then
      printf 'pacman_sync_install: builder synchronization failed; aborting repository transaction\n' >&2
      return 1
    fi
    sleep 15
  done
  printf 'pacman_sync_install: repository transaction failed after 3 attempts\n' >&2
  return 1
}

pacman_install_local() {
  local attempt
  for attempt in 1 2 3; do
    if pacman -U --noconfirm "$@"; then
      return 0
    fi
    [[ "$attempt" -lt 3 ]] || break
    printf 'pacman_install_local: local package transaction failed (attempt %s/3); refreshing databases before retry\n' \
      "$attempt" >&2
    if ! pacman_retry -Syy --noconfirm; then
      printf 'pacman_install_local: database refresh failed; aborting local package transaction\n' >&2
      return 1
    fi
    sleep 15
  done
  printf 'pacman_install_local: local package transaction failed after 3 attempts\n' >&2
  return 1
}
