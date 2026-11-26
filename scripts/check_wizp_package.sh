#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pkgdir="$root/distro/packages/wizp"
pkgbuild="$pkgdir/PKGBUILD"
desktop="$pkgdir/resources/wizp.desktop"
icon="$pkgdir/resources/dev.wizp.WIZP.svg"
readme="$pkgdir/README.md"

fail() {
  printf 'wizp_package_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$desktop" "$icon" "$readme"; do
  [[ -r "$path" ]] || fail "missing package input: $path"
done

grep -Fqx 'pkgname=wizp' "$pkgbuild" || fail 'PKGBUILD package name is not wizp'
grep -Fq 'WIZP_PACKAGE_DIR' "$pkgbuild" || fail 'PKGBUILD does not require the exact self-contained package directory'
grep -Fq 'libcef.so' "$pkgbuild" || fail 'PKGBUILD does not require bundled CEF'
grep -Fq '/opt/wizp' "$pkgbuild" || fail 'PKGBUILD does not isolate the bundled runtime under /opt/wizp'
grep -Fqx 'Exec=wizp %F' "$desktop" || fail 'desktop entry does not forward file arguments'
grep -Fqx 'Icon=dev.wizp.WIZP' "$desktop" || fail 'desktop entry icon identity is incorrect'
grep -Fq 'MimeType=text/plain;' "$desktop" || fail 'desktop entry lacks explicit text MIME handling'
grep -Fq 'does not claim binary, image, archive, or arbitrary MIME handling' "$readme" || fail 'README overclaims file handling'
grep -Fq '<svg ' "$icon" || fail 'WIZP icon is not SVG'

lean_pkgdir="$root/distro/packages/wizp-lean"
for path in \
  "$lean_pkgdir/PKGBUILD" \
  "$lean_pkgdir/README.md" \
  "$lean_pkgdir/build.sh" \
  "$lean_pkgdir/electrobun-cef109.patch"; do
  [[ -r "$path" ]] || fail "missing lean package input: $path"
done
bash -n "$lean_pkgdir/PKGBUILD" "$lean_pkgdir/build.sh" \
  || fail 'lean package build scripts have invalid shell syntax'
grep -Fqx 'pkgname=wizp-lean' "$lean_pkgdir/PKGBUILD" || fail 'lean PKGBUILD package name is not wizp-lean'
grep -Fq 'eurooffice=9.3.8-5' "$lean_pkgdir/PKGBUILD" || fail 'lean package does not pin EuroOffice runtime'
grep -Fq 'conflicts=(wizp)' "$lean_pkgdir/PKGBUILD" || fail 'lean package can coexist with bundled wizp'
grep -Fq 'ln -s "/opt/eurooffice/$file"' "$lean_pkgdir/PKGBUILD" || fail 'lean package does not link CEF libraries to EuroOffice'
grep -Fq '109.1.18+gf1c41e4' "$lean_pkgdir/PKGBUILD" || fail 'lean package does not pin CEF 109'
grep -Fq 'b86edf848d4c18c70d76eba7bcce766d2f5d735ac56effeb11fcf4ee47771689' \
  "$lean_pkgdir/PKGBUILD" || fail 'lean package does not pin EuroOffice libcef content'
grep -Fq 'CEF 109 is substantially older' "$lean_pkgdir/README.md" \
  || fail 'lean package README omits the CEF security warning'

printf 'wizp_lean_package_contract pinned_runtime=true bundled_fallback=true eol_warning=true\n'

printf 'wizp_package_contract metadata=true bundled_cef=true file_args=true text_mime_scope=true staged_source_required=true\n'
