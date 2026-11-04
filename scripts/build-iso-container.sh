#!/usr/bin/env bash
set -euo pipefail

host_uid=${DINX_HOST_UID:-}
host_gid=${DINX_HOST_GID:-}
build_uid=
build_gid=
repo_pid=
builder_started=$SECONDS
finish() {
  local status=$?
  local elapsed=$((SECONDS - builder_started))
  local path
  trap - EXIT
  if [[ -n "$repo_pid" ]]; then
    kill "$repo_pid" 2>/dev/null || true
  fi
  if [[ "$host_uid" =~ ^[0-9]+$ && "$host_gid" =~ ^[0-9]+$ ]]; then
    for path in "${DINX_ISO_OUTPUT:-}" "${DINX_PACKAGE_OUTPUT:-}" /var/lib/artools/buildiso /var/cache/dinx /workspace/distro/packages; do
      [[ -n "$path" && -e "$path" ]] || continue
      if [[ "$path" == /var/lib/artools/buildiso \
        && "$status" -eq 0 \
        && "${DINX_REMOVE_CHROOTS_AFTER_BUILD:-false}" == true ]]; then
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
              DINX_ARTIX_IMAGE="${DINX_ARTIX_IMAGE:-artixlinux/artixlinux@sha256:e746e31ffe48f9526759711de0a3bc4cb7a8f61d7339dc9b11fe6bee4a722507}"
              export DINX_ARTIX_IMAGE
              : "${DINX_ARTIX_IMAGE:?DINX_ARTIX_IMAGE was not forwarded into the builder container}"
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
              builder_pacman_started=$SECONDS
              pacman_retry -Syyu --noconfirm
              pacman_retry -S --needed --noconfirm \
                artools \
                iso-profiles \
                mkinitcpio \
                base-devel \
                bubblewrap \
                bash-completion \
                btop \
                curl \
                clang \
                brightnessctl \
                cairo \
                cjson \
                calamares \
                calamares-extensions \
                dbus \
                dialog \
                dinit \
                fzf \
                gdk-pixbuf2 \
                glances \
                glib2 \
                go-md2man \
                gettext \
                git \
                gnupg \
                glslang \
                glycin \
                gtk-layer-shell \
                gamescope \
                fontconfig \
                freetype2 \
                gtk3 \
                gtk4 \
                libadwaita \
                libarchive \
                libcups \
                libdecor \
                libevdev \
                libinih \
                lcms2 \
                libpulse \
                libsecret \
                libxml2 \
                pam \
                playerctl \
                polkit \
                qt5-base \
                qt6-base \
                shaderc \
                scdoc \
                vulkan-headers \
                vulkan-icd-loader \
                gtk4-layer-shell \
                gtksourceview5 \
                enchant \
                hunspell \
                gtksourceview4 \
                vte3 \
                ghostty \
                hicolor-icon-theme \
                adwaita-icon-theme \
                less \
                libdisplay-info \
                libdrm \
                libepoxy \
                libglvnd \
                libinput \
                libliftoff \
                libnewt \
                libpng \
                librsvg \
                libxcb \
                libxkbcommon \
                luajit \
                man-db \
                mesa \
                meson \
                nano \
                ninja \
                openssh \
                pango \
                pcre2 \
                pixman \
                pkgconf \
                procps-ng \
                pipewire \
                python \
                seatd \
                shared-mime-info \
                sqlite \
                texinfo \
                tmux \
                util-linux \
                wayland \
                wayland-protocols \
                vim \
                xcb-util-errors \
                xcb-util-renderutil \
                xcb-util-wm \
                xorg-xwayland \
                xdg-desktop-portal \
                xdg-utils \
                xorg-server-xvfb \
                xz \
                zlib \
                rust
              printf 'dinx-build-timing phase=builder-pacman-setup elapsed_seconds=%s exit_status=0\n' \
                "$((SECONDS - builder_pacman_started))"
              scripts/check_artix_initcpio_patch.sh --check-installed
              update-mime-database /usr/share/mime
              mkdir -p /usr/lib/gdk-pixbuf-2.0/2.10.0
              gdk-pixbuf-query-loaders --update-cache
              zig_version=0.17.0
              zig_archive="zig-x86_64-linux-${zig_version}.tar.xz"
              zig_sha256=1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026
              toolchain_cache="${DINX_BUILD_CACHE_DIR:-/var/cache/dinx}/toolchains"
              mkdir -p "$toolchain_cache"
              zig_archive_path="$toolchain_cache/$zig_archive"
              scripts/cache-verified-download.sh \
                "$zig_archive_path" \
                "https://ziglang.org/download/${zig_version}/${zig_archive}" \
                "$zig_sha256"
              actual_zig_sha=$(sha256sum "$zig_archive_path" | cut -d " " -f 1)
              printf "zig_sha256=%s\n" "$actual_zig_sha"
              test "$actual_zig_sha" = "$zig_sha256"
              tar -xJf "$zig_archive_path" --directory /tmp
              export PATH="/tmp/zig-x86_64-linux-${zig_version}:$PATH"
              actual_zig_version=$(zig version)
              printf "zig_version=%s\n" "$actual_zig_version"
              test "$actual_zig_version" = "$zig_version"
              source /workspace/distro/packages/pearl/source.env
              : "${PEARL_ZIG_VERSION:?PEARL_ZIG_VERSION is missing}"
              : "${PEARL_ZIG_SOURCE_URL:?PEARL_ZIG_SOURCE_URL is missing}"
              : "${PEARL_ZIG_SOURCE_SHA256:?PEARL_ZIG_SOURCE_SHA256 is missing}"
              pearl_zig_archive="zig-x86_64-linux-${PEARL_ZIG_VERSION}.tar.xz"
              pearl_zig_archive_path="$toolchain_cache/$pearl_zig_archive"
              scripts/cache-verified-download.sh \
                "$pearl_zig_archive_path" \
                "$PEARL_ZIG_SOURCE_URL" \
                "$PEARL_ZIG_SOURCE_SHA256"
              actual_pearl_zig_sha=$(sha256sum "$pearl_zig_archive_path" | cut -d " " -f 1)
              printf "pearl_zig_sha256=%s\n" "$actual_pearl_zig_sha"
              test "$actual_pearl_zig_sha" = "$PEARL_ZIG_SOURCE_SHA256"
              tar -xJf "$pearl_zig_archive_path" --directory /tmp

              # Run before makepkg --clean removes source trees used by the static theme contract.
              scripts/check_dinx_theme.sh
              package_repo=${DINX_PACKAGE_OUTPUT:-/workspace/dist/packages}
              rm -rf "$package_repo"
              mkdir -p "$package_repo"
              makepkg_conf=/tmp/dinx-makepkg.conf
              cp /etc/makepkg.conf "$makepkg_conf"
              makepkg_base_conf_sha256=$(sha256sum "$makepkg_conf" | cut -d " " -f 1)
              makepkg_source_cache=/var/cache/dinx/makepkg-sources
              cargo_cache=/var/cache/dinx/cargo
              cargo_target_cache=/var/cache/dinx/cargo-target
              zig_cache=/var/cache/dinx/zig
              package_artifact_cache=/var/cache/dinx/package-artifacts
              mkdir -p "$makepkg_source_cache" "$cargo_cache" "$cargo_target_cache" "$zig_cache" "$package_artifact_cache"
              printf '%q\n' "PKGDEST=$package_repo" "SRCDEST=$makepkg_source_cache" >> "$makepkg_conf"
              chmod 644 "$makepkg_conf"
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
              package_cache_builder_sha256=$(sha256sum /workspace/scripts/build-iso-container.sh | cut -d " " -f 1)
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
                local status archive archive_name installed_packages_sha256 cache_key
                local -a extra_env=(
                  "CARGO_HOME=/var/cache/dinx/cargo"
                  "CARGO_TARGET_DIR=/var/cache/dinx/cargo-target/$package_name"
                  "ZIG_GLOBAL_CACHE_DIR=/var/cache/dinx/zig"
                )
                local -a makepkg_options=(--nodeps --nocheck --noconfirm)
                local -A existing_archives=()
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
                if [[ "$package_name" == pearl || "$package_name" == phyto || "$package_name" == dome ]]; then
                  extra_env+=("ZIG=/tmp/zig-x86_64-linux-${PEARL_ZIG_VERSION}/zig")
                elif [[ "$package_name" == pori || "$package_name" == aqueous ]]; then
                  extra_env+=("ZIG=/tmp/zig-x86_64-linux-${zig_version}/zig")
                fi

                installed_packages_sha256=$(pacman -Q | LC_ALL=C sort | sha256sum)
                installed_packages_sha256=${installed_packages_sha256%% *}
                cache_key=$(dinx_package_cache_key \
                  "$package_name" "$package_dir" "$makepkg_base_conf_sha256" \
                  "$package_cache_builder_sha256" "$installed_packages_sha256" /workspace \
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

                while IFS= read -r -d '' archive; do
                  existing_archives["$(basename -- "$archive")"]=1
                done < <(find "$package_repo" -maxdepth 1 -type f -name '*.pkg.tar.zst' -print0)
                if (
                  cd "$package_dir"
                  runuser -u dinxbuild -- env "${extra_env[@]}" \
                    MAKEPKG_CONF="$makepkg_conf" \
                    GNUPGHOME="$signing_home" \
                    makepkg "${makepkg_options[@]}" \
                    --sign --key "$signing_key"
                ); then
                  while IFS= read -r -d '' archive; do
                    archive_name=$(basename -- "$archive")
                    if [[ -z ${existing_archives[$archive_name]+present} ]]; then
                      package_archives+=("$archive")
                    fi
                  done < <(find "$package_repo" -maxdepth 1 -type f -name '*.pkg.tar.zst' -print0)
                  if ((${#package_archives[@]} == 0)); then
                    printf 'build-iso-container: makepkg produced no package archive for %s\n' "$package_name" >&2
                    return 1
                  fi
                  if ! package_cache_as_build_user dinx_package_cache_store \
                    "$package_artifact_cache" "$package_name" "$cache_key" "${package_archives[@]}"; then
                    printf 'dinx-package-cache: store skipped package=%s key=%s\n' "$package_name" "$cache_key" >&2
                  fi
                  printf 'dinx-build-timing package=%s elapsed_seconds=%s exit_status=0 cache=miss\n' \
                    "$package_name" "$((SECONDS - package_started))"
                else
                  status=$?
                  printf 'dinx-build-timing package=%s elapsed_seconds=%s exit_status=%s cache=miss\n' \
                    "$package_name" "$((SECONDS - package_started))" "$status"
                  return "$status"
                fi
              }
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
              build_package opensnitch-dinit
              build_package cyan-skillfish-governor-smu
              build_package cyan-skillfish-governor-smu-dinit
              build_package bc250-control-center
              build_package topgrade
              build_package paru
              build_package shelly
              pacman_install_local \
                "$package_repo"/topgrade-*.pkg.tar.zst \
                "$package_repo"/shelly-*.pkg.tar.zst
              build_package dinitui
              pacman_install_local "$package_repo"/dinitui-*.pkg.tar.zst
              DINITUI_BIN=/usr/bin/dinitui scripts/dinitui_dinit_qualification.sh
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
              build_package dinx-plymouth-theme
              build_package dinx-live-autologin
              build_package swayimg
              pacman_retry -S --needed --noconfirm vala gst-plugins-base gst-plugins-good
              build_package gapless
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
              scripts/check_dinx_package_repository.sh "$package_repo"
              scripts/smoke_dinx_update.sh "$package_repo"
              dinx_invalidate_pacman_package_cache "$package_repo" /var/cache/pacman/pkg

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
                printf "compression_block=256K\n"
                printf "compression_dictionary=256K\n"
                printf "compression_bcj=x86\n"
                printf "compression_excludes=kernel-source,pacman-cache,logs\n"
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
