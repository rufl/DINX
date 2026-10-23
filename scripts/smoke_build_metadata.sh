#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

metadata="$tmp_dir/build-metadata.txt"
iso="$tmp_dir/fixture.iso"
printf 'DINX metadata fixture\n' >"$iso"

iso_bytes=$(stat -c '%s' "$iso")
iso_sha512=$(sha512sum "$iso" | cut -d ' ' -f 1)
profile_sha=$(sha256sum "$root/distro/iso/iso-profiles/dinx/profile.yaml" | cut -d ' ' -f 1)
common_profile_sha=$(sha256sum "$root/distro/iso/iso-profiles/common/common.yaml" | cut -d ' ' -f 1)
feature_groups_sha=$(sha256sum "$root/distro/iso/iso-profiles/dinx/feature-groups.json" | cut -d ' ' -f 1)
noctty_source_env_sha=$(sha256sum "$root/distro/packages/noctty/source.env" | cut -d ' ' -f 1)
compression_wrapper_sha=$(sha256sum "$root/scripts/iso-tools/mksquashfs" | cut -d ' ' -f 1)

fixture_commit=0000000000000000000000000000000000000000
cat >"$metadata" <<EOF
schema=dinx-build-metadata/v1
repository=rufl/DINX
commit=$fixture_commit
workflow_run=1
artix_image=artixlinux/artixlinux@sha256:0000000000000000000000000000000000000000000000000000000000000000
builder_pacman_conf_sha256=0000000000000000000000000000000000000000000000000000000000000000
builder_mirrorlist_sha256=0000000000000000000000000000000000000000000000000000000000000000
buildiso_owner=/usr/bin/buildiso is owned by artools-iso 0.40.0-1
zig_version=0.17.0
profile_sha256=$profile_sha
common_profile_sha256=$common_profile_sha
feature_groups_sha256=$feature_groups_sha
noctty_source_env_sha256=$noctty_source_env_sha
compression_schema=dinx-squashfs/v1
compression_algorithm=xz
compression_level=tool-default
compression_block=1M
compression_dictionary=1M
compression_bcj=x86
compression_excludes=kernel-source,pacman-cache,logs
compression_wrapper_sha256=$compression_wrapper_sha
package_repository_schema=dinx-package-repository/v1
package_repository_channel=ci
package_repository_publication=github-release-assets/v1
package_repository_snapshot=0000000000000000000000000000000000000000000000000000000000000000
package_repository_signing_fingerprint=0000000000000000000000000000000000000000
package_repository_db_sha256=0000000000000000000000000000000000000000000000000000000000000000
package_repository_key_sha256=0000000000000000000000000000000000000000000000000000000000000000
package_signing_mode=ephemeral-ci
iso_name=fixture.iso
iso_bytes=$iso_bytes
iso_sha512=$iso_sha512
[builder-packages]
iso-profiles 2025.09-2
mkinitcpio 42.2-1
[largest-packages]
123 KiB fixture
[all-artix-packages]
fixture 1
EOF

verified=$(GITHUB_SHA="$fixture_commit" "$root/scripts/check_build_metadata.sh" "$metadata" "$iso")
grep -Fq 'iso_binding=verified' <<<"$verified"
unchecked=$(GITHUB_SHA="$fixture_commit" "$root/scripts/check_build_metadata.sh" "$metadata")
grep -Fq 'iso_binding=not-checked' <<<"$unchecked"

printf 'corrupt fixture\n' >>"$iso"
if $root/scripts/check_build_metadata.sh "$metadata" "$iso" >/dev/null 2>&1; then
  printf 'smoke_build_metadata: changed ISO unexpectedly passed metadata binding\n' >&2
  exit 1
fi

printf 'build_metadata_smoke binding=true optional=true mismatch_rejected=true\n'
