#!/usr/bin/env bash
set -euo pipefail

host_uid=${DINX_HOST_UID:-}
host_gid=${DINX_HOST_GID:-}
build_uid=
build_gid=
repo_pid=
optional_build_pids=()
builder_started=$SECONDS
finish() {
  local status=$?
  local elapsed=$((SECONDS - builder_started))
  local path pid
  trap - EXIT
  for pid in "${optional_build_pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    wait "$pid" 2>/dev/null || true
  done
  if [[ -n "$repo_pid" ]]; then
    kill "$repo_pid" 2>/dev/null || true
  fi
  if [[ "$host_uid" =~ ^[0-9]+$ && "$host_gid" =~ ^[0-9]+$ ]]; then
    for path in "${DINX_ISO_OUTPUT:-}" "${DINX_PACKAGE_OUTPUT:-}" /var/lib/artools/buildiso /var/cache/dinx /workspace/distro/packages; do
      [[ -n "$path" && -e "$path" ]] || continue
      if [[ "$path" == /var/lib/artools/buildiso \
        && ( ( "$status" -eq 0 && "${DINX_REMOVE_CHROOTS_AFTER_BUILD:-false}" == true ) \
          || "${DINX_PACKAGE_REPOSITORY_ONLY:-false}" == true ) ]]; then
        continue
      fi
      if [[ "$host_uid" == "$build_uid" && "$host_gid" == "$build_gid" \
        && ( "$path" == /var/cache/dinx || "$path" == /workspace/distro/packages ) ]]; then
        continue
      fi
      local chown_started=$SECONDS
      if ! chown -R -- "$host_uid:$host_gid" "$path"; then
        printf 'build-iso-container: failed to restore ownership of %s\n' "$path" >&2
        (( status != 0 )) || status=1
      else
        printf 'dinx-build-timing phase=ownership-restore path=%s elapsed_seconds=%s exit_status=0\n' \
          "$path" "$((SECONDS - chown_started))"
      fi
    done
  fi
  printf 'dinx-build-timing phase=container-total elapsed_seconds=%s exit_status=%s\n' "$elapsed" "$status"
  exit "$status"
}
trap finish EXIT
              set -euxo pipefail
              package_repository_only=${DINX_PACKAGE_REPOSITORY_ONLY:-false}
              [[ "$package_repository_only" == true || "$package_repository_only" == false ]]
              DINX_ARTIX_IMAGE="${DINX_ARTIX_IMAGE:-artixlinux/artixlinux@sha256:e746e31ffe48f9526759711de0a3bc4cb7a8f61d7339dc9b11fe6bee4a722507}"
              export DINX_ARTIX_IMAGE
              : "${DINX_BUILDER_RECIPE_SHA256:?builder recipe checksum was not forwarded}"
              : "${DINX_BUILDER_IMAGE_ID:?builder image ID was not forwarded}"
              : "${DINX_BUILDER_REFRESH_DATE:?builder refresh date was not forwarded}"
              [[ "$DINX_BUILDER_RECIPE_SHA256" =~ ^[0-9a-f]{64}$ ]]
              [[ "$DINX_BUILDER_IMAGE_ID" =~ ^sha256:[0-9a-f]{64}$ ]]
              [[ "$DINX_BUILDER_REFRESH_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
              artix_mirrorlist_source=official-artix-https-tier1
              {
                printf '%s\n' '# DINX official Artix HTTPS mirrors'
                printf '%s\n' 'Server = https://mirror2.artixlinux.org/$repo/os/$arch'
                printf '%s\n' 'Server = https://mirror3.artixlinux.org/repos/$repo/os/$arch'
              } > /etc/pacman.d/mirrorlist
              grep -Eq '^Server = https://' /etc/pacman.d/mirrorlist
              builder_mirrorlist_source="$artix_mirrorlist_source"
              pacman_retry() {
                local attempt
                for attempt in 1 2 3; do
                  if pacman "$@"; then
                    return 0
                  fi
                  if [[ "$attempt" -lt 3 ]]; then
                    sleep 15
                  fi
                done
                return 1
              }
              source /workspace/scripts/lib/pacman-local-install.sh
              source /workspace/scripts/lib/dinx-package-artifact-cache.sh
              builder_image_verify_started=$SECONDS
              builder_image_marker=/etc/dinx-builder-image/metadata
              grep -Fqx "artix_image=$DINX_ARTIX_IMAGE" "$builder_image_marker"
              grep -Fqx "recipe_sha256=$DINX_BUILDER_RECIPE_SHA256" "$builder_image_marker"
              grep -Fqx "refresh_date=$DINX_BUILDER_REFRESH_DATE" "$builder_image_marker"
              command -v buildiso >/dev/null
              scripts/check_iso_builder_packages.sh /workspace/scripts/iso-builder/packages.txt
              scripts/check_artix_initcpio_patch.sh --check-installed
              printf 'dinx-build-timing phase=builder-image-verify elapsed_seconds=%s exit_status=0 image_id=%s\n' \
                "$((SECONDS - builder_image_verify_started))" "$DINX_BUILDER_IMAGE_ID"
              update-mime-database /usr/share/mime
              mkdir -p /usr/lib/gdk-pixbuf-2.0/2.10.0
              gdk-pixbuf-query-loaders --update-cache
              toolchain_started=$SECONDS
              zig_version=0.17.0
              zig_archive="zig-x86_64-linux-${zig_version}.tar.xz"
              zig_sha256=1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026
              toolchain_cache="${DINX_BUILD_CACHE_DIR:-/var/cache/dinx}/toolchains"
              toolchain_extraction_cache="$toolchain_cache/extracted"
              mkdir -p "$toolchain_cache" "$toolchain_extraction_cache"
              toolchain_dirty_marker=${DINX_TOOLCHAIN_CACHE_DIRTY_MARKER:-${DINX_CACHE_DIRTY_MARKER:-}}
              zig_archive_path="$toolchain_cache/$zig_archive"
              DINX_CACHE_DIRTY_MARKER="$toolchain_dirty_marker" \
                scripts/cache-verified-download.sh \
                  "$zig_archive_path" \
                  "https://ziglang.org/download/${zig_version}/${zig_archive}" \
                  "$zig_sha256"
              zig_root="$toolchain_extraction_cache/zig-${zig_version}-${zig_sha256}"
              DINX_CACHE_DIRTY_MARKER="$toolchain_dirty_marker" \
                scripts/cache-verified-extract.sh \
                  "$zig_archive_path" "$zig_sha256" "$zig_version" zig "$zig_root"
              export PATH="$zig_root:$PATH"
              printf "zig_version=%s\n" "$(zig version)"
              source /workspace/distro/packages/pearl/source.env
              : "${PEARL_ZIG_VERSION:?PEARL_ZIG_VERSION is missing}"
              : "${PEARL_ZIG_SOURCE_URL:?PEARL_ZIG_SOURCE_URL is missing}"
              : "${PEARL_ZIG_SOURCE_SHA256:?PEARL_ZIG_SOURCE_SHA256 is missing}"
              pearl_zig_archive="zig-x86_64-linux-${PEARL_ZIG_VERSION}.tar.xz"
              pearl_zig_archive_path="$toolchain_cache/$pearl_zig_archive"
              DINX_CACHE_DIRTY_MARKER="$toolchain_dirty_marker" \
                scripts/cache-verified-download.sh \
                  "$pearl_zig_archive_path" \
                  "$PEARL_ZIG_SOURCE_URL" \
                  "$PEARL_ZIG_SOURCE_SHA256"
              pearl_zig_root="$toolchain_extraction_cache/zig-${PEARL_ZIG_VERSION}-${PEARL_ZIG_SOURCE_SHA256}"
              DINX_CACHE_DIRTY_MARKER="$toolchain_dirty_marker" \
                scripts/cache-verified-extract.sh \
                  "$pearl_zig_archive_path" "$PEARL_ZIG_SOURCE_SHA256" \
                  "$PEARL_ZIG_VERSION" zig "$pearl_zig_root"
              printf 'dinx-build-timing phase=toolchain-setup elapsed_seconds=%s exit_status=0\n' \
                "$((SECONDS - toolchain_started))"

              # Run before makepkg --clean removes source trees used by the static theme contract.
              scripts/check_dinx_theme.sh
              package_repo=${DINX_PACKAGE_OUTPUT:-/workspace/dist/packages}
              rm -rf "$package_repo"
              mkdir -p "$package_repo"
              makepkg_base_conf=/tmp/dinx-makepkg-base.conf
              cp /etc/makepkg.conf "$makepkg_base_conf"
              makepkg_base_conf_sha256=$(sha256sum "$makepkg_base_conf" | cut -d " " -f 1)
              makepkg_source_cache=/var/cache/dinx/makepkg-sources
              cargo_cache=/var/cache/dinx/cargo
              cargo_target_cache=/var/cache/dinx/cargo-target
              zig_cache=/var/cache/dinx/zig
              package_artifact_cache=/var/cache/dinx/package-artifacts
              mkdir -p "$makepkg_source_cache" "$cargo_cache" "$cargo_target_cache" \
                "$zig_cache" "$package_artifact_cache"
              chmod 644 "$makepkg_base_conf"
              useradd --create-home --user-group dinxbuild
              build_uid=$(id -u dinxbuild)
              build_gid=$(id -g dinxbuild)
              if [[ "$build_uid" == "$host_uid" && "$build_gid" == "$host_gid" ]]; then
                chown dinxbuild:dinxbuild \
                  "$package_repo" "$makepkg_source_cache" "$cargo_cache" "$cargo_target_cache" "$zig_cache" "$package_artifact_cache"
              else
                chown -R dinxbuild:dinxbuild \
                  /workspace/distro/packages "$package_repo" "$makepkg_source_cache" "$cargo_cache" \
                  "$cargo_target_cache" "$zig_cache" "$package_artifact_cache"
              fi
              signing_home=/tmp/dinx-package-signing
              rm -rf "$signing_home"
              install -d -m 700 "$signing_home"
              package_repository_channel=ci
              package_signing_mode=ephemeral-ci
              if [[ "${DINX_REQUIRE_PERSISTENT_PACKAGE_SIGNING:-false}" == true ]]; then
                set +x
                package_key_present=false
                if [[ -n "${DINX_PACKAGE_SIGNING_KEY:-}" ]]; then
                  package_key_present=true
                fi
                set -x
                if [[ "$package_key_present" != true ]]; then
                  printf 'A persistent DINX_PACKAGE_SIGNING_KEY is required for this release build.\n' >&2
                  exit 1
                fi
                package_repository_channel=stable
                package_signing_mode=persistent
                signing_key_file="$signing_home/private.asc"
                set +x
                printf '%s\n' "$DINX_PACKAGE_SIGNING_KEY" > "$signing_key_file"
                gpg --batch --homedir "$signing_home" --import "$signing_key_file" >/dev/null
                rm -f "$signing_key_file"
                set -x
              else
                printf '%s\n' \
                  '%no-protection' \
                  'Key-Type: RSA' \
                  'Key-Length: 3072' \
                  'Name-Real: DINX CI package repository' \
                  'Name-Email: ci@dinx.invalid' \
                  'Expire-Date: 0' \
                  '%commit' \
                  > "$signing_home/keyparams"
                gpg --batch --homedir "$signing_home" --generate-key "$signing_home/keyparams" >/dev/null
              fi
              signing_key=$(gpg --batch --homedir "$signing_home" --with-colons --list-secret-keys \
                | awk -F: '$1 == "fpr" { print $10; exit }')
              [[ "$signing_key" =~ ^[A-Fa-f0-9]{40}$ ]]
              if [[ -n "${DINX_PACKAGE_SIGNING_FINGERPRINT:-}" ]]; then
                [[ "${signing_key,,}" == "${DINX_PACKAGE_SIGNING_FINGERPRINT,,}" ]] \
                  || { printf 'DINX_PACKAGE_SIGNING_FINGERPRINT does not match the imported key.\n' >&2; exit 1; }
              fi
              gpg --batch --homedir "$signing_home" --export "$signing_key" \
                > "$package_repo/dinx-package-signing-key.gpg"
              chown -R dinxbuild:dinxbuild "$signing_home"
              pacman-key --init
              pacman-key --add "$package_repo/dinx-package-signing-key.gpg"
              pacman-key --lsign-key "$signing_key"
              package_cache_as_build_user() {
                local operation="$1"
                shift
                runuser -u dinxbuild -- bash -c '
                  set -euo pipefail
                  source "$1"
                  operation=$2
                  shift 2
                  "$operation" "$@"
                ' _ /workspace/scripts/lib/dinx-package-artifact-cache.sh "$operation" "$@"
              }



              build_package() {
                local package_name="$1"
                local package_dir="/workspace/distro/packages/$package_name"
                local package_started=$SECONDS
                local package_output="/tmp/dinx-package-output/$package_name"
                local package_source_cache="$makepkg_source_cache/$package_name"
                local package_makepkg_conf="/tmp/dinx-makepkg-$package_name.conf"
                local status archive archive_name installed_packages_sha256 cache_key
                local -a extra_env=(
                  "CARGO_HOME=/var/cache/dinx/cargo"
                  "CARGO_TARGET_DIR=/var/cache/dinx/cargo-target/$package_name"
                  "ZIG_GLOBAL_CACHE_DIR=/var/cache/dinx/zig/$package_name"
                )
                local -a makepkg_options=(--nodeps --nocheck --noconfirm)
                local -a package_archives=()
                case "$package_name" in
                  dinitui|dinxpanel|seafoam-settings)
                    # These packages build directly from checked-in source trees.
                    ;;
                  dome)
                    # A failed Zig build can leave partial dependency state in $srcdir.
                    makepkg_options+=(--clean --cleanbuild)
                    ;;
                  *)
                    makepkg_options+=(--clean)
                    ;;
                esac
                if [[ "$package_name" == deetty ]]; then
                  extra_env+=(GLYCIN_DISABLE_SANDBOX=i-know-the-risks)
                  makepkg_options+=(--cleanbuild)
                fi
                if [[ "$package_name" == cyan-skillfish-governor-smu ]]; then
                  extra_env+=(CARGO_BUILD_JOBS=1)
                fi
                if [[ "$package_name" == pearl || "$package_name" == phyto || "$package_name" == dome ]]; then
                  extra_env+=("ZIG=$pearl_zig_root/zig")
                elif [[ "$package_name" == pori || "$package_name" == aqueous ]]; then
                  extra_env+=("ZIG=$zig_root/zig")
                fi

                installed_packages_sha256=$(pacman -Q | LC_ALL=C sort | sha256sum)
                installed_packages_sha256=${installed_packages_sha256%% *}
                cache_key=$(dinx_package_cache_key \
                  "$package_name" "$package_dir" "$makepkg_base_conf_sha256" \
                  "$package_cache_recipe_sha256" "$installed_packages_sha256" /workspace \
                  "${makepkg_options[@]}" -- "${extra_env[@]}")
                if package_cache_as_build_user dinx_package_cache_restore \
                  "$package_artifact_cache" "$package_name" "$cache_key" "$package_repo" "$signing_home"; then
                  printf 'dinx-build-timing package=%s elapsed_seconds=%s exit_status=0 cache=hit\n' \
                    "$package_name" "$((SECONDS - package_started))"
                  return 0
                else
                  status=$?
                  if [[ "$status" -ne 1 ]]; then
                    printf 'dinx-build-timing package=%s elapsed_seconds=%s exit_status=%s cache=error\n' \
                      "$package_name" "$((SECONDS - package_started))" "$status"
                    return "$status"
                  fi
                fi
                if [[ -n ${DINX_CACHE_DIRTY_MARKER:-} ]]; then
                  touch -- "$DINX_CACHE_DIRTY_MARKER"
                fi

                rm -rf -- "$package_output"
                mkdir -p -- "$package_output" "$package_source_cache" \
                  "$cargo_target_cache/$package_name" "$zig_cache/$package_name"
                chown -R dinxbuild:dinxbuild \
                  "$package_output" "$package_source_cache" \
                  "$cargo_target_cache/$package_name" "$zig_cache/$package_name"
                cp -- "$makepkg_base_conf" "$package_makepkg_conf"
                printf '%q\n' "PKGDEST=$package_output" "SRCDEST=$package_source_cache" \
                  >> "$package_makepkg_conf"
                chmod 644 "$package_makepkg_conf"
                if (
                  cd "$package_dir"
                  runuser -u dinxbuild -- env "${extra_env[@]}" \
                    MAKEPKG_CONF="$package_makepkg_conf" \
                    GNUPGHOME="$signing_home" \
                    makepkg "${makepkg_options[@]}" \
                    --sign --key "$signing_key"
                ); then
                  mapfile -d '' package_archives < <(
                    find "$package_output" -maxdepth 1 -type f -name '*.pkg.tar.zst' -print0
                  )
                  if ((${#package_archives[@]} == 0)); then
                    printf 'build-iso-container: makepkg produced no package archive for %s\n' "$package_name" >&2
                    return 1
                  fi
                  for archive in "${package_archives[@]}"; do
                    [[ -f "$archive.sig" && ! -L "$archive.sig" ]] || {
                      printf 'build-iso-container: makepkg produced no signature for %s\n' "$archive" >&2
                      return 1
                    }
                  done
                  if package_cache_as_build_user dinx_package_cache_store \
                    "$package_artifact_cache" "$package_name" "$cache_key" "${package_archives[@]}"; then
                    if [[ -n ${DINX_PACKAGE_CACHE_DIRTY_MARKER:-} ]]; then
                      touch -- "$DINX_PACKAGE_CACHE_DIRTY_MARKER"
                    fi
                  else
                    printf 'dinx-package-cache: store skipped package=%s key=%s\n' "$package_name" "$cache_key" >&2
                  fi
                  for archive in "${package_archives[@]}"; do
                    archive_name=$(basename -- "$archive")
                    mv -- "$archive" "$package_repo/$archive_name"
                    mv -- "$archive.sig" "$package_repo/$archive_name.sig"
                  done
                  rm -rf -- "$package_output"
                  printf 'dinx-build-timing package=%s elapsed_seconds=%s exit_status=0 cache=miss\n' \
                    "$package_name" "$((SECONDS - package_started))"
                else
                  status=$?
                  printf 'dinx-build-timing package=%s elapsed_seconds=%s exit_status=%s cache=miss\n' \
                    "$package_name" "$((SECONDS - package_started))" "$status"
                  return "$status"
                fi
              }
              package_cache_recipe_sha256=$(
                { declare -f package_cache_as_build_user; declare -f build_package; } | sha256sum
              )
              package_cache_recipe_sha256=${package_cache_recipe_sha256%% *}
              build_package ghostty-vt-runtime
              ghostty_vt_package=$(find "$package_repo" -maxdepth 1 -type f -name 'ghostty-vt-runtime-*.pkg.tar.zst' -print -quit)
              [[ -n "$ghostty_vt_package" ]]
              pacman -Rdd --noconfirm ghostty
              pacman_install_local "$ghostty_vt_package"
              scripts/check_ghostty_vt_runtime.sh "$ghostty_vt_package"
              source /workspace/distro/packages/deetty/source.env
              [[ -n "$DEETTY_VERSION" ]]
              icon_svg=/tmp/dinx-dintor-icon.svg
              icon_png=/usr/share/icons/hicolor/128x128/apps/org.dinx.Dintor.png
              tar -xOf \
                "/workspace/distro/packages/deetty/deetty-${DEETTY_VERSION}.tar.gz" \
                "deetty-${DEETTY_VERSION}/resources/com.noctty.NoctEd.svg" \
                > "$icon_svg"
              mkdir -p "$(dirname "$icon_png")"
              rsvg-convert -w 128 -h 128 -o "$icon_png" "$icon_svg"
              gtk-update-icon-cache -f /usr/share/icons/hicolor
              rm -f "$icon_svg"
              build_package deetty
              pacman_install_local "$package_repo"/deetty-*.pkg.tar.zst
              build_package topgrade
              build_package paru
              build_package shelly
              pacman_install_local \
                "$package_repo"/topgrade-*.pkg.tar.zst \
                "$package_repo"/shelly-*.pkg.tar.zst
              build_package dinitui
              pacman_install_local "$package_repo"/dinitui-*.pkg.tar.zst
              DINITUI_BIN=/usr/bin/dinitui scripts/dinitui_dinit_qualification.sh
              build_package calamares
              pacman_install_local "$package_repo"/calamares-*.pkg.tar.zst
              if pacman -Qq plasma-integration >/dev/null 2>&1; then
                pacman -Rns --noconfirm plasma-integration
              fi
              scripts/smoke_calamares_startup.sh
              build_package dinxpanel
              pacman_install_local "$package_repo"/dinxpanel-*.pkg.tar.zst
              build_package shikane
              pacman_install_local "$package_repo"/shikane-*.pkg.tar.zst
              pacman_retry -S --needed --noconfirm wdisplays qt6ct
              build_package matugen
              pacman_install_local "$package_repo"/matugen-*.pkg.tar.zst
              build_package aqueous
              build_package pearl
              pacman_install_local \
                "$package_repo"/aqueous-*.pkg.tar.zst \
                "$package_repo"/pearl-*.pkg.tar.zst
              build_package pori
              build_package phyto
              build_package dome
              build_package zls
              build_package seafoam-settings
              pacman_install_local \
                "$package_repo"/dome-*.pkg.tar.zst \
                "$package_repo"/seafoam-settings-*.pkg.tar.zst \
                "$package_repo"/zls-*.pkg.tar.zst
              SEAFOAM_SETTINGS_BIN=/usr/bin/seafoam-settings scripts/seafoam_settings_smoke.sh
              ZLS_BIN=/usr/bin/zls scripts/smoke_zls.sh
              pacman_retry -S --needed --noconfirm python-fonttools vala gst-plugins-base gst-plugins-good
              build_package dinx-noto-latin
              build_package dinx-plymouth-theme
              build_package dinx-live-autologin
              build_package swayimg
              build_package gapless
              build_package dinx-keyring
              build_package opensnitch-dinit
              build_package floorp
              build_package patchy
              build_package blockbench
              build_package impasto
              build_package pixelorama
              build_package onlyoffice
              build_package zrythm
              # Build Haruna against its Artix runtime/build dependencies. Artix does not package it.
              pacman_retry -S --needed --noconfirm \
                extra-cmake-modules ffmpeg kcolorscheme kconfig kcoreaddons kcrash \
                kdeclarative kdsingleapplication kfilemetadata ki18n kio kirigami \
                kitemmodels kservice kwindowsystem mpvqt qqc2-desktop-style \
                qt6-5compat qt6-declarative
              build_package haruna
              if [[ "$package_repository_only" != true ]]; then
              repository_seed_started=$SECONDS
              GNUPGHOME="$signing_home" repo-add --include-sigs --sign --key "$signing_key" \
                "$package_repo/dinx.db.tar.gz" "$package_repo"/*.pkg.tar.zst
              rm -f "$package_repo/dinx.db" "$package_repo/dinx.db.sig"
              cp -- "$package_repo/dinx.db.tar.gz" "$package_repo/dinx.db"
              cp -- "$package_repo/dinx.db.tar.gz.sig" "$package_repo/dinx.db.sig"
              printf 'dinx-build-timing phase=package-repository-seed elapsed_seconds=%s exit_status=0\n' \
                "$((SECONDS - repository_seed_started))"

              pacman_conf=$(find /usr/share/artools -type f \
                -path "*/pacman.conf.d/iso-x86_64.conf" -print -quit)
              test -n "$pacman_conf"
              printf "\n[dinx]\nSigLevel = Required\nServer = http://127.0.0.1:8765\n" \
                >> "$pacman_conf"
              # Pacman 7's alpm downloader cannot write basestrap's root-owned alternate-root sync DB.
              pacman_options_tmp="$pacman_conf.dinx"
              awk '
                /^[[:space:]]*DownloadUser[[:space:]]*=/ { next }
                /^\[options\][[:space:]]*$/ && !injected {
                  print
                  print "DownloadUser = root"
                  print "NoExtract = usr/lib/systemd"
                  print "NoExtract = usr/lib/systemd/*"
                  print "NoExtract = etc/systemd"
                  print "NoExtract = etc/systemd/*"
                  print "NoExtract = usr/share/uwsm"
                  print "NoExtract = usr/share/uwsm/*"
                  print "NoExtract = usr/bin/systemd"
                  print "NoExtract = usr/bin/systemctl"
                  print "NoExtract = usr/share/wayland-sessions/plasma.desktop"
                  print "NoExtract = usr/bin/uwsm"
                  print "NoExtract = etc/calamares-config-switcher.conf"
                  print "NoExtract = usr/bin/calamares-config-switcher"
                  print "NoExtract = usr/share/applications/calamares-config-switcher.desktop"
                  print "NoExtract = usr/lib/calamares/modules/basestrap/*"
                  print "NoExtract = usr/share/calamares/modules/basestrap.conf"
                  print "NoExtract = usr/share/calamares/branding/artix/*"
                  print "NoExtract = usr/share/calamares/branding/artix-next/*"
                  injected = 1
                  next
                }
                { print }
                END {
                  if (!injected) exit 1
                }
              ' "$pacman_conf" > "$pacman_options_tmp"
              mv -- "$pacman_options_tmp" "$pacman_conf"
              [[ $(grep -Ec '^[[:space:]]*DownloadUser[[:space:]]*=' "$pacman_conf") -eq 1 ]]
              grep -Fqx 'DownloadUser = root' "$pacman_conf"
              grep -Fqx 'NoExtract = usr/lib/systemd/*' "$pacman_conf"
              grep -Fqx 'NoExtract = etc/systemd/*' "$pacman_conf"
              grep -Fqx 'NoExtract = usr/share/uwsm/*' "$pacman_conf"
              grep -Fqx 'NoExtract = usr/share/wayland-sessions/plasma.desktop' "$pacman_conf"
              for excluded_path in \
                'NoExtract = etc/calamares-config-switcher.conf' \
                'NoExtract = usr/bin/calamares-config-switcher' \
                'NoExtract = usr/share/applications/calamares-config-switcher.desktop' \
                'NoExtract = usr/lib/calamares/modules/basestrap/*' \
                'NoExtract = usr/share/calamares/modules/basestrap.conf' \
                'NoExtract = usr/share/calamares/branding/artix/*' \
                'NoExtract = usr/share/calamares/branding/artix-next/*'; do
                grep -Fqx "$excluded_path" "$pacman_conf"
              done
              builder_pacman_conf_sha256=$(sha256sum "$pacman_conf" | cut -d " " -f 1)
              builder_mirrorlist=/etc/pacman.d/mirrorlist
              test -r "$builder_mirrorlist"
              builder_mirrorlist_sha256=$(sha256sum "$builder_mirrorlist" | cut -d " " -f 1)
              builder_mirrorlist_source="$artix_mirrorlist_source"
              python -m http.server 8765 \
                --bind 127.0.0.1 \
                --directory "$package_repo" \
                >/tmp/dinx-package-repo.log 2>&1 &
              repo_pid=$!
              repo_ready=false
              for _ in {1..30}; do
                if curl --fail --silent --show-error --max-time 2 \
                  http://127.0.0.1:8765/dinx.db --output /dev/null; then
                  repo_ready=true
                  break
                fi
                if ! kill -0 "$repo_pid" 2>/dev/null; then
                  break
                fi
                sleep 1
              done
              if [[ "$repo_ready" != true ]]; then
                cat /tmp/dinx-package-repo.log >&2 || true
                printf 'build-iso-container: signed package repository HTTP server did not become ready\n' >&2
                exit 1
              fi
              fi
              optional_build_started=$SECONDS
              build_package cyan-skillfish-governor-smu &
              optional_build_pids+=("$!")
              build_package cyan-skillfish-governor-smu-dinit &
              optional_build_pids+=("$!")
              build_package bc250-control-center &
              optional_build_pids+=("$!")

              if [[ "$package_repository_only" != true ]]; then
              mksquashfs_path=$(command -v mksquashfs)
              real_mksquashfs=$(readlink -f "$mksquashfs_path")
              test -x "$real_mksquashfs"
              install -D -m 0755 "$real_mksquashfs" /usr/local/libexec/dinx-mksquashfs.real
              install -m 0755 /workspace/scripts/iso-tools/mksquashfs /usr/bin/mksquashfs
              export DINX_MKSQUASHFS_REAL=/usr/local/libexec/dinx-mksquashfs.real
              hash -r
              mksquashfs_path=$(command -v mksquashfs)
              test "$(readlink -f "$mksquashfs_path")" = /usr/bin/mksquashfs
              printf 'dinx_mksquashfs_wrapper=%s real=%s\n' "$mksquashfs_path" "$DINX_MKSQUASHFS_REAL"
              scripts/smoke_final_squashfs_package_exclusions.sh
              dinx_invalidate_pacman_package_cache "$package_repo" /var/cache/pacman/pkg

              iso_assembly_started=$SECONDS
              if scripts/build-iso.sh; then
                printf 'dinx-build-timing phase=iso-assembly elapsed_seconds=%s exit_status=0\n' \
                  "$((SECONDS - iso_assembly_started))"
              else
                status=$?
                printf 'dinx-build-timing phase=iso-assembly elapsed_seconds=%s exit_status=%s\n' \
                  "$((SECONDS - iso_assembly_started))" "$status"
                exit "$status"
              fi
              fi
              optional_build_status=0
              for optional_pid in "${optional_build_pids[@]}"; do
                if wait "$optional_pid"; then
                  :
                else
                  optional_build_status=$?
                fi
              done
              optional_build_pids=()
              printf 'dinx-build-timing phase=optional-hardware-packages elapsed_seconds=%s exit_status=%s\n' \
                "$((SECONDS - optional_build_started))" "$optional_build_status"
              (( optional_build_status == 0 )) || exit "$optional_build_status"
              if [[ -n "$repo_pid" ]]; then
                kill "$repo_pid" 2>/dev/null || true
                wait "$repo_pid" 2>/dev/null || true
                repo_pid=
              fi
              repository_finalize_started=$SECONDS
              GNUPGHOME="$signing_home" repo-add --include-sigs --sign --key "$signing_key" \
                "$package_repo/dinx.db.tar.gz" "$package_repo"/*.pkg.tar.zst
              rm -f "$package_repo/dinx.db" "$package_repo/dinx.db.sig"
              cp -- "$package_repo/dinx.db.tar.gz" "$package_repo/dinx.db"
              cp -- "$package_repo/dinx.db.tar.gz.sig" "$package_repo/dinx.db.sig"
              package_count=$(find "$package_repo" -maxdepth 1 -type f \
                -name "*.pkg.tar.zst" | awk 'END { print NR }')
              package_repository_snapshot=$(
                find "$package_repo" -maxdepth 1 -type f -name "*.pkg.tar.zst" -printf "%f\n" \
                  | LC_ALL=C sort \
                  | while IFS= read -r package_name; do
                      digest=$(sha256sum "$package_repo/$package_name" | cut -d " " -f 1)
                      printf "%s  %s\n" "$digest" "$package_name"
                    done \
                  | LC_ALL=C sort \
                  | sha256sum \
                  | cut -d " " -f 1
              )
              package_repository_db_sha256=$(sha256sum "$package_repo/dinx.db.tar.gz" | cut -d " " -f 1)
              package_repository_key_sha256=$(sha256sum "$package_repo/dinx-package-signing-key.gpg" | cut -d " " -f 1)
              {
                printf "schema=dinx-package-repository/v1\n"
                printf "channel=%s\n" "$package_repository_channel"
                printf "snapshot=%s\n" "$package_repository_snapshot"
                printf "signing_fingerprint=%s\n" "$signing_key"
                printf "package_count=%s\n" "$package_count"
                printf "publication=github-release-assets/v1\n"
                printf "database_sha256=%s\n" "$package_repository_db_sha256"
                printf "key_sha256=%s\n" "$package_repository_key_sha256"
              } > "$package_repo/dinx-repository-metadata.txt"
              repository_checks_started=$SECONDS
              scripts/check_dinx_package_repository.sh "$package_repo"
              scripts/smoke_dinx_update.sh "$package_repo"
              printf 'dinx-build-timing phase=package-repository-validation elapsed_seconds=%s exit_status=0\n' \
                "$((SECONDS - repository_checks_started))"
              printf 'dinx-build-timing phase=package-repository-finalize elapsed_seconds=%s exit_status=0\n' \
                "$((SECONDS - repository_finalize_started))"
              if [[ "$package_repository_only" == true ]]; then
                printf 'dinx-package-repository channel=%s snapshot=%s packages=%s output=%s\n' \
                  "$package_repository_channel" "$package_repository_snapshot" "$package_count" "$package_repo"
                printf 'dinx-build-timing phase=package-repository-only elapsed_seconds=%s exit_status=0\n' \
                  "$((SECONDS - builder_started))"
                exit 0
              fi
              mapfile -t iso_paths < <(find "$DINX_ISO_OUTPUT" -type f -name '*.iso' -print | LC_ALL=C sort)
              [[ ${#iso_paths[@]} -eq 1 ]] || {
                printf 'build-iso-container: expected exactly one ISO, found %s\n' "${#iso_paths[@]}" >&2
                exit 1
              }
              iso_path=${iso_paths[0]}
              metadata_path="$(dirname "$iso_path")/build-metadata.txt"
              mkdir -p "$(dirname "$metadata_path")"
              iso_size=$(stat -c "%s" "$iso_path")
              iso_sha512=$(sha512sum "$iso_path" | cut -d " " -f 1)
              buildiso_owner=$(pacman -Qo "$(command -v buildiso)")
              mapfile -t builder_sync_databases < <(find /var/lib/pacman/sync -maxdepth 1 -type f -name '*.db' -print | LC_ALL=C sort)
              ((${#builder_sync_databases[@]} > 0)) || {
                printf 'build-iso-container: refreshed Artix sync databases are missing\n' >&2
                exit 1
              }
              builder_sync_databases_sha256=$(
                for sync_db in "${builder_sync_databases[@]}"; do
                  digest=$(sha256sum -- "$sync_db")
                  printf '%s  %s\n' "${digest%% *}" "$(basename -- "$sync_db")"
                done | sha256sum | cut -d ' ' -f 1
              )
              deetty_source_env_sha256=$(sha256sum -- /workspace/distro/packages/deetty/source.env | cut -d " " -f 1)
              package_snapshot=$(pacman -Q iso-profiles mkinitcpio)
              {
                printf "schema=dinx-build-metadata/v1\n"
                printf "repository=%s\n" "$DINX_REPOSITORY"
                printf "commit=%s\n" "$DINX_COMMIT"
                printf "build_context=%s\n" "${DINX_BUILD_CONTEXT:-github-actions}"
                : "${DINX_SOURCE_TREE_SHA256:?build is missing its source-tree checksum}"
                printf "source_tree_sha256=%s\n" "$DINX_SOURCE_TREE_SHA256"
                printf "deetty_source_env_sha256=%s\n" "$deetty_source_env_sha256"
                printf "workflow_run=%s\n" "$DINX_RUN_ID"
                printf "artix_image=%s\n" "$DINX_ARTIX_IMAGE"
                printf "builder_image_id=%s\n" "$DINX_BUILDER_IMAGE_ID"
                printf "builder_image_recipe_sha256=%s\n" "$DINX_BUILDER_RECIPE_SHA256"
                printf "builder_image_refresh_date=%s\n" "$DINX_BUILDER_REFRESH_DATE"
                printf "builder_pacman_conf_sha256=%s\n" "$builder_pacman_conf_sha256"
                printf "builder_mirrorlist_sha256=%s\n" "$builder_mirrorlist_sha256"
                printf "builder_mirrorlist_source=%s\n" "$builder_mirrorlist_source"
                printf "buildiso_owner=%s\n" "$buildiso_owner"
                printf "zig_version=%s\n" "$(zig version)"
                printf "profile_sha256=%s\n" "$(sha256sum /workspace/distro/iso/iso-profiles/dinx/profile.yaml | cut -d " " -f 1)"
                printf "common_profile_sha256=%s\n" "$(sha256sum /workspace/distro/iso/iso-profiles/common/common.yaml | cut -d " " -f 1)"
                printf "feature_groups_sha256=%s\n" "$(sha256sum /workspace/distro/iso/iso-profiles/dinx/feature-groups.json | cut -d " " -f 1)"
                printf "builder_sync_databases_sha256=%s\n" "$builder_sync_databases_sha256"
                printf "compression_schema=dinx-squashfs/v1\n"
                printf "compression_algorithm=xz\n"
                printf "compression_level=tool-default\n"
                printf "compression_block=1M\n"
                printf "compression_dictionary=1M\n"
                printf "compression_bcj=x86\n"
                printf "compression_excludes=kernel-source,pacman-cache,logs\n"
                printf "final_squashfs_prune_candidates=breeze,breeze-cursors,breeze-icons,dhcpcd,dhcpcd-dinit,ex-vi-compat,linux-headers,man-db,man-pages,pahole,plasma-integration,plasma-workspace,qogir-icon-theme,qqc2-breeze-style,texinfo,vim,vim-runtime,xdg-desktop-portal-kde\n"
                printf "compression_wrapper_sha256=%s\n" "$(sha256sum /workspace/scripts/iso-tools/mksquashfs | cut -d " " -f 1)"
                printf "package_repository_schema=dinx-package-repository/v1\n"
                printf "package_repository_channel=%s\n" "$package_repository_channel"
                printf "package_repository_publication=github-release-assets/v1\n"
                printf "package_repository_snapshot=%s\n" "$package_repository_snapshot"
                printf "package_repository_signing_fingerprint=%s\n" "$signing_key"
                printf "package_repository_db_sha256=%s\n" "$package_repository_db_sha256"
                printf "package_repository_key_sha256=%s\n" "$package_repository_key_sha256"
                printf "package_signing_mode=%s\n" "$package_signing_mode"
                printf "iso_name=%s\n" "$(basename "$iso_path")"
                printf "iso_bytes=%s\n" "$iso_size"
                printf "iso_sha512=%s\n" "$iso_sha512"
                printf "[builder-packages]\n"
                printf "%s\n" "$package_snapshot"
                printf "[largest-packages]\n"
                LC_ALL=C pacman -Qi \
                  | awk '
                    /^Name[[:space:]]*:/ { name = $3 }
                    /^Installed Size[[:space:]]*:/ {
                      value = $4 + 0
                      unit = $5
                      factor = unit == "KiB" ? 1 : unit == "MiB" ? 1024 : unit == "GiB" ? 1048576 : 0
                      if (name != "" && factor > 0) printf "%d KiB\t%s\n", value * factor, name
                    }
                  ' \
                  | sort -nrk1,1 \
                  | awk 'NR <= 20'
                printf "[all-artix-packages]\n"
                pacman -Q
              } > "$metadata_path"
