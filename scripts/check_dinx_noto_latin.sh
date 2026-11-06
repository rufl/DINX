#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
package_dir="$repo_root/distro/packages/dinx-noto-latin"
source_env="$package_dir/source.env"
pkgbuild="$package_dir/PKGBUILD"
license="$package_dir/OFL.txt"
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json"
update_manifest="$repo_root/.github/package-updates.json"
builder="$repo_root/scripts/build-iso-container.sh"

fail() {
  printf 'dinx_noto_latin_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$source_env" "$pkgbuild" "$license" "$profile" "$groups" "$update_manifest" "$builder"; do
  [[ -r "$path" ]] || fail "missing contract input: $path"
done
source "$source_env"
[[ "$DINX_NOTO_VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$ ]] \
  || fail "invalid monthly source version: $DINX_NOTO_VERSION"

font_keys=(REGULAR BOLD ITALIC BOLD_ITALIC MONO_REGULAR)
font_files=(NotoSans-Regular.ttf NotoSans-Bold.ttf NotoSans-Italic.ttf NotoSans-BoldItalic.ttf NotoSansMono-Regular.ttf)
for index in "${!font_keys[@]}"; do
  key=${font_keys[index]}
  file=${font_files[index]}
  url_key="DINX_NOTO_${key}_SOURCE_URL"
  checksum_key="DINX_NOTO_${key}_SOURCE_SHA256"
  url=${!url_key}
  checksum=${!checksum_key}
  [[ "$url" == "https://raw.githubusercontent.com/notofonts/notofonts.github.io/noto-monthly-release-${DINX_NOTO_VERSION}/fonts/"*"/hinted/ttf/$file" ]] \
    || fail "source URL is not pinned to the selected Noto monthly release: $url_key"
  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail "invalid source checksum: $checksum_key"
  grep -Fq "${file}::\${${url_key}}" "$pkgbuild" \
    || fail "PKGBUILD does not package the pinned font source: $file"
  grep -Fq "\${${checksum_key}}" "$pkgbuild" \
    || fail "PKGBUILD does not verify the font source: $checksum_key"
done

for file in "${font_files[@]}"; do
  grep -Fq "\"$file\"" "$pkgbuild" || grep -Fq "$file" "$pkgbuild" \
    || fail "PKGBUILD does not install expected font: $file"
done
for required in \
  "pkgname=dinx-noto-latin" \
  "license=('OFL-1.1-no-RFN')" \
  'install -Dm644 "$startdir/OFL.txt"' \
  'fontconfig'; do
  grep -Fq -- "$required" "$pkgbuild" || fail "PKGBUILD is missing: $required"
done
grep -Fq 'SIL OPEN FONT LICENSE Version 1.1' "$license" || fail 'OFL 1.1 license text is missing'
grep -Fq 'Copyright 2022 The Noto Project Authors' "$license" || fail 'Noto copyright notice is missing'
grep -Fqx '    - dinx-noto-latin' "$profile" || fail 'DINX ISO profile omits the subset package'
if grep -Fqx '    - noto-fonts' "$profile"; then
  fail 'full noto-fonts package is still in the ISO profile'
fi
jq -e '
  [.groups[].packages[]] | index("dinx-noto-latin") != null and index("noto-fonts") == null
' "$groups" >/dev/null || fail 'feature groups do not select only the DINX subset package'
grep -Fq 'build_package dinx-noto-latin' "$builder" || fail 'ISO package repository does not build the subset package'
jq -e '
  .packages[] | select(.name == "dinx-noto-latin" and .tag_prefix == "noto-monthly-release-" and (.additional_sources | length) == 4)
' "$update_manifest" >/dev/null || fail 'monthly source refresh does not track all font files'

printf 'dinx_noto_latin_contract package=true monthly_source=true font_files=%s families=NotoSans+NotoSansMono license=OFL-1.1 refresh=true full_package=false\n' \
  "${#font_files[@]}"
