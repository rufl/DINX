ARG DINX_ARTIX_IMAGE=artixlinux/artixlinux@sha256:e746e31ffe48f9526759711de0a3bc4cb7a8f61d7339dc9b11fe6bee4a722507
FROM ${DINX_ARTIX_IMAGE}

ARG DINX_ARTIX_IMAGE
ARG DINX_BUILDER_REFRESH
ARG DINX_BUILDER_RECIPE_SHA256

LABEL org.dinx.builder.artix-image="${DINX_ARTIX_IMAGE}" \
      org.dinx.builder.refresh-date="${DINX_BUILDER_REFRESH}" \
      org.dinx.builder.recipe-sha256="${DINX_BUILDER_RECIPE_SHA256}"

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
COPY packages.txt /tmp/dinx-builder-packages.txt

RUN printf '%s\n' \
      '# DINX official Artix HTTPS mirrors' \
      'Server = https://mirror2.artixlinux.org/$repo/os/$arch' \
      'Server = https://mirror3.artixlinux.org/repos/$repo/os/$arch' \
      > /etc/pacman.d/mirrorlist

RUN pacman -Syyu --noconfirm \
    && xargs -r pacman -S --needed --noconfirm < /tmp/dinx-builder-packages.txt \
    && install -d -m 0755 /etc/dinx-builder-image \
    && { \
      printf 'artix_image=%s\n' "$DINX_ARTIX_IMAGE"; \
      printf 'recipe_sha256=%s\n' "$DINX_BUILDER_RECIPE_SHA256"; \
      printf 'refresh_date=%s\n' "$DINX_BUILDER_REFRESH"; \
    } > /etc/dinx-builder-image/metadata \
    && rm -rf /var/cache/pacman/pkg/* /tmp/dinx-builder-packages.txt
