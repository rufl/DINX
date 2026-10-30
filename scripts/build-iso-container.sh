#!/usr/bin/env bash
set -euo pipefail

host_uid=${DINX_HOST_UID:-}
host_gid=${DINX_HOST_GID:-}
finish() {
  local status=$?
  trap - EXIT
  if [[ "$host_uid" =~ ^[0-9]+$ && "$host_gid" =~ ^[0-9]+$ ]]; then
    for path in "${DINX_ISO_OUTPUT:-}" "${DINX_PACKAGE_OUTPUT:-}" /var/lib/artools/buildiso; do
      [[ -n "$path" && -e "$path" ]] || continue
      chown -R -- "$host_uid:$host_gid" "$path" || true
    done
  fi
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
              pacman_retry -Syu --noconfirm
              pacman_retry -Syy --noconfirm
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
              update-mime-database /usr/share/mime
              mkdir -p /usr/lib/gdk-pixbuf-2.0/2.10.0
              gdk-pixbuf-query-loaders --update-cache
              zig_version=0.17.0
              zig_archive="zig-x86_64-linux-${zig_version}.tar.xz"
              zig_sha256=1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026
              curl --fail --silent --show-error --location --retry 3 \
                --output "/tmp/$zig_archive" \
                "https://ziglang.org/download/${zig_version}/${zig_archive}"
              actual_zig_sha=$(sha256sum "/tmp/$zig_archive" | cut -d " " -f 1)
              printf "zig_sha256=%s\n" "$actual_zig_sha"
              test "$actual_zig_sha" = "$zig_sha256"
              tar -xJf "/tmp/$zig_archive" --directory /tmp
              export PATH="/tmp/zig-x86_64-linux-${zig_version}:$PATH"
              actual_zig_version=$(zig version)
              printf "zig_version=%s\n" "$actual_zig_version"
              test "$actual_zig_version" = "$zig_version"
              source /workspace/distro/packages/pearl/source.env
              : "${PEARL_ZIG_VERSION:?PEARL_ZIG_VERSION is missing}"
              : "${PEARL_ZIG_SOURCE_URL:?PEARL_ZIG_SOURCE_URL is missing}"
              : "${PEARL_ZIG_SOURCE_SHA256:?PEARL_ZIG_SOURCE_SHA256 is missing}"
              pearl_zig_archive="zig-x86_64-linux-${PEARL_ZIG_VERSION}.tar.xz"
              curl --fail --silent --show-error --location --retry 3 \
                --output "/tmp/$pearl_zig_archive" \
                "$PEARL_ZIG_SOURCE_URL"
              actual_pearl_zig_sha=$(sha256sum "/tmp/$pearl_zig_archive" | cut -d " " -f 1)
              printf "pearl_zig_sha256=%s\n" "$actual_pearl_zig_sha"
              test "$actual_pearl_zig_sha" = "$PEARL_ZIG_SOURCE_SHA256"
              tar -xJf "/tmp/$pearl_zig_archive" --directory /tmp

              # Run before makepkg --clean removes source trees used by the static theme contract.
              scripts/check_dinx_theme.sh
              package_repo=${DINX_PACKAGE_OUTPUT:-/workspace/dist/packages}
              rm -rf "$package_repo"
              mkdir -p "$package_repo"
              makepkg_conf=/tmp/dinx-makepkg.conf
              cp /etc/makepkg.conf "$makepkg_conf"
              printf '%q\n' "PKGDEST=$package_repo" >> "$makepkg_conf"
              chmod 644 "$makepkg_conf"
              useradd --create-home --user-group dinxbuild
              chown -R dinxbuild:dinxbuild /workspace/distro/packages "$package_repo"
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
              pacman-key --add "$package_repo/dinx-package-signing-key.gpg"
              pacman-key --init
              pacman-key --lsign-key "$signing_key"

              build_package() {
                local package_name="$1"
                local package_dir="/workspace/distro/packages/$package_name"
                local -a extra_env=()
                if [[ "$package_name" == deetty ]]; then
                  extra_env=(GLYCIN_DISABLE_SANDBOX=i-know-the-risks)
                fi
                if [[ "$package_name" == pearl || "$package_name" == phyto || "$package_name" == dome ]]; then
                  extra_env+=("ZIG=/tmp/zig-x86_64-linux-${PEARL_ZIG_VERSION}/zig")
                elif [[ "$package_name" == pori || "$package_name" == aqueous ]]; then
                  extra_env+=("ZIG=/tmp/zig-x86_64-linux-${zig_version}/zig")
                fi
                (
                  cd "$package_dir"
                  runuser -u dinxbuild -- env "${extra_env[@]}" \
                    MAKEPKG_CONF="$makepkg_conf" \
                    GNUPGHOME="$signing_home" \
                    makepkg --clean --nodeps --nocheck --noconfirm \
                    --sign --key "$signing_key"
                )
              }
              build_package ghostty-vt-runtime
              ghostty_vt_package=$(find "$package_repo" -maxdepth 1 -type f -name 'ghostty-vt-runtime-*.pkg.tar.zst' -print -quit)
              [[ -n "$ghostty_vt_package" ]]
              pacman -Rdd --noconfirm ghostty
              pacman -U --noconfirm "$ghostty_vt_package"
              scripts/check_ghostty_vt_runtime.sh "$ghostty_vt_package"
              source /workspace/distro/packages/deetty/source.env
              [[ -n "$DEETTY_VERSION" ]]
              icon_svg=/tmp/dinx-dintor-icon.svg
              icon_png=/usr/share/icons/hicolor/128x128/apps/org.dinx.Dintor.png
              tar -xOf \
                "/workspace/distro/packages/deetty/noctty-${DEETTY_VERSION}.tar.gz" \
                "noctty-${DEETTY_VERSION}/resources/com.noctty.NoctEd.svg" \
                > "$icon_svg"
              mkdir -p "$(dirname "$icon_png")"
              rsvg-convert -w 128 -h 128 -o "$icon_png" "$icon_svg"
              gtk-update-icon-cache -f /usr/share/icons/hicolor
              rm -f "$icon_svg"
              build_package deetty
              pacman -U --noconfirm "$package_repo"/deetty-*.pkg.tar.zst
              build_package opensnitch-dinit
              build_package cyan-skillfish-governor-smu
              build_package cyan-skillfish-governor-smu-dinit
              build_package bc250-control-center
              build_package topgrade
              build_package paru
              build_package shelly
              pacman -U --noconfirm \
                "$package_repo"/topgrade-*.pkg.tar.zst \
                "$package_repo"/shelly-*.pkg.tar.zst
              build_package dinitui
              pacman -U --noconfirm "$package_repo"/dinitui-*.pkg.tar.zst
              DINITUI_BIN=/usr/bin/dinitui scripts/dinitui_dinit_qualification.sh
              scripts/smoke_calamares_startup.sh
              build_package dinxpanel
              pacman -U --noconfirm "$package_repo"/dinxpanel-*.pkg.tar.zst
              build_package shikane
              pacman -U --noconfirm "$package_repo"/shikane-*.pkg.tar.zst
              pacman_retry -S --needed --noconfirm wdisplays qt6ct
              build_package matugen
              pacman -U --noconfirm "$package_repo"/matugen-*.pkg.tar.zst
              build_package aqueous
              build_package pearl
              pacman -U --noconfirm \
                "$package_repo"/aqueous-*.pkg.tar.zst \
                "$package_repo"/pearl-*.pkg.tar.zst
              build_package pori
              build_package phyto
              build_package dome
              build_package zls
              build_package seafoam-settings
              pacman -U --noconfirm \
                "$package_repo"/dome-*.pkg.tar.zst \
                "$package_repo"/seafoam-settings-*.pkg.tar.zst \
                "$package_repo"/zls-*.pkg.tar.zst
              SEAFOAM_SETTINGS_BIN=/usr/bin/seafoam-settings scripts/seafoam_settings_smoke.sh
              ZLS_BIN=/usr/bin/zls scripts/smoke_zls.sh
              build_package dinx-live-autologin
              build_package swayimg
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

              pacman_conf=$(find /usr/share/artools -type f \
                -path "*/pacman.conf.d/iso-x86_64.conf" -print -quit)
              test -n "$pacman_conf"
              printf "\n[dinx]\nSigLevel = Required\nServer = http://127.0.0.1:8765\n" \
                >> "$pacman_conf"
              pacman_options_tmp="$pacman_conf.dinx"
              awk '
                /^\[options\][[:space:]]*$/ && !injected {
                  print
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
              trap "kill $repo_pid 2>/dev/null || true" EXIT

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
              scripts/check-iso-host.sh
              scripts/build-iso.sh
              metadata_path="$DINX_ISO_OUTPUT/dinx/build-metadata.txt"
              mkdir -p "$(dirname "$metadata_path")"
              iso_path=$(find "$DINX_ISO_OUTPUT" -type f -name "*.iso" -print -quit)
              test -n "$iso_path"
              iso_size=$(stat -c "%s" "$iso_path")
              iso_sha512=$(sha512sum "$iso_path" | cut -d " " -f 1)
              buildiso_owner=$(pacman -Qo "$(command -v buildiso)")
              package_snapshot=$(pacman -Q iso-profiles mkinitcpio)
              {
                printf "schema=dinx-build-metadata/v1\n"
                printf "repository=%s\n" "$DINX_REPOSITORY"
                printf "commit=%s\n" "$DINX_COMMIT"
                printf "build_context=%s\n" "${DINX_BUILD_CONTEXT:-github-actions}"
                if [[ "${DINX_BUILD_CONTEXT:-github-actions}" == local-docker ]]; then
                  : "${DINX_SOURCE_TREE_SHA256:?local Docker build is missing its source-tree checksum}"
                  printf "source_tree_sha256=%s\n" "$DINX_SOURCE_TREE_SHA256"
                fi
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
                printf "deetty_source_env_sha256=%s\n" "$(sha256sum /workspace/distro/packages/deetty/source.env | cut -d " " -f 1)"
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
